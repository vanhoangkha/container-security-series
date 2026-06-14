# Container Security Series - Part 7: Best Practices & Comprehensive Security Checklist

> **Series:** Container Security Toàn Diện (2026 Edition)
> **Author:** Security Research Series
> **Date:** June 2026

---

## 1. Container Security Maturity Model

### Maturity Levels

| Level | Name | Description |
|-------|------|-------------|
| **1** | Reactive | No scanning, no policies, incidents discovered externally |
| **2** | Aware | Basic image scanning, some security contexts, manual processes |
| **3** | Structured | CI/CD scanning, admission control, network policies, runtime detection |
| **4** | Proactive | Full supply chain security, zero trust, automated response, continuous compliance |

### Self-Assessment

```
Level 1 → Level 2:
  □ Add image scanning to CI/CD
  □ Set runAsNonRoot on production pods
  □ Enable basic audit logging

Level 2 → Level 3:
  □ Admission controllers (Kyverno/OPA)
  □ Default-deny network policies
  □ Falco runtime detection
  □ Image signing + verification
  □ Secrets management (not env vars)

Level 3 → Level 4:
  □ SBOM generation + SLSA provenance
  □ mTLS everywhere (service mesh)
  □ Automated incident response
  □ Continuous compliance scanning
  □ SPIFFE/SPIRE workload identity
  □ eBPF enforcement (Tetragon)
```

---

## 2. Top 20 Container Security Best Practices

### BUILD TIME (Shift-Left)

#### 1. Use Minimal, Trusted Base Images
```dockerfile
# ✅ Distroless: no shell, no package manager, minimal CVEs
FROM gcr.io/distroless/static-debian12
# ✅ Alpine: small attack surface (~5MB)
FROM alpine:3.19
# ❌ Full OS images: hundreds of unnecessary packages + CVEs
FROM ubuntu:22.04
```

#### 2. Pin All Dependencies
```dockerfile
# Pin base image by digest
FROM node:20.11.1-alpine3.19@sha256:1a2b3c...
# Use lockfiles
COPY package.json package-lock.json ./
RUN npm ci --only=production
```

#### 3. Multi-Stage Builds
```dockerfile
FROM golang:1.22 AS builder
RUN CGO_ENABLED=0 go build -o /server .

FROM gcr.io/distroless/static-debian12
COPY --from=builder /server /server
USER nonroot
ENTRYPOINT ["/server"]
```

#### 4. Scan Images in CI/CD (Gate Deployments)
```bash
trivy image --exit-code 1 --severity CRITICAL myapp:latest
```

#### 5. Generate SBOM Automatically Every Build
```bash
syft myapp:latest -o cyclonedx-json=sbom.cdx.json
# Store ≥ 1 year for incident response
```

#### 6. Sign Images (Keyless)
```bash
cosign sign --yes myregistry.com/myapp@sha256:abc...
```

#### 7. Scan IaC Before Deploy
```bash
trivy config ./terraform/
checkov -d ./k8s/
kubescape scan *.yaml
```

### DEPLOY TIME (Admission Control)

#### 8. Verify Image Signatures at Admission
```yaml
# Kyverno: reject unsigned images
spec:
  verifyImages:
    - imageReferences: ["myregistry.com/*"]
      attestors:
        - entries:
            - keyless:
                subject: "https://github.com/myorg/*"
                issuer: "https://token.actions.githubusercontent.com"
```

#### 9. Enforce Pod Security Standards (Restricted)
```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
```

#### 10. Default-Deny Network Policies
```yaml
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
```

### RUNTIME (Protection)

#### 11. Never Run as Root
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
```

#### 12. Read-Only Filesystem
```yaml
securityContext:
  readOnlyRootFilesystem: true
# Use emptyDir for writable paths
volumes:
  - name: tmp
    emptyDir: {}
```

#### 13. Set Resource Limits
```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

#### 14. Deploy Runtime Threat Detection
```bash
helm install falco falcosecurity/falco --set driver.kind=ebpf
```

#### 15. Enable Seccomp Profile
```yaml
securityContext:
  seccompProfile:
    type: RuntimeDefault
```

### DATA & SECRETS

#### 16. Never Store Secrets in Environment Variables or Images
```yaml
# ✅ External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
spec:
  secretStoreRef:
    name: aws-secrets-manager
```

#### 17. Encrypt etcd at Rest
```yaml
kind: EncryptionConfiguration
resources:
  - resources: ["secrets"]
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <32-byte-key>
```

### NETWORK

#### 18. mTLS for All Service-to-Service Communication
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
spec:
  mtls:
    mode: STRICT
```

#### 19. Block Cloud Metadata Access
```yaml
egress:
  - to:
      - ipBlock:
          cidr: 0.0.0.0/0
          except:
            - 169.254.169.254/32
```

### MONITORING & RESPONSE

#### 20. Enable Kubernetes Audit Logging + Ship to SIEM
```yaml
# audit-policy.yaml
rules:
  - level: Metadata
    resources: [{resources: ["secrets"]}]
  - level: RequestResponse
    resources: [{resources: ["pods/exec"]}]
```

---

## 3. Comprehensive Security Checklist

### 🔨 BUILD PHASE

| # | Control | Priority | Status |
|---|---------|----------|--------|
| 1 | Use minimal/distroless base images | Critical | ☐ |
| 2 | Pin base image by digest (not tag) | Critical | ☐ |
| 3 | Multi-stage builds (build ≠ runtime image) | High | ☐ |
| 4 | Image scanning in CI/CD pipeline | Critical | ☐ |
| 5 | Fail pipeline on CRITICAL CVEs | Critical | ☐ |
| 6 | SBOM generated every build | High | ☐ |
| 7 | Image signed with Cosign (keyless) | High | ☐ |
| 8 | IaC scanning (Trivy/Checkov) | High | ☐ |
| 9 | Secret scanning in code/config | Critical | ☐ |
| 10 | Dependency scanning (SCA) | High | ☐ |
| 11 | No secrets in Dockerfile or image layers | Critical | ☐ |
| 12 | Non-root USER in Dockerfile | Critical | ☐ |
| 13 | .dockerignore excludes sensitive files | Medium | ☐ |
| 14 | COPY instead of ADD (no URL downloads) | Medium | ☐ |
| 15 | Locked package versions in lockfiles | High | ☐ |

### 🚀 DEPLOY PHASE

| # | Control | Priority | Status |
|---|---------|----------|--------|
| 16 | Image signature verified at admission | High | ☐ |
| 17 | Only approved registries allowed | High | ☐ |
| 18 | Pod Security Standards: Restricted | Critical | ☐ |
| 19 | Default-deny NetworkPolicy applied | Critical | ☐ |
| 20 | Resource limits set on all containers | High | ☐ |
| 21 | No `latest` tag in production | High | ☐ |
| 22 | Liveness/readiness probes configured | Medium | ☐ |
| 23 | Anti-affinity for HA | Medium | ☐ |
| 24 | PodDisruptionBudget defined | Medium | ☐ |

### 🔒 RUNTIME PHASE

| # | Control | Priority | Status |
|---|---------|----------|--------|
| 25 | `runAsNonRoot: true` | Critical | ☐ |
| 26 | `allowPrivilegeEscalation: false` | Critical | ☐ |
| 27 | `readOnlyRootFilesystem: true` | High | ☐ |
| 28 | `capabilities.drop: ["ALL"]` | Critical | ☐ |
| 29 | Seccomp profile applied | High | ☐ |
| 30 | No hostNetwork/hostPID/hostIPC | Critical | ☐ |
| 31 | No privileged containers | Critical | ☐ |
| 32 | No hostPath volumes (or strictly limited) | Critical | ☐ |
| 33 | `automountServiceAccountToken: false` | High | ☐ |
| 34 | Falco/Tetragon runtime detection | High | ☐ |
| 35 | AppArmor/SELinux profiles | Medium | ☐ |

### 🌐 NETWORK PHASE

| # | Control | Priority | Status |
|---|---------|----------|--------|
| 36 | Default-deny ingress AND egress | Critical | ☐ |
| 37 | Explicit allow rules per service pair | Critical | ☐ |
| 38 | Cloud metadata (169.254.169.254) blocked | Critical | ☐ |
| 39 | mTLS enabled (service mesh) | High | ☐ |
| 40 | L7 authorization policies | Medium | ☐ |
| 41 | Egress restricted to known endpoints | High | ☐ |
| 42 | DNS policies (prevent exfiltration) | Medium | ☐ |
| 43 | API Gateway with rate limiting + WAF | High | ☐ |
| 44 | CNI with policy enforcement (Calico/Cilium) | Critical | ☐ |

### 🔑 SECRETS & DATA

| # | Control | Priority | Status |
|---|---------|----------|--------|
| 45 | etcd encryption at rest | Critical | ☐ |
| 46 | External secrets manager (Vault/AWS SM) | High | ☐ |
| 47 | No secrets in env vars (use volumes) | High | ☐ |
| 48 | Secret rotation automated | Medium | ☐ |
| 49 | Sealed Secrets for GitOps | Medium | ☐ |
| 50 | Volume encryption (encrypted PVs) | Medium | ☐ |

### 🏛️ CONTROL PLANE

| # | Control | Priority | Status |
|---|---------|----------|--------|
| 51 | `--anonymous-auth=false` | Critical | ☐ |
| 52 | `--authorization-mode=Node,RBAC` | Critical | ☐ |
| 53 | Audit logging enabled | Critical | ☐ |
| 54 | Private API server endpoint | High | ☐ |
| 55 | TLS 1.2+ only | High | ☐ |
| 56 | etcd mutual TLS | Critical | ☐ |
| 57 | Admission controllers enabled | High | ☐ |
| 58 | Control plane logging (CloudWatch/Stackdriver) | High | ☐ |

### 👤 RBAC & IAM

| # | Control | Priority | Status |
|---|---------|----------|--------|
| 59 | No wildcard verbs (`*`) in roles | Critical | ☐ |
| 60 | No cluster-admin for workloads | Critical | ☐ |
| 61 | Service accounts per workload (not default) | High | ☐ |
| 62 | Token expiration (projected volumes) | Medium | ☐ |
| 63 | OIDC for user authentication | High | ☐ |
| 64 | Regular RBAC audit (quarterly) | High | ☐ |
| 65 | Pod Identity/IRSA for cloud access | High | ☐ |

### 📊 MONITORING & COMPLIANCE

| # | Control | Priority | Status |
|---|---------|----------|--------|
| 66 | Runtime threat detection (Falco) | High | ☐ |
| 67 | Audit logs shipped to SIEM | High | ☐ |
| 68 | CIS benchmark quarterly (kube-bench) | High | ☐ |
| 69 | Alert on suspicious pod creation | High | ☐ |
| 70 | Alert on privilege escalation attempts | Critical | ☐ |
| 71 | Network flow monitoring | Medium | ☐ |
| 72 | Continuous vulnerability re-scanning | High | ☐ |
| 73 | Incident response plan documented | High | ☐ |
| 74 | Forensics capability (snapshot, pause) | Medium | ☐ |
| 75 | Compliance reports generated (SOC2, PCI) | Varies | ☐ |

---

## 4. Implementation Roadmap

### Phase 1: Foundation (Week 1-4)

```
Priority: Stop the bleeding
━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Image scanning in CI/CD (Trivy, fail on CRITICAL)
✓ Non-root containers (runAsNonRoot: true)
✓ Drop all capabilities
✓ No privileged containers
✓ Default-deny network policies
✓ Block metadata service access
✓ Disable anonymous auth on API server
✓ Enable audit logging
```

### Phase 2: Hardening (Week 5-8)

```
Priority: Reduce attack surface
━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Pod Security Standards (Restricted)
✓ Kyverno admission policies
✓ Secrets in external manager (not etcd plaintext)
✓ Service accounts per workload
✓ automountServiceAccountToken: false
✓ readOnlyRootFilesystem: true
✓ Seccomp RuntimeDefault
✓ RBAC audit and cleanup
```

### Phase 3: Detection (Week 9-12)

```
Priority: Know when you're attacked
━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Falco deployed (eBPF driver)
✓ Alerting pipeline (Falcosidekick → Slack/PagerDuty)
✓ SIEM integration
✓ Network flow monitoring
✓ CIS benchmark automated (kube-bench)
✓ Continuous vulnerability re-scanning
```

### Phase 4: Supply Chain (Month 4-5)

```
Priority: Trust but verify
━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ SBOM generation (Syft, every build)
✓ Image signing (Cosign, keyless)
✓ Signature verification at admission
✓ Only approved registries
✓ Distroless/minimal base images
✓ Multi-stage builds
✓ Pin dependencies by digest
```

### Phase 5: Zero Trust (Month 6+)

```
Priority: Defense in depth
━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Service mesh (mTLS everywhere)
✓ L7 authorization policies
✓ SPIFFE/SPIRE workload identity
✓ Tetragon enforcement
✓ DNS policies
✓ Automated incident response
✓ Full compliance automation
```

---

## 5. Security Metrics & KPIs

### Key Metrics to Track

| Metric | Target | Measurement |
|--------|--------|-------------|
| **MTTD** (Mean Time to Detect) | < 1 minute | Falco alert timestamp - attack start |
| **MTTR** (Mean Time to Respond) | < 5 minutes | Alert → containment time |
| **Patch SLA** (Critical CVE) | < 24 hours | CVE disclosure → patched in production |
| **Scan Coverage** | 100% | Images scanned / total images |
| **Policy Compliance** | > 95% | Pods passing PSS / total pods |
| **CIS Score** | > 80% | Passing checks / total checks |
| **False Positive Rate** | < 5% | False alerts / total alerts |
| **Mean CVE Age** | < 30 days | Average age of unfixed CVEs |
| **SBOM Coverage** | 100% | Production images with SBOMs |
| **mTLS Coverage** | 100% | Services with mTLS / total services |

### Dashboard Example

```
┌─────────────────────────────────────────────────────────┐
│              CONTAINER SECURITY DASHBOARD                 │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  Critical CVEs in Production: 3    ▼ (was 12 last month)│
│  High CVEs in Production:     27   ▼ (was 45 last month)│
│  Images without scan:         0    ✓                     │
│  Unsigned images running:     2    ⚠ (investigate)       │
│                                                           │
│  Runtime Alerts (24h):        7    (5 true, 2 false pos) │
│  Network Policy Coverage:     94%  ▲                     │
│  PSS Compliance:              97%  ▲                     │
│  CIS Benchmark Score:         82%  ▲                     │
│                                                           │
│  Containers as Root:          3    ⚠ (kube-system only)  │
│  Privileged Containers:       1    ⚠ (CNI agent)         │
│  Secrets in Env Vars:         5    ❌ (migrating)         │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

---

## 6. Common Mistakes to Avoid

| Mistake | Why It's Bad | Fix |
|---------|-------------|-----|
| Scanning only in CI, not continuously | New CVEs appear after deploy | Continuous re-scanning |
| Network policies without testing | Policies may not be enforced (wrong CNI) | Test with denied traffic |
| Trusting managed K8s is "secure enough" | Shared responsibility ≠ vendor handles all | Apply full hardening |
| Alert fatigue from too many findings | Team ignores all alerts | Tune rules, prioritize runtime |
| Secrets in env vars "temporarily" | Temporary becomes permanent | External secrets from day 1 |
| Running as root "because the app requires it" | Usually fixable | Fix app permissions, use initContainers |
| No egress restrictions | Data exfiltration is trivial | Restrict to known endpoints |
| Skipping admission control | Anything can be deployed | Kyverno/OPA as enforcement |
| Only scanning base image, not layers | App vulnerabilities missed | Scan final multi-stage image |
| No incident response plan | Scramble during actual incident | Document + practice runbooks |

---

## 7. Compliance Mapping

### Framework Coverage by Practice

| Practice | PCI-DSS | SOC 2 | HIPAA | NIST 800-53 | CIS K8s |
|----------|---------|-------|-------|-------------|---------|
| Image scanning | 6.3 | CC7.1 | §164.312 | RA-5 | 5.1 |
| Non-root containers | 7.1 | CC6.1 | §164.312 | AC-6 | 5.2 |
| Network segmentation | 1.2 | CC6.6 | §164.312(e) | SC-7 | 4.1 |
| Encryption at rest | 3.4 | CC6.1 | §164.312(a) | SC-28 | 1.2 |
| Encryption in transit | 4.1 | CC6.7 | §164.312(e) | SC-8 | 4.2 |
| Audit logging | 10.2 | CC7.2 | §164.312(b) | AU-2 | 3.2 |
| Access control (RBAC) | 7.2 | CC6.3 | §164.312(a) | AC-3 | 5.1 |
| Secrets management | 3.5 | CC6.1 | §164.312(a) | SC-12 | 1.2 |
| Vulnerability management | 6.1 | CC7.1 | §164.308(a) | RA-5 | 5.1 |
| Incident response | 12.10 | CC7.3 | §164.308(a) | IR-1 | — |

---

## 8. Incident Response Playbook (Container-Specific)

### Playbook: Compromised Container

```
┌──────────────────────────────────────────────────┐
│           CONTAINER INCIDENT RESPONSE             │
├──────────────────────────────────────────────────┤
│                                                    │
│  1. DETECT (< 1 min)                              │
│     • Falco alert triggered                       │
│     • Alert routed to on-call                     │
│     • Initial assessment: severity?               │
│                                                    │
│  2. CONTAIN (< 5 min)                             │
│     • Apply quarantine NetworkPolicy              │
│     • Label pod: quarantine=true                  │
│     • DO NOT DELETE (preserve evidence)           │
│     • Snapshot container filesystem               │
│                                                    │
│  3. INVESTIGATE (< 1 hour)                        │
│     • Review Falco event timeline                 │
│     • Check: which image? which CVE?              │
│     • Check: lateral movement indicators?         │
│     • Check: data accessed/exfiltrated?           │
│     • Collect: container logs, network flows      │
│                                                    │
│  4. ERADICATE (< 4 hours)                         │
│     • Identify root cause (vuln? misconfig?)      │
│     • Patch vulnerability / fix misconfig         │
│     • Rebuild and rescan image                    │
│     • Revoke compromised credentials              │
│                                                    │
│  5. RECOVER (< 24 hours)                          │
│     • Deploy patched version                      │
│     • Verify fix with security scan               │
│     • Remove quarantine                           │
│     • Monitor for recurrence                      │
│                                                    │
│  6. LESSONS LEARNED (< 1 week)                    │
│     • Post-incident review                        │
│     • Update detection rules                      │
│     • Update policies to prevent recurrence       │
│     • Document in runbook                         │
│                                                    │
└──────────────────────────────────────────────────┘
```

### Automated Response Commands

```bash
# 1. Quarantine pod (deny all network)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: quarantine-$(date +%s)
  namespace: production
spec:
  podSelector:
    matchLabels:
      quarantine: "true"
  policyTypes: ["Ingress", "Egress"]
EOF

# 2. Label compromised pod
kubectl label pod <pod-name> quarantine=true

# 3. Capture state
kubectl logs <pod-name> > /evidence/pod-logs-$(date +%s).txt
kubectl describe pod <pod-name> > /evidence/pod-describe-$(date +%s).txt
kubectl exec <pod-name> -- cat /proc/1/status > /evidence/proc-status.txt

# 4. Snapshot filesystem
kubectl cp <pod-name>:/ /evidence/filesystem-snapshot/

# 5. Check what image is running
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].image}'

# 6. After investigation, delete
kubectl delete pod <pod-name> --grace-period=0
```

---

## 9. Series Summary & Quick Reference

### Container Security in One Page

```
┌─────────────────────────────────────────────────────────────┐
│              CONTAINER SECURITY: ONE PAGE REFERENCE           │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  BUILD:    Scan → SBOM → Sign → Minimal Image → Non-root    │
│  DEPLOY:   Verify sig → PSS Restricted → Default-deny NP    │
│  RUNTIME:  Falco → Seccomp → Least privilege → Monitor      │
│  NETWORK:  mTLS → L7 policy → Egress restrict → DNS policy  │
│  SECRETS:  External manager → Encrypted etcd → Auto-rotate  │
│  RBAC:     Least privilege → No wildcards → Audit quarterly  │
│                                                               │
│  TOOLS (OSS):  Trivy + Falco + Kyverno + Cilium + Cosign    │
│  TOOLS (Paid): Wiz | Sysdig | Aqua | Snyk | Prisma Cloud    │
│                                                               │
│  RESPOND:  Detect < 1min → Contain < 5min → Fix < 24h       │
│                                                               │
│  COMPLIANCE: CIS benchmark + OWASP K8s Top 10 + SLSA L2+    │
│                                                               │
│  MANTRA: "Shift left, but never skip right"                  │
│          (Prevention + Detection + Response = Complete)       │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Tools Quick Reference

| Need | Tool | Command |
|------|------|---------|
| Scan image | Trivy | `trivy image --severity HIGH,CRITICAL myapp:v1` |
| Generate SBOM | Syft | `syft myapp:v1 -o cyclonedx-json=sbom.json` |
| Sign image | Cosign | `cosign sign --yes registry/myapp@sha256:...` |
| Scan from SBOM | Grype | `grype sbom:./sbom.json --fail-on high` |
| K8s compliance | kube-bench | `kube-bench run --targets=master,node` |
| K8s policies | Kyverno | `kubectl apply -f policy.yaml` |
| Runtime detection | Falco | `helm install falco falcosecurity/falco` |
| Network viz | Hubble | `hubble observe --verdict DROPPED` |
| IaC scan | Checkov | `checkov -d ./terraform/` |
| Cluster scan | Kubescape | `kubescape scan framework nsa` |

### Quick-Win Scripts: Security Hardening in 10 Minutes

#### Script 1: Apply Security Baseline to All Namespaces

```bash
#!/bin/bash
# apply-security-baseline.sh — Apply PSS + default-deny to all non-system namespaces

EXCLUDED_NS="kube-system kube-public kube-node-lease istio-system calico-system"

for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  if echo "$EXCLUDED_NS" | grep -qw "$ns"; then
    echo "⏭️  Skipping system namespace: $ns"
    continue
  fi

  echo "🔒 Hardening namespace: $ns"

  # Apply Pod Security Standards (Restricted)
  kubectl label ns "$ns" \
    pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/warn=restricted \
    --overwrite

  # Apply default-deny NetworkPolicy
  kubectl apply -n "$ns" -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
EOF

  echo "  ✅ PSS Restricted + Default-deny applied"
done

echo ""
echo "🎯 Done. Run 'kubectl get ns --show-labels' to verify."
```

#### Script 2: Find and Report Security Issues

```bash
#!/bin/bash
# security-audit.sh — Quick cluster security audit

echo "═══════════════════════════════════════════════"
echo "  KUBERNETES SECURITY AUDIT REPORT"
echo "  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "═══════════════════════════════════════════════"

echo ""
echo "🔴 CRITICAL: Containers running as root"
kubectl get pods -A -o json | jq -r '
  .items[] | select(
    .spec.containers[].securityContext.runAsNonRoot != true and
    .spec.securityContext.runAsNonRoot != true
  ) | "\(.metadata.namespace)/\(.metadata.name)"
' | grep -v "kube-system" | head -20

echo ""
echo "🔴 CRITICAL: Privileged containers"
kubectl get pods -A -o json | jq -r '
  .items[] | select(
    .spec.containers[].securityContext.privileged == true
  ) | "\(.metadata.namespace)/\(.metadata.name)"
'

echo ""
echo "🟡 WARNING: Namespaces without NetworkPolicy"
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  count=$(kubectl get networkpolicy -n "$ns" --no-headers 2>/dev/null | wc -l)
  if [ "$count" -eq 0 ] && ! echo "kube-system kube-public" | grep -qw "$ns"; then
    echo "  ⚠️  $ns (0 policies)"
  fi
done

echo ""
echo "🟡 WARNING: Pods with automountServiceAccountToken (default)"
kubectl get pods -A -o json | jq -r '
  .items[] | select(
    .spec.automountServiceAccountToken != false and
    .spec.serviceAccountName != null
  ) | "\(.metadata.namespace)/\(.metadata.name)"
' | grep -v "kube-system" | wc -l | xargs -I{} echo "  {} pods with auto-mounted service account tokens"

echo ""
echo "🟡 WARNING: Images using :latest tag"
kubectl get pods -A -o json | jq -r '
  .items[].spec.containers[] | select(.image | test(":latest$") or (test(":") | not))
  | .image
' | sort -u

echo ""
echo "📊 SUMMARY"
echo "  Total pods: $(kubectl get pods -A --no-headers | wc -l)"
echo "  Namespaces with PSS: $(kubectl get ns -l pod-security.kubernetes.io/enforce --no-headers 2>/dev/null | wc -l)"
echo "  Total NetworkPolicies: $(kubectl get networkpolicy -A --no-headers 2>/dev/null | wc -l)"
```

#### Script 3: Scan All Running Images

```bash
#!/bin/bash
# scan-running-images.sh — Scan all images currently running in cluster

OUTPUT_DIR="./scan-results-$(date +%Y%m%d)"
mkdir -p "$OUTPUT_DIR"

echo "🔍 Scanning all running images..."

kubectl get pods -A -o json | jq -r '.items[].spec.containers[].image' | sort -u | while read -r image; do
  echo "  Scanning: $image"
  safe_name=$(echo "$image" | tr '/:@' '___')
  trivy image --severity HIGH,CRITICAL --format json \
    --output "$OUTPUT_DIR/${safe_name}.json" \
    "$image" 2>/dev/null

  # Count vulnerabilities
  high=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "$OUTPUT_DIR/${safe_name}.json" 2>/dev/null || echo 0)
  crit=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "$OUTPUT_DIR/${safe_name}.json" 2>/dev/null || echo 0)

  if [ "$crit" -gt 0 ]; then
    echo "    🔴 CRITICAL: $crit | HIGH: $high"
  elif [ "$high" -gt 0 ]; then
    echo "    🟡 HIGH: $high"
  else
    echo "    ✅ Clean"
  fi
done

echo ""
echo "📁 Results saved to: $OUTPUT_DIR/"
echo "📊 Summary:"
echo "  Total images scanned: $(ls $OUTPUT_DIR/*.json 2>/dev/null | wc -l)"
echo "  With CRITICAL CVEs: $(grep -l '"CRITICAL"' $OUTPUT_DIR/*.json 2>/dev/null | wc -l)"
```

---

## 10. Key Takeaways (Entire Series)

1. **Container security is a lifecycle discipline** — not a one-time setup
2. **Kubernetes ships insecure by default** — hardening is your responsibility
3. **Image scanning alone is insufficient** — runtime detection catches what scanning misses
4. **Default-deny everything** — network, RBAC, admission, then explicitly allow
5. **Supply chain is the new attack surface** — SBOM + signing + verification
6. **eBPF is the future of runtime security** — Falco + Tetragon at kernel level
7. **Zero Trust = identity-based, not perimeter-based** — mTLS everywhere
8. **Automate everything** — scanning, signing, policy enforcement, response
9. **Measure your security posture** — what gets measured gets improved
10. **Start today, iterate continuously** — perfect security doesn't exist, but good enough does

---

## References (Complete Series)

### Part 1: Introduction & Overview
- Sysdig. "17 comprehensive container security best practices for 2026"
- Wiz. "8 Container Security Best Practices"
- CNCF Annual Survey 2025
- Microsoft. "Understanding the threat landscape for Kubernetes"

### Part 2: Image Security & Supply Chain
- Docker. "What is Software Supply Chain Security?" (2026)
- Bitslovers. "SBOM + Container Signing on GitLab CI"
- Minimus.io. "Software Supply Chain Security Tools Guide"
- Sonatype. "2026 State of the Software Supply Chain"

### Part 3: Runtime Security & Monitoring
- AquilaX. "Container Runtime Security with eBPF"
- Falco Project Documentation
- AWS. "Continuous runtime security monitoring with Falco"
- Motasem. "Detect Docker Container Escapes using AppArmor, SELinux, Seccomp & Falco"

### Part 4: Kubernetes Security Hardening
- AquilaX. "Kubernetes Security Hardening: A Practical Guide"
- FreeCodeCamp. "RBAC, Pod Hardening, and Runtime Protection"
- OWASP. "Kubernetes Top 10 (2025)"
- CIS. "Kubernetes Benchmark"

### Part 5: Network Security & Zero Trust
- Wiz. "What is a Service Mesh?"
- SystemsArchitect.io. "Zero Trust vs Traditional VPC Security"
- Hokstad Consulting. "Zero Trust in Multi-Cloud Service Mesh"
- GoCodeo. "How to Implement mTLS in Microservices"

### Part 6: Security Tools & Platforms
- AppSecSanta. "22 Best Container Security Tools (2026)"
- CiphersSecurity. "Best Container Security Platform 2026"
- Guptadeepak. "Top 5 Container Security Tools of 2026"
- AppSecSanta. "Trivy vs Snyk Comparison"

### Part 7: Best Practices & Checklist
- Portainer. "10 Container Security Best Practices for Enterprises in 2026"
- ActiveState. "15 Container Security Best Practices for Engineering Teams"
- Orca Security. "Container Security Best Practices"
- OX Security. "Top Container Security Best Practices in 2026"

---

*← [Part 6: Security Tools & Platforms](./part6-security-tools-platforms.md)*

---

**🎉 End of Container Security Series**

Cảm ơn bạn đã đọc series này. Container security là một hành trình liên tục, không phải điểm đến. Bắt đầu với Phase 1, iterate continuously, và nhớ: **"Shift left, but never skip right."**
