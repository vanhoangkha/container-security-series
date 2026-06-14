# Container Security Series - Part 6: Security Tools & Platforms

> **Series:** Container Security Toàn Diện (2026 Edition)
> **Author:** Security Research Series
> **Date:** June 2026

---

## 1. Container Security Tool Landscape (2026)

Container security tools bao gồm 7 categories chính:

```
┌─────────────────────────────────────────────────────────┐
│              CONTAINER SECURITY TOOL CATEGORIES           │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  1. Image Scanning & Vulnerability Management             │
│     Trivy, Grype, Docker Scout, Snyk Container           │
│                                                           │
│  2. Runtime Security & Threat Detection                   │
│     Falco, Tetragon, Sysdig Secure                       │
│                                                           │
│  3. Supply Chain Security                                 │
│     Cosign/Sigstore, Syft, Notary, SLSA                  │
│                                                           │
│  4. Policy Enforcement & Admission Control                │
│     Kyverno, OPA Gatekeeper, Kubewarden                  │
│                                                           │
│  5. Configuration & Compliance Scanning                   │
│     kube-bench, Kubescape, Checkov, Trivy IaC            │
│                                                           │
│  6. Network Security                                      │
│     Cilium, Calico, Istio, Linkerd                       │
│                                                           │
│  7. Full-Stack CNAPP Platforms                            │
│     Wiz, Aqua Security, Sysdig, Prisma Cloud, Snyk      │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Open-Source Image Scanning Tools

### 2.1. Trivy (Aqua Security)

**The Swiss Army knife** of security scanning — single binary, zero configuration.

| Aspect | Details |
|--------|---------|
| **License** | Apache 2.0 |
| **GitHub Stars** | 34,800+ |
| **Scans** | Container images, filesystems, git repos, IaC, K8s clusters, SBOM |
| **Vuln DBs** | NVD, GitHub Advisory, Red Hat, Alpine, Ubuntu, etc. |
| **Languages** | Java, Node, Python, Go, Rust, Ruby, PHP, .NET |
| **Output** | JSON, SARIF, Table, CycloneDX, SPDX, HTML |
| **Best for** | Teams wanting one tool for everything |

```bash
# Image scan
trivy image --severity HIGH,CRITICAL myregistry.com/myapp:latest

# Filesystem scan (source + secrets)
trivy fs --scanners vuln,secret,misconfig .

# Kubernetes cluster scan
trivy k8s --report summary cluster

# IaC scan (Terraform, Helm, K8s YAML)
trivy config ./terraform/

# Generate SBOM
trivy image --format cyclonedx --output sbom.json myapp:latest

# Scan in CI with exit code
trivy image --exit-code 1 --severity CRITICAL myapp:latest
```

**Strengths:** Single binary, zero dependencies, fastest scan time, absorbed tfsec for IaC, huge community.  
**Limitations:** No runtime protection, no CNAPP features, community vuln DB only.

### 2.2. Grype (Anchore)

**Focused vulnerability scanner** — pairs with Syft for SBOM-first scanning.

```bash
# Scan image
grype myregistry.com/myapp:latest

# Scan from SBOM (faster, more accurate)
grype sbom:./sbom.cdx.json

# Fail on severity
grype myapp:latest --fail-on high

# JSON output for automation
grype myapp:latest --output json --file results.json

# Custom config (.grype.yaml)
# Ignore specific CVEs, set severity thresholds
```

**Strengths:** Fast, SBOM-first workflow, excellent Syft integration, customizable ignore rules.  
**Best paired with:** Syft (SBOM generation) in CI/CD pipelines.

### 2.3. Clair (CoreOS/Red Hat)

```bash
# Run Clair server
docker run -d --name clair \
  -p 6060:6060 -p 6061:6061 \
  quay.io/projectquay/clair:latest

# Scan via API (integrated into registries like Quay)
```

**Best for:** Integration with Red Hat Quay, air-gapped environments.

### 2.4. Docker Scout

```bash
# Integrated into Docker Desktop
docker scout quickview myapp:latest
docker scout cves myapp:latest
docker scout recommendations myapp:latest

# Compare images
docker scout compare myapp:v1.0 myapp:v2.0
```

**Best for:** Docker Desktop users, base image recommendations, quick local scanning.

---

## 3. Runtime Security Tools

### 3.1. Falco (CNCF Graduated)

| Aspect | Details |
|--------|---------|
| **Project** | CNCF Graduated (2024) |
| **Detection** | System calls via eBPF or kernel module |
| **Rules** | YAML DSL, community library + custom |
| **Outputs** | JSON, gRPC, HTTP, Kafka |
| **Integration** | Falcosidekick (30+ output targets) |
| **Performance** | 1-5% CPU overhead with eBPF driver |
| **Best for** | Comprehensive runtime detection |

```bash
# Deploy on Kubernetes
helm install falco falcosecurity/falco \
  --set driver.kind=ebpf \
  --set falcosidekick.enabled=true

# Key detections:
# - Shell in container
# - Crypto mining
# - Container escape attempts
# - Credential access
# - Lateral movement
# - File integrity monitoring
```

### 3.2. Cilium Tetragon (CNCF Sandbox)

| Aspect | Details |
|--------|---------|
| **Project** | CNCF Sandbox |
| **Detection + Enforcement** | eBPF-based, can BLOCK syscalls |
| **Policies** | TracingPolicy CRDs |
| **Unique** | Kills malicious processes before syscall completes |
| **Best for** | Critical enforcement points |

```bash
# Deploy
helm install tetragon cilium/tetragon -n kube-system

# Real-time event stream
kubectl exec -n kube-system ds/tetragon -c tetragon -- \
  tetra getevents -o compact
```

### 3.3. Comparison: Detection Tools

| Feature | Falco | Tetragon | GuardDuty (EKS) | Sysdig Secure |
|---------|-------|----------|-----------------|---------------|
| **Type** | OSS | OSS | Managed | Commercial |
| **Detection** | ✅ | ✅ | ✅ | ✅ |
| **Enforcement** | ❌ (alert only) | ✅ (Sigkill) | ❌ | ✅ |
| **Custom rules** | ✅ | ✅ | ❌ | ✅ |
| **Cloud integration** | Via Falcosidekick | Hubble | Native AWS | Multi-cloud |
| **Overhead** | Low | Low | Zero (agentless) | Medium |
| **Cost** | Free | Free | Pay per use | License |

---

## 4. Supply Chain Security Tools

### 4.1. Sigstore Ecosystem

| Tool | Function |
|------|----------|
| **Cosign** | Sign & verify container images and artifacts |
| **Fulcio** | Certificate Authority (short-lived certs via OIDC) |
| **Rekor** | Transparency log (append-only, public) |
| **Sigstore policy-controller** | K8s admission webhook for signature verification |

```bash
# Keyless signing (recommended)
cosign sign --yes myregistry.com/myapp@sha256:abc...

# Verify
cosign verify \
  --certificate-identity-regexp="https://github.com/myorg/.*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  myregistry.com/myapp@sha256:abc...

# Attach SBOM attestation
cosign attest --yes --predicate sbom.json --type cyclonedx \
  myregistry.com/myapp@sha256:abc...
```

### 4.2. Syft (Anchore)

```bash
# Generate SBOM from image
syft myapp:latest -o cyclonedx-json=sbom.cdx.json
syft myapp:latest -o spdx-json=sbom.spdx.json

# Scan source directory
syft dir:. -o cyclonedx-json=source-sbom.json

# Supports: Alpine, Debian, RPM, npm, pip, Go, Maven, Rust, Ruby
```

### 4.3. Supply Chain Tool Selection

| Need | Tool | Notes |
|------|------|-------|
| SBOM generation | **Syft** | Widest language support |
| Image signing | **Cosign** (keyless) | No key management |
| Signature verification at admission | **Sigstore Policy Controller** or **Kyverno** | K8s native |
| Vulnerability scanning from SBOM | **Grype** | Syft → Grype workflow |
| Build provenance | **SLSA GitHub Generator** | SLSA Level 3 |
| Transparency & audit | **Rekor** | Public, immutable log |

---

## 5. Policy Enforcement Tools

### 5.1. Kyverno

| Aspect | Details |
|--------|---------|
| **Type** | Kubernetes-native policy engine |
| **Language** | YAML (no Rego required) |
| **Modes** | Validate, Mutate, Generate, Verify Images |
| **CNCF** | Graduated |
| **Best for** | Teams wanting simpler policy language |

```yaml
# Example policies Kyverno excels at:
# - Require labels on all resources
# - Disallow latest tag
# - Add default security context
# - Verify image signatures
# - Generate NetworkPolicy for new namespaces
# - Require resource limits
```

### 5.2. OPA Gatekeeper

| Aspect | Details |
|--------|---------|
| **Type** | General-purpose policy engine |
| **Language** | Rego (OPA's policy language) |
| **Modes** | Validate (audit + enforce) |
| **CNCF** | Graduated (OPA) |
| **Best for** | Complex policy logic, multi-platform policies |

```rego
# Example Rego policy
package k8s.security

violation[{"msg": msg}] {
    container := input.review.object.spec.containers[_]
    not container.securityContext.runAsNonRoot
    msg := sprintf("Container %v must set runAsNonRoot", [container.name])
}
```

### 5.3. Kyverno vs OPA Gatekeeper

| Criteria | Kyverno | OPA Gatekeeper |
|----------|---------|----------------|
| **Policy language** | YAML/JSON | Rego |
| **Learning curve** | Low | High |
| **Mutating** | ✅ Native | ❌ Separate webhook |
| **Generate resources** | ✅ | ❌ |
| **Image verification** | ✅ Native | Via external data |
| **Audit mode** | ✅ | ✅ |
| **Multi-platform** | K8s only | Any (OPA is general) |
| **Community** | Growing fast | Established |

---

## 6. Configuration & Compliance Tools

### 6.1. Kubescape

```bash
# NSA/CISA hardening scan
kubescape scan framework nsa --include-namespaces production

# CIS benchmark
kubescape scan framework cis-v1.23-t1.0.1

# MITRE ATT&CK for K8s
kubescape scan framework mitre

# Scan YAML before deploy
kubescape scan *.yaml --format junit --output results.xml
```

### 6.2. kube-bench

```bash
# CIS Kubernetes Benchmark
kube-bench run --targets=master,node,policies --json > results.json

# As Kubernetes Job
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
```

### 6.3. Checkov (Prisma Cloud)

```bash
# Scan Terraform
checkov -d ./terraform/ --framework terraform

# Scan Kubernetes manifests
checkov -d ./k8s/ --framework kubernetes

# Scan Dockerfile
checkov --file Dockerfile --framework dockerfile

# All frameworks
checkov -d . --output json > checkov-results.json
```

### 6.4. Tool Comparison

| Tool | Frameworks | Focus | Output |
|------|-----------|-------|--------|
| **Kubescape** | NSA, CIS, MITRE, SOC2 | K8s cluster + manifests | JSON, PDF, SARIF |
| **kube-bench** | CIS only | Running cluster nodes | JSON, JUnit |
| **Checkov** | 1000+ policies | IaC (Terraform, K8s, Docker) | JSON, SARIF, JUnit |
| **Trivy** | CIS, custom | Images + IaC + config | JSON, SARIF, Table |

---

## 7. Full-Stack CNAPP Platforms (Commercial)

### 7.1. Platform Comparison

| Platform | Architecture | Strengths | Pricing Model |
|----------|-------------|-----------|---------------|
| **Wiz** | Agentless (cloud graph) | Cloud context, risk prioritization, fast deploy | Per workload |
| **Aqua Security** | Agent-based (container-native) | Deep container security, vShield, runtime | Per node/workload |
| **Sysdig** | Agent (eBPF) + Falco | Runtime insights, 555 benchmark, open-source core | Per node |
| **Prisma Cloud** (Palo Alto) | Full-stack CNAPP | Broadest coverage, CSPM + CWPP | Per credit |
| **Snyk** | Developer-integrated | Developer experience, fix PRs, reachability analysis | Per developer |

### 7.2. Wiz

**Philosophy:** Agentless, cloud-native security graph

```
Strengths:
- Zero-agent deployment (API-based scanning)
- Cloud security graph (visualize attack paths)
- Covers: CSPM, CWPP, CIEM, DSPM, container security
- Fast time-to-value (minutes to first findings)
- Context-rich prioritization

Best for:
- Organizations wanting agentless approach
- Multi-cloud environments
- Risk prioritization across cloud + containers
- Teams with limited security headcount
```

### 7.3. Aqua Security

**Philosophy:** Container-native, full lifecycle security

```
Strengths:
- vShield: runtime protection without kernel access
- Image scanning + hardening
- DTA (Dynamic Threat Analysis) - sandbox execution
- Supply chain security
- Kubernetes security
- Maintained Trivy (open source)

Best for:
- Deep container security needs
- Air-gapped/on-prem environments
- Organizations needing runtime enforcement
- Teams already using Trivy wanting enterprise upgrade
```

### 7.4. Sysdig

**Philosophy:** Runtime insights powered by open source (Falco)

```
Strengths:
- Built on Falco (CNCF graduated)
- 555 Benchmark: detect in 5s, correlate in 5m, respond in 5m
- Runtime insights for prioritization
- In-use vulnerability detection
- Cloud detection & response (CDR)
- Kubernetes security posture

Best for:
- Runtime-first security approach
- Teams wanting open-source foundation + enterprise features
- Detection & response focus
- "Only 1% of vulnerabilities matter" philosophy
```

### 7.5. Snyk

**Philosophy:** Developer-first security

```
Strengths:
- Integrated into IDE and git workflows
- Automatic fix PRs for vulnerabilities
- Reachability analysis (is vuln actually called?)
- Container image scanning + base image recommendations
- Curated vulnerability database
- Developer-friendly UX

Pricing:
- Free tier available
- $25/developer/month (Team)

Best for:
- Developer-centric organizations
- Shift-left focused teams
- Organizations wanting fix suggestions, not just findings
- Small to medium teams
```

### 7.6. Prisma Cloud (Palo Alto)

**Philosophy:** Full-stack CNAPP, broadest coverage

```
Strengths:
- Widest feature set (CSPM, CWPP, CAS, CIEM, DSPM)
- Code-to-cloud coverage
- Integrated with Palo Alto security ecosystem
- Compliance: 100+ frameworks out of box
- CI/CD security

Best for:
- Large enterprises needing one platform
- Organizations already in Palo Alto ecosystem
- Complex compliance requirements
- Teams needing broadest feature coverage
```

---

## 8. How to Choose: Decision Framework

### 8.1. By Organization Size

| Size | Recommended Stack |
|------|------------------|
| **Startup / Small** | Trivy + Falco + Kyverno + Cilium |
| **Medium** | Snyk + Falco + Kyverno + Istio/Cilium |
| **Enterprise** | CNAPP (Wiz/Sysdig/Aqua) + Falco + OPA + Istio |
| **Regulated** | CNAPP + External Secrets + Full audit pipeline |

### 8.2. By Primary Concern

| Concern | Best Tool(s) |
|---------|-------------|
| "We need free/OSS" | Trivy + Falco + Kyverno + Syft + Cosign |
| "Developer experience" | Snyk + Docker Scout |
| "Runtime threats" | Sysdig or Falco + Tetragon |
| "Cloud-wide visibility" | Wiz (agentless) |
| "Deep container security" | Aqua Security |
| "Compliance" | Prisma Cloud or Sysdig |
| "Supply chain" | Sigstore ecosystem + Trivy/Grype |

### 8.3. Build vs Buy

| Factor | Open Source | Commercial |
|--------|-----------|-----------|
| **Cost** | Free (but ops cost) | $50K-500K+/year |
| **Time to value** | Weeks-months | Hours-days |
| **Maintenance** | Your team | Vendor |
| **Customization** | Unlimited | Limited |
| **Support** | Community | 24/7 SLA |
| **Integration** | DIY | Pre-built |
| **Compliance reports** | DIY | Out of box |

### 8.4. Detailed Cost Comparison (100-node cluster)

| Cost Factor | Full OSS Stack | Snyk Team | Sysdig | Wiz |
|-------------|---------------|-----------|--------|-----|
| **License/year** | $0 | ~$30K (25 devs) | ~$150K | ~$120K |
| **Engineer time** (setup) | 2-3 months | 1-2 weeks | 1 week | 1 day |
| **Ongoing ops** (FTE) | 0.5 FTE (~$75K) | 0.1 FTE | 0.2 FTE | 0.1 FTE |
| **Infrastructure** | $5-15K/yr (Elasticsearch, storage) | Included | Included | Included |
| **Training** | Self-study | Vendor docs | Vendor training | Vendor training |
| **Total Year 1** | ~$90K | ~$45K | ~$170K | ~$135K |
| **Total Year 2+** | ~$80K/yr | ~$35K/yr | ~$160K/yr | ~$125K/yr |
| **Coverage** | Full (with effort) | Build + partial runtime | Full | Full (agentless) |

> **Note:** OSS is cheaper Year 2+ nhưng đắt hơn Year 1 do setup time. Commercial có higher licensing nhưng lower ops cost. Break-even thường ở ~50 nodes.

### 8.5. Migration Path: OSS → Commercial

```
Stage 1: Pure OSS (0-50 nodes, 1-3 clusters)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Trivy + Falco + Kyverno + Cilium + Cosign
Total cost: ~$0 license + engineer time
Trigger to move: alert fatigue, compliance audit, >50 nodes

Stage 2: OSS Core + Commercial Add-on (50-200 nodes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Keep: Falco (runtime), Kyverno (policies), Cosign (signing)
Add:  Snyk (dev experience, fix PRs) OR Wiz (agentless visibility)
Total cost: ~$50-120K/yr
Trigger to move: multi-cloud, SOC2/PCI audit, >200 nodes

Stage 3: Full CNAPP (200+ nodes, multi-cloud, regulated)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Platform: Sysdig OR Wiz OR Aqua (pick one)
Keep: Falco (if using Sysdig), Kyverno
Total cost: $150-400K/yr
Value: unified dashboard, compliance automation, 24/7 support
```

---

## 9. The Open-Source Security Stack

### 9.1. Complete Free Stack

```
┌──────────────────────────────────────────────────────────┐
│                    FULL OSS SECURITY STACK                 │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  BUILD TIME                                                │
│  ├── Image Scanning:     Trivy                             │
│  ├── SBOM Generation:    Syft                              │
│  ├── Vuln from SBOM:     Grype                             │
│  ├── Image Signing:      Cosign (Sigstore)                 │
│  ├── IaC Scanning:       Trivy / Checkov                   │
│  └── Secret Detection:   Trivy / Gitleaks                  │
│                                                            │
│  DEPLOY TIME                                               │
│  ├── Admission Control:  Kyverno                           │
│  ├── Signature Verify:   Sigstore Policy Controller        │
│  ├── CIS Compliance:     kube-bench / Kubescape            │
│  └── Registry:           Harbor (with Trivy scanning)      │
│                                                            │
│  RUNTIME                                                   │
│  ├── Threat Detection:   Falco                             │
│  ├── Enforcement:        Tetragon                          │
│  ├── Network Security:   Cilium                            │
│  ├── Service Mesh:       Cilium / Linkerd / Istio          │
│  └── Monitoring:         Prometheus + Grafana              │
│                                                            │
│  RESPONSE                                                  │
│  ├── Alert Routing:      Falcosidekick                     │
│  ├── SIEM:              OpenSearch / ELK                    │
│  ├── Incident Response:  TheHive                           │
│  └── Forensics:          Volatility + Falco captures       │
│                                                            │
└──────────────────────────────────────────────────────────┘
```

### 9.2. Implementation Priority

```
Phase 1 (Week 1-2):  Trivy scanning in CI/CD
Phase 2 (Week 3-4):  Kyverno admission policies
Phase 3 (Week 5-6):  Falco runtime detection
Phase 4 (Week 7-8):  Cosign/Sigstore signing
Phase 5 (Week 9-10): Cilium network policies
Phase 6 (Month 3):   Full integration + alerting
```

---

## 10. Tool Integration Patterns

### 10.1. GitHub Actions Full Pipeline

```yaml
name: Container Security Pipeline
on: [push]
jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .
      
      # Step 1: Trivy scan
      - name: Trivy vulnerability scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${{ github.sha }}
          exit-code: '1'
          severity: 'CRITICAL'
      
      # Step 2: Generate SBOM
      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: myapp:${{ github.sha }}
          format: cyclonedx-json
          output-file: sbom.cdx.json
      
      # Step 3: Sign image
      - name: Sign with Cosign
        uses: sigstore/cosign-installer@v3
      - run: |
          cosign sign --yes ${{ env.REGISTRY }}/myapp@${{ steps.build.outputs.digest }}
      
      # Step 4: Attach SBOM attestation
      - run: |
          cosign attest --yes --predicate sbom.cdx.json --type cyclonedx \
            ${{ env.REGISTRY }}/myapp@${{ steps.build.outputs.digest }}
```

### 10.2. Kubernetes Cluster Security Stack

```yaml
# ArgoCD ApplicationSet for security tools
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: security-stack
spec:
  generators:
    - list:
        elements:
          - name: falco
            chart: falcosecurity/falco
            namespace: falco
          - name: kyverno
            chart: kyverno/kyverno
            namespace: kyverno
          - name: cilium
            chart: cilium/cilium
            namespace: kube-system
          - name: tetragon
            chart: cilium/tetragon
            namespace: kube-system
```

---

## 11. Evaluation Criteria

Khi đánh giá container security tools, xem xét:

| Criteria | Weight | Questions |
|----------|--------|-----------|
| **Coverage** | High | Build + Deploy + Runtime? |
| **Accuracy** | High | False positive rate? Reachability analysis? |
| **Performance** | Medium | Scan speed? Runtime overhead? |
| **Integration** | High | CI/CD, SIEM, ticketing, cloud providers? |
| **Usability** | Medium | Developer experience? Alert fatigue? |
| **Maintenance** | Medium | Self-hosted burden? Updates? |
| **Compliance** | Varies | Frameworks supported? Report generation? |
| **Cost** | High | Per developer? Per node? Per workload? |
| **Community** | Medium | Open source? Active development? |
| **Support** | Varies | SLA? Response time? |

---

## 12. Key Takeaways

1. **Trivy** is the default OSS choice — one tool for images, IaC, secrets, and K8s scanning
2. **Falco** is the standard for runtime detection (CNCF Graduated)
3. **Sigstore/Cosign** enables keyless image signing — no key management overhead
4. **Kyverno** is simpler than OPA for K8s-only policy enforcement
5. **CNAPPs** (Wiz, Sysdig, Aqua) provide integrated experience but at significant cost
6. **Full OSS stack is viable** — Trivy + Falco + Kyverno + Cilium + Sigstore
7. **Snyk excels at developer experience** — fix PRs, IDE integration
8. **Sysdig differentiates on runtime insights** — "only 1% of vulns matter"
9. **Wiz differentiates on agentless** — fastest time-to-value
10. **Start OSS, add commercial when** complexity/scale/compliance demands exceed team capacity

---

## References

- AppSecSanta. "22 Best Container Security Tools (2026)"
- CiphersSecurity. "Best Container Security Platform 2026 Compared"
- Guptadeepak. "Top 5 Container Security Tools of 2026: Trivy vs Wiz vs the Rest"
- Expert Insights. "Best 9 Container Security Tools for Development Teams (2026)"
- AppSecSanta. "Trivy vs Snyk: Container, SCA & IaC Comparison"
- Minimus.io. "Container Security Tools: Types, Features & 2026 Guide"
- SentinelOne. "Top 10 Container Security Scanning Tools for 2026"

---

*← [Part 5: Network Security & Zero Trust](./part5-network-security-zero-trust.md)*
*→ Tiếp theo: [Part 7: Best Practices & Security Checklist](./part7-best-practices-checklist.md)*
