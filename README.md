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
├── README.md                 ← You are here
├── LICENSE                   ← MIT License
├── CONTRIBUTING.md           ← How to contribute
├── .gitignore
└── docs/
    ├── part1-introduction-overview.md
    ├── part2-image-security-supply-chain.md
    ├── part3-runtime-security-monitoring.md
    ├── part4-kubernetes-security-hardening.md
    ├── part5-network-security-zero-trust.md
    ├── part6-security-tools-platforms.md
    ├── part7-best-practices-checklist.md
    └── part8-kubernetes-security-ai-era.md
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
