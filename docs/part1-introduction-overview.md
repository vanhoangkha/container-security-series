# Container Security Series - Part 1: Introduction & Overview

> **Series:** Container Security Toàn Diện (2026 Edition)
> **Author:** Security Research Series
> **Date:** June 2026

---

## 1. Tại Sao Container Security Quan Trọng?

Container technologies đã trở thành mainstream và có mặt ở khắp nơi. Theo **CNCF Annual Survey 2025**:

- **56%** tổ chức sử dụng containers cho production applications (tăng từ 41% năm 2023)
- **82%** container users deploy Kubernetes trong production
- **66%** tổ chức sử dụng K8s cho generative AI workloads
- **70%** containers tồn tại ít hơn 5 phút — khiến việc investigate anomalous behavior cực kỳ khó khăn

Kubernetes clusters mới nhận được **attack attempt đầu tiên trong vòng 18 phút** sau khi deploy. 18 phút.

---

## 2. Container Security Là Gì?

Container security là tập hợp các **practices, tools, và policies** được sử dụng để bảo vệ containerized applications xuyên suốt lifecycle:

```
Image Creation → Registry Storage → Orchestration → Runtime Execution → Teardown
```

Không giống traditional security approaches, container security phải address **dynamic, ephemeral workloads** có thể spin up và biến mất trong vài giây.

### Shared Responsibility Model

| Layer | Cloud Provider | User |
|-------|---------------|------|
| Physical hardware, hypervisors | ✅ | |
| Managed K8s control plane | ✅ | |
| Container images | | ✅ |
| Application code | | ✅ |
| Secrets management | | ✅ |
| Network policies | | ✅ |
| Access controls | | ✅ |
| Runtime monitoring | | ✅ |

---

## 3. Container Security Attack Surface

Attack surface phân bố qua **4 key layers**:

### 3.1. Container Images
- Vulnerable base images (standard public images thường ship với 50-60 known CVEs)
- Malicious code embedded trong images
- Lateral movement từ compromised image

### 3.2. Container Registries
- Distribution point cho compromised images
- Unauthorized access dẫn đến image tampering
- Supply chain attacks qua poisoned images

### 3.3. Container Orchestrators (Kubernetes)
- Misconfigured RBAC policies
- Exposed API servers
- Overly permissive network policies
- 78% Kubernetes clusters publicly accessible (Wiz Report)

### 3.4. Container Runtime Engine
- Container escape vulnerabilities
- Privileged containers → full host control
- Shared kernel architecture risks

---

## 4. Common Threats & Attack Vectors

### Container-Specific Threats

| Threat | Description | Impact |
|--------|-------------|--------|
| **Container Escape** | Exploit runtime vulnerabilities để escape container isolation | Full host compromise |
| **Privileged Container Abuse** | CI systems (Docker-in-Docker, Jenkins) chạy privileged | Modify kernel modules, host filesystem |
| **Image Vulnerability Propagation** | Vulnerabilities trong base images spread qua supply chain | Wide-scale compromise |
| **Exposed Docker Socket** | Mount docker.sock vào container | Complete Docker host control |
| **Kubernetes RBAC Misconfiguration** | Overly permissive roles | Unauthorized cluster access |
| **Credential Theft via Metadata Service** | Container access AWS/GCP metadata | Cloud account compromise |

### Real-World Attack Pattern

```
1. Initial Access → Vulnerable container image với known CVE
2. Execution → Exploit vulnerability trong running container
3. Privilege Escalation → Container escape hoặc mount sensitive paths
4. Lateral Movement → Access metadata service, steal credentials
5. Data Exfiltration → Access secrets, databases, other services
```

---

## 5. Container Security Lifecycle Framework

Container security áp dụng ở **4 phases** chính:

### Phase 1: PREVENT (Shift-Left)
- Code scanning (SAST)
- Dependency scanning (SCA)
- Image scanning
- IaC scanning
- Image signing & content trust
- Admission controllers

### Phase 2: PROTECT (Runtime Hardening)
- Least privilege (non-root, drop capabilities)
- Resource limits
- Network policies & segmentation
- Pod Security Standards (PSS)
- Seccomp & AppArmor profiles
- Read-only filesystems

### Phase 3: DETECT (Monitoring)
- Runtime threat detection (Falco, Tetragon)
- System call auditing (eBPF)
- Kubernetes audit logs
- Cloud trail logs (CloudTrail, Cloud Audit)
- Anomaly detection

### Phase 4: RESPOND (Incident Response)
- Container isolation & pause
- Snapshot & forensics
- Kill compromised containers
- Patch vulnerabilities
- Fix misconfigurations
- Post-incident review

---

## 6. Security Matrix: Layer × Phase

| Layer | Prevent | Protect | Detect | Respond |
|-------|---------|---------|--------|---------|
| **Code** | SAST, dependency scan | — | — | — |
| **CI/CD** | Image scan, IaC scan | — | — | — |
| **Registry** | Image scan, signing | Verify signature | — | — |
| **Cloud** | Configuration, IaC scan | Security groups, network rules | Event & log audit | Isolate, investigate |
| **Host** | Host scanning, benchmarks | Hardening, vuln management | Syscall audit | Patch vulnerabilities |
| **Runtime** | Admission controller | Network policies, configuration | Image scan, events | Fix config, patch |
| **Container** | — | User privileges, resource limits | Syscall audit, logs | Update image, dependencies |

---

## 7. Key Components Cần Secure

```
╔═══════════════════════════════════════════════════════════╗
║                    ORCHESTRATOR (K8s)                      ║
║                                                           ║
║   ┌───────────┐   ┌───────────┐   ┌───────────┐         ║
║   │    Pod    │   │    Pod    │   │    Pod    │         ║
║   │ ┌───────┐│   │ ┌───────┐│   │ ┌───────┐│         ║
║   │ │  App  ││   │ │  App  ││   │ │  App  ││         ║
║   │ └───────┘│   │ └───────┘│   │ └───────┘│         ║
║   │ Image Lyr │   │ Image Lyr │   │ Image Lyr │         ║
║   └───────────┘   └───────────┘   └───────────┘         ║
║                                                           ║
║   Network Policies │ RBAC │ Secrets │ PSS                 ║
╠═══════════════════════════════════════════════════════════╣
║   CONTAINER RUNTIME (containerd / CRI-O)                  ║
╠═══════════════════════════════════════════════════════════╣
║   HOST OS (Linux Kernel)                                  ║
║   Seccomp │ AppArmor/SELinux │ Namespaces │ Cgroups       ║
╠═══════════════════════════════════════════════════════════╣
║   INFRASTRUCTURE (Cloud / On-prem)                        ║
║   Firewall │ VPC │ IAM │ Encryption                       ║
╚═══════════════════════════════════════════════════════════╝
```

---

## 8. Challenges Khi Securing Containers

1. **Dynamic Infrastructure**: Containers xuất hiện và biến mất nhanh hơn security tools có thể track
2. **Layered Image Complexity**: Multiple layers từ different sources → vulnerability multiplication
3. **Ephemeral Workloads**: "Harden once, protect forever" không hoạt động
4. **Supply Chain Attacks**: Compromised link trong image chain → spread across infrastructure
5. **Shared Kernel**: Single compromised container → potentially impact entire host
6. **Visibility Gaps**: Traditional tools miss vulnerabilities trong brief-lived containers

---

## 9. Series Overview

Series này sẽ cover chi tiết từng aspect:

| Part | Topic | Focus |
|------|-------|-------|
| **Part 1** | Introduction & Overview | ← Bạn đang ở đây |
| **Part 2** | Image Security & Supply Chain | SBOM, scanning, signing, minimal images |
| **Part 3** | Runtime Security & Monitoring | eBPF, Falco, Seccomp, AppArmor |
| **Part 4** | Kubernetes Security Hardening | RBAC, PSS, Network Policies, API Security |
| **Part 5** | Network Security & Zero Trust | Service Mesh, mTLS, micro-segmentation |
| **Part 6** | Security Tools & Platforms | Trivy, Falco, Wiz, Aqua, Sysdig comparison |
| **Part 7** | Best Practices & Security Checklist | Comprehensive checklist, compliance |

---

## 10. Key Takeaways

- Container security không phải "set once and forget" — nó là continuous process
- Attack surface distributed across images, registries, orchestrators, và runtime
- Defense-in-depth approach: multiple layers of security ở mỗi phase
- Shift-left nhưng không bỏ qua runtime protection
- 56% organizations dùng containers cho production nhưng security vẫn là top challenge
- Kubernetes ships insecure by default — cần hardening có chủ đích

---

## 11. Hands-On Lab: Container Security Quick Assessment

### Lab 1: Scan Your First Image (5 phút)

```bash
# Install Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Scan một image phổ biến — xem có bao nhiêu CVEs
trivy image nginx:latest --severity HIGH,CRITICAL

# So sánh với minimal image
trivy image nginx:alpine --severity HIGH,CRITICAL

# Kết quả: nginx:latest thường có 50+ HIGH/CRITICAL CVEs
#          nginx:alpine thường < 5
```

### Lab 2: Kiểm Tra Container Đang Chạy As Root? (3 phút)

```bash
# List all containers running as root
docker ps --quiet | xargs docker inspect --format \
  '{{.Name}} - User: {{.Config.User}} - Privileged: {{.HostConfig.Privileged}}' 2>/dev/null

# Trên Kubernetes
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: runAsNonRoot={.spec.securityContext.runAsNonRoot}{"\n"}{end}' | grep -v "runAsNonRoot=true"
```

### Lab 3: Tìm Secrets Bị Expose (3 phút)

```bash
# Scan source code cho leaked secrets
trivy fs --scanners secret .

# Kiểm tra Kubernetes secrets (base64, NOT encrypted)
kubectl get secrets -A -o json | jq '.items[] | select(.type != "kubernetes.io/service-account-token") | .metadata.namespace + "/" + .metadata.name'
```

### Lab 4: Network Policy Coverage Check (2 phút)

```bash
# Namespaces KHÔNG có network policy (vulnerable!)
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  count=$(kubectl get networkpolicy -n $ns --no-headers 2>/dev/null | wc -l)
  if [ "$count" -eq 0 ]; then
    echo "⚠️  NO NetworkPolicy: $ns"
  fi
done
```

### Lab 5: CIS Benchmark Quick Check (5 phút)

```bash
# Run kube-bench (as a Job in cluster)
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
sleep 30
kubectl logs $(kubectl get pods -l app=kube-bench -o name) | tail -20

# Hoặc local scan với kubescape
curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | bash
kubescape scan framework nsa --include-namespaces default
```

---

## References

- Sysdig. "17 comprehensive container security best practices for 2026"
- Wiz. "8 Container Security Best Practices"
- CNCF Annual Survey 2025
- Microsoft. "Understanding the threat landscape for Kubernetes and containerized assets"
- OX Security. "Top Container Security Best Practices in 2026"

---

*→ Tiếp theo: [Part 2: Container Image Security & Supply Chain](./part2-image-security-supply-chain.md)*
