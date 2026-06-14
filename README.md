# 🔒 Container Security Series - Toàn Diện (2026 Edition)

> Comprehensive 7-part series covering container security from image to runtime, from build to incident response.

---

## 📚 Table of Contents

| Part | Title | Topics |
|------|-------|--------|
| [**Part 1**](./part1-introduction-overview.md) | Introduction & Overview | Attack surface, lifecycle framework, security matrix, threats |
| [**Part 2**](./part2-image-security-supply-chain.md) | Image Security & Supply Chain | Image scanning, SBOM, Sigstore/Cosign, SLSA, minimal images |
| [**Part 3**](./part3-runtime-security-monitoring.md) | Runtime Security & Monitoring | eBPF, Falco, Tetragon, Seccomp, AppArmor, incident response |
| [**Part 4**](./part4-kubernetes-security-hardening.md) | Kubernetes Security Hardening | RBAC, PSS, Network Policies, Secrets, API Server, CIS Benchmark |
| [**Part 5**](./part5-network-security-zero-trust.md) | Network Security & Zero Trust | mTLS, Service Mesh, Cilium, SPIFFE/SPIRE, micro-segmentation |
| [**Part 6**](./part6-security-tools-platforms.md) | Security Tools & Platforms | Trivy, Falco, Kyverno, CNAPP platforms comparison |
| [**Part 7**](./part7-best-practices-checklist.md) | Best Practices & Checklist | 75-item checklist, maturity model, roadmap, incident playbook |
| [**Part 8**](./part8-kubernetes-security-ai-era.md) | **K8s Security in the AI Era** 🆕 | AI agent attacks, LLM threat model, sandboxing, detection |

---

## 🎯 Quick Start

If you're new to container security, read in order. If you need specific topics:

- **"What tools should I use?"** → [Part 6](./part6-security-tools-platforms.md)
- **"Give me a checklist"** → [Part 7](./part7-best-practices-checklist.md)
- **"How to harden Kubernetes?"** → [Part 4](./part4-kubernetes-security-hardening.md)
- **"How to detect attacks at runtime?"** → [Part 3](./part3-runtime-security-monitoring.md)
- **"How to secure my CI/CD pipeline?"** → [Part 2](./part2-image-security-supply-chain.md)

---

## 🛠️ Recommended OSS Stack

```
Build:    Trivy + Syft + Grype + Cosign
Deploy:   Kyverno + Sigstore Policy Controller
Runtime:  Falco + Tetragon + Seccomp
Network:  Cilium (CNI + Service Mesh + Hubble)
Monitor:  Prometheus + Grafana + OpenSearch
```

---

## 📊 Key Statistics (2026)

- **56%** organizations use containers in production
- **82%** container users deploy Kubernetes in production
- **18 minutes** — time to first attack on new K8s cluster
- **70%** containers live less than 5 minutes
- **454,000+** malicious packages published in 2025
- **50-60 CVEs** in standard public container images

---

## 📅 Created

June 2026 | Based on research from Sysdig, Wiz, Docker, AquilaX, CNCF, Microsoft, Aqua Security, AppSecSanta, and 30+ industry sources.
