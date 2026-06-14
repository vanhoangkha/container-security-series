<p align="center">
  <img src="https://img.shields.io/badge/Container-Security-blue?style=for-the-badge&logo=docker" alt="Container Security"/>
  <img src="https://img.shields.io/badge/Kubernetes-Hardening-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white" alt="Kubernetes"/>
  <img src="https://img.shields.io/badge/2026-Edition-green?style=for-the-badge" alt="2026"/>
</p>

<h1 align="center">🔒 Container Security Series</h1>

<p align="center">
  <strong>Comprehensive 8-part series covering container security from image to runtime, from build to incident response — including AI-era threats.</strong>
</p>

<p align="center">
  <a href="#-table-of-contents">Contents</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-recommended-stack">Stack</a> •
  <a href="#-key-statistics">Stats</a> •
  <a href="#-contributing">Contributing</a>
</p>

<p align="center">
  <img src="https://img.shields.io/github/stars/vanhoangkha/container-security-series?style=social" alt="Stars"/>
  <img src="https://img.shields.io/github/forks/vanhoangkha/container-security-series?style=social" alt="Forks"/>
  <img src="https://img.shields.io/github/license/vanhoangkha/container-security-series" alt="License"/>
  <img src="https://img.shields.io/github/last-commit/vanhoangkha/container-security-series" alt="Last Commit"/>
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs Welcome"/>
</p>

---

## 📚 Table of Contents

| # | Part | Topics | Read Time |
|---|------|--------|-----------|
| 1 | [Introduction & Overview](./docs/part1-introduction-overview.md) | Attack surface, lifecycle framework, threat landscape, hands-on labs | 15 min |
| 2 | [Image Security & Supply Chain](./docs/part2-image-security-supply-chain.md) | Image scanning, SBOM, Sigstore/Cosign, SLSA, Dockerfile hardening | 25 min |
| 3 | [Runtime Security & Monitoring](./docs/part3-runtime-security-monitoring.md) | eBPF, Falco, Tetragon, Seccomp, AppArmor, AI agent detection | 30 min |
| 4 | [Kubernetes Security Hardening](./docs/part4-kubernetes-security-hardening.md) | RBAC, PSS, Network Policies, Secrets, Admission Control, Terraform | 30 min |
| 5 | [Network Security & Zero Trust](./docs/part5-network-security-zero-trust.md) | mTLS, Service Mesh (Istio/Cilium), SPIFFE, micro-segmentation | 25 min |
| 6 | [Security Tools & Platforms](./docs/part6-security-tools-platforms.md) | Trivy, Falco, Wiz, Sysdig, Aqua, Snyk — comparison & cost analysis | 20 min |
| 7 | [Best Practices & Checklist](./docs/part7-best-practices-checklist.md) | 75-item checklist, maturity model, roadmap, automation scripts | 20 min |
| 8 | [K8s Security in the AI Era](./docs/part8-kubernetes-security-ai-era.md) | AI agent attacks, LLM threats, sandboxing, causal chain detection | 25 min |
| 9 | [Platform Engineering Reference Architecture](./docs/part9-platform-engineering-reference-architecture.md) | Terraform + ArgoCD + CI/CD + security stack (end-to-end) | 30 min |
| 10 | [Multi-tenancy & Developer Experience](./docs/part10-multitenancy-developer-experience.md) | Tenant isolation, Day-2 ops, security SLOs, golden images | 25 min |

---

## 🎯 Quick Start

**New to container security?** Read in order (Part 1 → 8).

**Need something specific?**

| Question | Go To |
|----------|-------|
| "What tools should I use?" | [Part 6 — Tools & Platforms](./docs/part6-security-tools-platforms.md) |
| "Give me a checklist" | [Part 7 — 75-item Checklist](./docs/part7-best-practices-checklist.md) |
| "How to harden Kubernetes?" | [Part 4 — K8s Hardening](./docs/part4-kubernetes-security-hardening.md) |
| "How to detect runtime attacks?" | [Part 3 — Runtime Security](./docs/part3-runtime-security-monitoring.md) |
| "How to secure CI/CD pipeline?" | [Part 2 — Supply Chain](./docs/part2-image-security-supply-chain.md) |
| "What about AI/LLM workloads?" | [Part 8 — AI Era](./docs/part8-kubernetes-security-ai-era.md) |
| "I'm a platform engineer — where to start?" | [Part 9 — Reference Architecture](./docs/part9-platform-engineering-reference-architecture.md) |
| "Multi-tenancy and Day-2 ops?" | [Part 10 — Multi-tenancy & DX](./docs/part10-multitenancy-developer-experience.md) |
| "Give me deployable code" | [examples/](./examples/) — Terraform, Kyverno, Falco, scripts |
| "How to become a Platform Engineer?" | [Career Guide](./docs/platform-engineer-career-guide.md) |

---

## 🛠️ Recommended Stack

### Open Source (Free)

```
Build:    Trivy + Syft + Grype + Cosign + Hadolint
Deploy:   Kyverno + Sigstore Policy Controller
Runtime:  Falco + Tetragon + Seccomp
Network:  Cilium (CNI + Service Mesh + Hubble)
Monitor:  Prometheus + Grafana + OpenSearch
```

### Enterprise

```
CNAPP:    Wiz (agentless) | Sysdig (runtime) | Aqua (container-native)
DevSec:   Snyk (developer-first) | Docker Scout
Comply:   Prisma Cloud (broadest coverage)
```

---

## 📊 Key Statistics (2026)

| Metric | Value | Source |
|--------|-------|--------|
| Organizations using containers in production | 56% | CNCF Survey 2025 |
| K8s users in production | 82% | CNCF Survey 2025 |
| Time to first attack on new K8s cluster | 18 min | Wiz Research |
| Container lifespan (70% of containers) | < 5 min | Sysdig |
| Malicious packages published (2025) | 454,000+ | Sonatype |
| K8s security incidents (organizations) | 93% | CNCF Survey |
| AI breaches involving agentic systems | 1 in 8 | HiddenLayer 2026 |
| Container lateral movement attacks (YoY) | +34% | Vectra AI |

---

## 🏗️ Repository Structure

```
container-security-series/
├── README.md
├── LICENSE
├── CONTRIBUTING.md
├── .gitignore
├── docs/
│   ├── part1-introduction-overview.md
│   ├── part2-image-security-supply-chain.md
│   ├── part3-runtime-security-monitoring.md
│   ├── part4-kubernetes-security-hardening.md
│   ├── part5-network-security-zero-trust.md
│   ├── part6-security-tools-platforms.md
│   ├── part7-best-practices-checklist.md
│   ├── part8-kubernetes-security-ai-era.md
│   ├── part9-platform-engineering-reference-architecture.md
│   └── part10-multitenancy-developer-experience.md
└── examples/
    ├── terraform/main.tf          # Hardened EKS (VPC + KMS + ECR + GuardDuty)
    ├── kyverno/policies.yaml      # 10 production admission policies
    ├── falco/values.yaml          # Production Helm values
    ├── falco/custom-rules.yaml    # 10 custom detection rules
    └── scripts/
        ├── bootstrap-security-stack.sh   # Deploy full stack (run once)
        ├── security-audit.sh             # Quick posture assessment
        └── onboard-tenant.sh             # Create secured namespace
```

---

## 📖 What You'll Learn

- ✅ How container security works across the entire lifecycle
- ✅ Practical Dockerfile hardening (before/after examples)
- ✅ SBOM generation, image signing with Sigstore/Cosign
- ✅ Runtime threat detection with Falco & eBPF
- ✅ Kubernetes hardening (RBAC, PSS, NetworkPolicies, Secrets)
- ✅ Zero Trust networking with mTLS and service mesh
- ✅ Tool comparison with cost analysis (OSS vs Commercial)
- ✅ Ready-to-run automation scripts for cluster hardening
- ✅ Terraform modules for hardened EKS clusters
- ✅ **NEW:** AI agent threats and LLM workload security (2026)

---

## Mapping Voi Platform Engineering Roadmap

Series nay cover phan **Security** cua [Platform Engineering Roadmap](https://mbianchidev.github.io/platform-engineering-roadmap/) (by mbianchidev).

| Roadmap Topic | Series Coverage | Part |
|--------------|-----------------|------|
| Encryption, Certificates, TLS, PKI | mTLS, Sigstore, certificate management | 2, 5 |
| Authentication, Authorization, IAM | RBAC, Pod Identity, OIDC, Service Accounts | 4, 9 |
| OPA (Open Policy Agent) | OPA Gatekeeper + Kyverno so sanh chi tiet | 4, 6 |
| DevSecOps (SAST, DAST, Container Scanning) | Trivy, Grype, Hadolint, CI/CD pipeline | 2, 6, 9 |
| Threat Detection | Falco, Tetragon, GuardDuty, eBPF | 3, 8 |
| CNAPP, CDR | Wiz, Sysdig, Aqua, Prisma Cloud | 6 |
| Container (Docker, OCI, Registry) | Image hardening, scanning, signing, SBOM | 2 |
| Kubernetes (full topic list) | Hardening, PSS, NetworkPolicy, Secrets | 3, 4, 5 |
| Service Mesh (Istio, Linkerd) | mTLS, AuthorizationPolicy, Cilium mesh | 5 |
| CNI (Cilium) | Cilium vs Calico, L7 policies, Hubble | 5 |
| GitOps (ArgoCD, FluxCD) | ArgoCD security config, drift detection | 9 |
| IaC (Terraform) | Hardened EKS module, KMS, GuardDuty | 9 |
| Rollout (Canary, Blue-Green) | Argo Rollouts + Falco, auto-rollback | 9 |
| Observability (Prometheus, Grafana) | Security dashboards, SLOs, alerting | 9 |
| Platform Engineering (IDP, DevEx) | Self-service, golden images, onboarding | 10 |
| Multitenancy | Hard vs soft, namespace isolation, quotas | 10 |
| AI Workload Security | AI agent attacks, LLM threats, sandboxing | 8 |

---

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

- 🐛 Found an error? Open an issue
- 💡 Have a suggestion? Open a PR
- ⭐ Found this useful? Give it a star!

---

## 👤 Author

**Van Hoang Kha**

- GitHub: [@vanhoangkha](https://github.com/vanhoangkha)

---

## 📄 License

This project is licensed under the [MIT License](./LICENSE).

---

## 🙏 Sources & Acknowledgments

Based on research from 40+ industry sources including:

Sysdig • Wiz • Docker • AquilaX • CNCF • Microsoft • Aqua Security • Falco Project • ARMO • Sigstore • AppSecSanta • TasrieIT • BeyondScale • HiddenLayer • Sonatype • GitGuardian • and more.

---

<p align="center">
  <strong>⭐ Star this repo if you find it useful!</strong>
</p>

<p align="center">
  <em>"Shift left, but never skip right." — Container Security Series</em>
</p>
