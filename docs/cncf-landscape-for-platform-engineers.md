# CNCF Landscape Cho Platform Engineer: Chọn Gì, Bỏ Gì

> CNCF Landscape có hơn 1,000 projects/products. Bài này lọc xuống còn những gì platform engineer thực sự cần, xếp theo thứ tự ưu tiên triển khai.

---

## 1. CNCF Landscape Là Gì

CNCF (Cloud Native Computing Foundation) duy trì một bản đồ (landscape) của toàn bộ ecosystem cloud native. Tính đến 2026:

- 20 triệu developers trong ecosystem
- 300,000+ contributors
- 30+ graduated projects (production-ready, battle-tested)
- 40+ incubating projects (đang trưởng thành)
- Hàng trăm sandbox projects (đang thử nghiệm)

**Landscape URL:** https://landscape.cncf.io

**Maturity levels:**

| Level | Ý nghĩa | Dùng khi |
|-------|---------|---------|
| **Graduated** | Stable, production-proven, wide adoption | Luôn ưu tiên chọn |
| **Incubating** | Growing, used in production by early adopters | Đánh giá trước khi dùng |
| **Sandbox** | Experimental, early-stage | Chỉ thử nghiệm |

---

## 2. Sáu Categories Chính

```
PROVISIONING ──── Tạo nền móng (infra, registry, security, IaC)
     |
RUNTIME ────────── Chạy containers (storage, runtime, networking)
     |
ORCHESTRATION ──── Quản lý workloads (K8s, service mesh, API gateway)
     |
APP DEFINITION ──── Đóng gói & deliver (Helm, CI/CD, database)
     |
OBSERVABILITY ───── Nhìn thấy hệ thống (metrics, logs, traces)
     |
PLATFORM ────────── Nền tảng cho developer (IDP, certified K8s)
```

---

## 3. Stack Khuyến Nghị Cho Platform Engineer

### Tier 1: Bắt Buộc (deploy tuần đầu)

| Project | CNCF Status | Vai trò | Tại sao bắt buộc |
|---------|-------------|---------|-------------------|
| **Kubernetes** | Graduated | Orchestration | Nền tảng cho tất cả |
| **containerd** | Graduated | Container runtime | Default runtime cho K8s |
| **CoreDNS** | Graduated | Service discovery | Built-in với K8s |
| **etcd** | Graduated | State store | K8s control plane |

### Tier 2: Deploy Trong Tháng Đầu

| Project | CNCF Status | Vai trò | Tại sao quan trọng |
|---------|-------------|---------|---------------------|
| **Cilium** | Graduated | CNI + Network Policy + Mesh | eBPF, L7 policies, Hubble observability |
| **ArgoCD** (Argo) | Graduated | GitOps delivery | Single source of truth từ Git |
| **Prometheus** | Graduated | Metrics + alerting | Monitoring nền tảng |
| **Kyverno** | Graduated | Policy enforcement | Admission control, PSS, image verify |

### Tier 3: Deploy Trong Quý Đầu

| Project | CNCF Status | Vai trò | Tại sao cần |
|---------|-------------|---------|------------|
| **Falco** | Graduated | Runtime security | Phát hiện tấn công real-time |
| **Helm** | Graduated | Package management | Deploy ứng dụng phức tạp |
| **OpenTelemetry** | Graduated | Traces + metrics + logs | Unified observability |
| **Crossplane** | Graduated | IaC control plane | Quản lý cloud resources trong K8s |
| **Harbor** | Graduated | Container registry | Private registry + scanning |
| **External Secrets** | Incubating | Secrets sync | Pull từ AWS SM/Vault vào K8s |

### Tier 4: Khi Scale (6+ tháng)

| Project | CNCF Status | Vai trò | Khi nào cần |
|---------|-------------|---------|------------|
| **Backstage** | Graduated | Developer portal | Khi có >5 teams, cần self-service UI |
| **Istio** | Graduated | Service mesh (full-featured) | Khi cần L7 auth policies phức tạp |
| **Flux** | Graduated | GitOps (alternative) | Nếu cần image automation native |
| **Jaeger** | Graduated | Distributed tracing | Debug microservices chậm |
| **Fluentd** | Graduated | Log collection | Centralized logging |
| **SPIFFE/SPIRE** | Incubating | Workload identity | Cross-cluster, cross-cloud identity |
| **Linkerd** | Graduated | Service mesh (lightweight) | Nếu Istio quá nặng |
| **Argo Rollouts** | (part of Argo) | Progressive delivery | Canary, blue-green |
| **Kargo** | Sandbox | Environment promotion | Automated promotion dev→staging→prod |

---

## 4. Những Gì KHÔNG Cần

CNCF Landscape có hơn 1,000 entries. Phần lớn bạn không cần. Quy tắc lọc:

| Bỏ qua khi | Ví dụ |
|------------|-------|
| Đã có giải pháp tốt hơn (Graduated) | Dùng Cilium thay vì Flannel (không enforce NetworkPolicy) |
| Quá niche cho team nhỏ | Spinnaker (thay bằng ArgoCD đơn giản hơn) |
| Trùng lặp với tool khác | Thanos/Cortex (khi chưa cần multi-cluster Prometheus) |
| Sandbox chưa stable | Hầu hết sandbox projects — chờ incubating |
| Proprietary wrapped in OSS | Các products cần enterprise license ngay |

### Cụ thể: Những lựa chọn đã có câu trả lời rõ (2026)

| Câu hỏi | Trả lời | Lý do |
|---------|---------|-------|
| CNI nào? | **Cilium** | eBPF, L7, Hubble, CNCF Graduated, thay thế Calico cho hầu hết use cases |
| GitOps nào? | **ArgoCD** (default) | UI, multi-cluster, phổ biến nhất. FluxCD nếu cần image automation |
| Policy engine? | **Kyverno** | Kubernetes-native YAML, dễ hơn OPA Rego cho K8s-only |
| Service mesh? | **Cilium** (sidecar-less) | Nếu chỉ cần mTLS + L7 policy. Istio nếu cần full features |
| Monitoring? | **Prometheus + Grafana** | De facto standard |
| Tracing? | **OpenTelemetry** | Unified, thay Jaeger/Zipkin riêng lẻ |
| Registry? | **Harbor** (self-hosted) hoặc ECR/GCR (managed) | Scanning + RBAC built-in |
| IaC? | **Terraform** (bootstrap) + **Crossplane** (ongoing) | Pattern 2026 |
| Runtime security? | **Falco** | CNCF Graduated, de facto standard |
| Developer portal? | **Backstage** | CNCF Graduated, khi team đủ lớn (>5 teams) |

---

## 5. Architecture Sử Dụng CNCF Projects

```
Developer
    |
    | git push
    v
+------------------+
| CI Pipeline      |  Tools: GitHub Actions / Tekton
| - Build          |
| - Trivy scan     |  ← (không CNCF nhưng từ Aqua, maintainer Falco)
| - Cosign sign    |  ← Sigstore (CNCF)
| - Push to Harbor |  ← Harbor (CNCF Graduated)
+------------------+
         |
         v
+------------------+
| ArgoCD           |  ← Argo (CNCF Graduated)
| - GitOps sync    |
| - Drift detect   |
| - Self-heal      |
+------------------+
         |
         v
+------------------+
| Kyverno          |  ← CNCF Graduated
| - Verify sig     |
| - Enforce PSS    |
| - Check limits   |
+------------------+
         |
         v
+-----------------------------------------------------------+
| Kubernetes Cluster                                         |
|                                                           |
| Networking:    Cilium (CNCF Graduated)                    |
| Runtime:       containerd (CNCF Graduated)                |
| DNS:           CoreDNS (CNCF Graduated)                   |
| State:         etcd (CNCF Graduated)                      |
| Secrets:       External Secrets Operator (CNCF Incubating)|
| IaC:           Crossplane (CNCF Graduated)                |
|                                                           |
| Observability:                                            |
|   Metrics:     Prometheus (CNCF Graduated)                |
|   Traces:      OpenTelemetry (CNCF Graduated)             |
|   Logs:        Fluentd (CNCF Graduated)                   |
|                                                           |
| Security:                                                 |
|   Runtime:     Falco (CNCF Graduated)                     |
|   Policy:      Kyverno (CNCF Graduated)                   |
|   Network:     Cilium NetworkPolicy                       |
|   Identity:    SPIFFE/SPIRE (CNCF Incubating)             |
|                                                           |
| Developer Portal: Backstage (CNCF Graduated)              |
+-----------------------------------------------------------+
```

---

## 6. Thứ Tự Triển Khai (Timeline)

```
Tuần 1-2: Foundation
  Kubernetes + containerd + CoreDNS + etcd
  (có sẵn nếu dùng EKS/GKE/AKS)

Tuần 3-4: Networking + GitOps
  Cilium (thay default CNI)
  ArgoCD (quản lý mọi thứ từ Git)

Tháng 2: Policy + Monitoring
  Kyverno (admission policies)
  Prometheus + Grafana (metrics)
  Helm (deploy applications)

Tháng 3: Security + Secrets
  Falco (runtime detection)
  External Secrets Operator (sync secrets)
  Harbor (private registry, nếu không dùng managed)

Tháng 4-6: Observability + IaC
  OpenTelemetry (unified telemetry)
  Crossplane (manage cloud resources qua K8s API)
  Fluentd (centralized logging)

Tháng 6+: Developer Experience
  Backstage (khi >5 teams)
  Argo Rollouts (progressive delivery)
  SPIFFE/SPIRE (cross-platform identity)
```

---

## 7. CNCF Projects KHÔNG Dùng Và Tại Sao

| Project | Tại sao bỏ qua | Thay bằng |
|---------|----------------|-----------|
| Flannel | Không enforce NetworkPolicy | Cilium |
| Calico | Tốt nhưng Cilium có eBPF + L7 + Hubble | Cilium (trừ khi cần Windows) |
| Spinnaker | Quá phức tạp, ops overhead lớn | ArgoCD + Argo Rollouts |
| Vitess | Chỉ cần cho MySQL scale cực lớn | Managed DB (RDS, Cloud SQL) |
| Thanos/Cortex | Chỉ cần khi multi-cluster Prometheus | Single Prometheus đủ ban đầu |
| Rook | Storage operator phức tạp | EBS/EFS managed storage |
| Chaos Mesh | Nice-to-have, không urgent | Triển khai sau khi stable |
| KubeEdge | Edge computing, rất niche | Chỉ khi có IoT/edge use case |
| OpenKruise | Advanced workload management | Standard K8s đủ cho hầu hết |

---

## 8. Maturity Checklist: Đánh Giá Khi Nào Sẵn Sàng Cho Project Tiếp Theo

| Giai đoạn | Đạt được | Project tiếp theo |
|-----------|----------|-------------------|
| K8s chạy ổn, team biết kubectl | ✅ | Cilium + ArgoCD |
| GitOps hoạt động, deploy từ Git | ✅ | Kyverno + Prometheus |
| Policies enforce, metrics thu thập | ✅ | Falco + External Secrets |
| Security stack đầy đủ | ✅ | OpenTelemetry + Crossplane |
| Observability unified | ✅ | Backstage + Argo Rollouts |
| Self-service cho developer | ✅ | SPIFFE/SPIRE + advanced patterns |

**Quy tắc vàng:** Không thêm tool mới cho đến khi tool hiện tại chạy ổn định và team hiểu rõ.

---

## 9. Mapping Với Series

| Bài trong repo | CNCF Projects covered |
|---------------|----------------------|
| Part 1-2 (Image Security) | Harbor, Sigstore, Trivy |
| Part 3 (Runtime) | Falco, containerd, Cilium (Tetragon) |
| Part 4 (K8s Hardening) | Kubernetes, Kyverno, OPA, etcd |
| Part 5 (Network) | Cilium, Istio, Linkerd, SPIFFE/SPIRE, Envoy |
| Part 6 (Tools) | Falco, Kyverno, Prometheus |
| Part 8 (AI Era) | Falco, Kyverno, containerd (gVisor) |
| Part 9 (Architecture) | ArgoCD, Prometheus, Cilium, External Secrets |
| Part 10 (Multi-tenancy) | Backstage, ArgoCD, Kyverno |
| GitOps Guide | ArgoCD, Flux, Crossplane, Helm |
| examples/terraform | (Terraform = non-CNCF, nhưng bootstrap cho CNCF stack) |
| examples/kyverno | Kyverno policies |
| examples/falco | Falco rules + config |

---

## 10. Tóm Tắt: 12 Projects Quan Trọng Nhất

Nếu chỉ nhớ được 12 projects từ toàn bộ CNCF Landscape:

```
1.  Kubernetes     — orchestration (nền tảng)
2.  Cilium         — networking + security + observability (eBPF)
3.  ArgoCD         — GitOps delivery
4.  Prometheus     — monitoring + alerting
5.  Kyverno        — policy enforcement
6.  Falco          — runtime threat detection
7.  Helm           — package management
8.  OpenTelemetry  — unified observability
9.  Crossplane     — IaC control plane
10. Harbor         — container registry
11. Backstage      — developer portal
12. External Secrets — secrets management
```

Tất cả đều Graduated hoặc Incubating. Tất cả đều có trong series này.

---

## Nguồn

- CNCF Landscape: landscape.cncf.io
- CNCF Projects: cncf.io/projects
- "State of Cloud Native 2026" — CNCF CTO insights
- "State of Cloud Native Development Q1 2026" — CNCF + SlashData (20M developers)
- Aqua Security — "The 6 Categories of CNCF Landscape"
- CNCF — Graduation announcements (Crossplane 2025, Falco 2024, Kyverno 2024, Backstage 2024)
- "The Kubernetes Integration Tax" — CNCF Blog 2026
