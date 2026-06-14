# GitOps Toàn Diện: Từ Nguyên Lý Đến Production (2026)

> Tổng hợp từ 30+ nguồn: platformengineering.org, CNCF GitOps Survey 2025, OneUptime, TasrieIT, Harness, CalmOps, Spacelift, Akuity, và các production case studies.

---

## 1. GitOps Là Gì

Git là single source of truth. Một controller trong cluster liên tục so sánh trạng thái thực tế với trạng thái khai báo trong Git và tự động sửa mọi khác biệt.

Một câu: **Khai báo trạng thái mong muốn trong Git, agent tự reconcile cluster để khớp.**

```
       Git Repository (desired state)
              |
              | Watch (mỗi 3 phút hoặc webhook)
              v
    +-------------------+
    | GitOps Controller |  (ArgoCD / FluxCD)
    | (trong cluster)   |
    +-------------------+
              |
              | Compare desired vs actual
              v
    +-------------------+
    | Kubernetes Cluster|  (actual state)
    +-------------------+
              |
        Matched? ─── YES → Healthy
              |
              NO
              |
              v
        Reconcile (apply changes từ Git)
```

---

## 2. Tại Sao GitOps (2026)

| Chỉ số | Giá trị | Nguồn |
|---------|---------|-------|
| Tổ chức cloud-native đã adopt GitOps | 91% | CNCF GitOps Survey 2025 |
| Kubernetes deployments quản lý bằng GitOps | >90% | Scalr 2025 |
| Drift detection giảm MTTR | 73% | Datadog |
| GitOps trở thành de facto standard | 2026 | CalmOps, Fivenines |

---

## 3. Push vs Pull — Khác Biệt Cốt Lõi

| | Traditional CI/CD (Push) | GitOps (Pull) |
|-|--------------------------|---------------|
| Hướng | Pipeline đẩy changes tới cluster | Agent trong cluster kéo từ Git |
| Credentials | CI system giữ cluster credentials | Chỉ agent trong cluster có access |
| Drift | Không phát hiện cho đến pipeline chạy lại | Phát hiện liên tục, tự sửa |
| Partial failure | Cluster ở trạng thái unknown | Luôn reconcile về trạng thái known |
| Audit | Audit CI logs (phân tán) | Audit = Git history (tập trung) |
| Rollback | Chạy lại pipeline version cũ | git revert là đủ |
| Security | CI cần cluster-admin credentials | Agent chỉ pull từ Git, ít attack surface |

> "Khi Kubernetes được xử lý như traditional deployment target thay vì self-managing platform, bạn bỏ mất những khả năng mạnh nhất của nó: continuous reconciliation, drift correction, easy rollback."
> — Portainer

---

## 4. ArgoCD vs FluxCD

Cả hai đều CNCF Graduated. Câu hỏi không phải tool nào tốt hơn, mà tool nào phù hợp hơn.

| Tiêu chí | ArgoCD | FluxCD |
|----------|--------|--------|
| UI | Web app + topology graph | Không có UI (CLI-driven) |
| Triết lý | Platform (all-in-one) | Composable toolkit (controllers tách biệt) |
| Onboarding | Dễ hơn (UI trực quan) | Cần hiểu từng controller |
| Multi-cluster | Hub-spoke: 1 ArgoCD quản lý N clusters | Per-cluster: 1 Flux mỗi cluster |
| ApplicationSet | Generators: cluster, git, matrix, merge | Kustomization + GitRepository |
| Image automation | Cần Image Updater (add-on) | Native (Image Reflector + Automation) |
| Progressive Delivery | Argo Rollouts | Flagger |
| Helm + Kustomize | Native support | Deep integration |
| RBAC | Built-in (per project/app) | Dùng K8s native RBAC |
| Adoption (2026) | Cao hơn | Thấp hơn (ảnh hưởng Weaveworks shutdown) |

**Chọn ArgoCD khi:**
- Cần UI dashboard (debug lúc 2h sáng)
- Onboarding team chưa quen GitOps
- Multi-cluster quản lý tập trung
- RBAC fine-grained per application

**Chọn FluxCD khi:**
- Cần image automation native
- Team prefer CLI-first
- Deep Kustomize workflow
- Per-cluster autonomy (không centralized control)

> "Flux CD reconciles via CLI-driven controllers and almost no UI. ArgoCD gives you a full web app with topology graph that operators love at 2 AM."
> — ComputingForGeeks

---

## 5. Repository Structure

### Golden Rule: Tách app source và GitOps config

```
Repo 1: myapp/                   (application source code)
  ├── src/
  ├── Dockerfile
  ├── tests/
  └── .github/workflows/ci.yaml  (build + scan + sign)

Repo 2: gitops-config/           (Kubernetes manifests)
  ├── apps/
  │   ├── frontend/
  │   │   ├── base/
  │   │   │   ├── deployment.yaml
  │   │   │   ├── service.yaml
  │   │   │   └── kustomization.yaml
  │   │   └── overlays/
  │   │       ├── dev/
  │   │       │   ├── kustomization.yaml
  │   │       │   └── patch-replicas.yaml
  │   │       ├── staging/
  │   │       └── production/
  │   └── backend/
  │       ├── base/
  │       └── overlays/
  ├── platform/
  │   ├── falco/
  │   ├── kyverno/
  │   ├── cilium/
  │   └── external-secrets/
  └── clusters/
      ├── dev/
      │   └── apps.yaml          (ArgoCD ApplicationSet)
      ├── staging/
      └── production/
```

### Monorepo vs Multi-repo

| Pattern | Ưu | Nhược | Khi nào |
|---------|-----|-------|---------|
| Monorepo | Đơn giản, atomic changes | Chậm khi scale, RBAC khó | <50 apps, 1 team |
| Multi-repo (app + config tách) | Separation of concerns, RBAC rõ | Coordination phức tạp hơn | Production (chuẩn nhất) |
| Per-team repos | Autonomy cao, blast radius nhỏ | Khó enforce chính sách chung | Multi-tenant, nhiều team |

---

## 6. Environment Promotion

```
Developer commit → CI build + test + scan → Image pushed to registry
                                                    |
                                                    v
                                        Update gitops-config/apps/myapp/overlays/dev/
                                                    |
                                                    | ArgoCD auto-sync
                                                    v
                                              Deploy to DEV
                                                    |
                                                    | Tests pass → PR to staging overlay
                                                    v
                                              Deploy to STAGING
                                                    |
                                                    | QA approve → PR to production overlay
                                                    v
                                              Deploy to PRODUCTION
```

### Promotion Patterns

| Pattern | Cách thực hiện | Ưu/Nhược |
|---------|---------------|-----------|
| Directory-based (recommended) | Kustomize overlays per env, cùng branch | Rõ ràng, dễ diff, không diverge |
| Branch-based | dev/staging/prod branches | Đơn giản nhưng dễ diverge |
| Tag-based | Promote = update image tag trong overlay | Lightweight |
| Kargo (mới 2026) | Dedicated promotion controller | Tự động, audit trail tốt |

### Kargo — Giải Quyết Promotion Problem

> "ArgoCD solved the first mile of GitOps: reconcile clusters to match Git. But most teams still rely on CI scripts and manual steps for promotion. Kargo was built to solve exactly that."
> — Akuity

```yaml
# Kargo: tự động promote khi image mới verified ở dev
apiVersion: kargo.akuity.io/v1alpha1
kind: Stage
metadata:
  name: staging
spec:
  subscriptions:
    upstreamStages:
      - name: dev
  promotionMechanisms:
    gitRepoUpdates:
      - repoURL: https://github.com/company/gitops-config
        writeBranch: main
        kustomize:
          images:
            - image: registry.company.com/myapp
              path: apps/myapp/overlays/staging
```

---

## 7. Secrets Management Trong GitOps

> "The biggest challenge with GitOps is secrets. You want everything in Git for version control, but you cannot put passwords in plaintext."
> — OneUptime

> "29 triệu secrets mới bị expose trên public GitHub năm 2025 — tăng 34% YoY."
> — GitGuardian 2026

| Giải pháp | Secrets ở đâu | Reconciliation | GitOps-friendly | Phức tạp |
|-----------|--------------|----------------|-----------------|----------|
| **External Secrets Operator** | Cloud provider (AWS SM, Vault) | Auto-sync (refreshInterval) | Cao (ExternalSecret CRD trong git) | Thấp-Trung bình |
| **Sealed Secrets** | Encrypted trong Git | Controller decrypt trong cluster | Cao (SealedSecret trong git) | Thấp |
| **SOPS** | Encrypted values trong Git | Decrypt khi apply (Flux native) | Cao | Thấp |
| **Vault Agent** | Vault server | Inject runtime | Trung bình | Cao |

**Khuyến nghị:**
- Dùng **External Secrets Operator** nếu đã có AWS Secrets Manager/GCP SM
- Dùng **Sealed Secrets** cho team nhỏ, cần đơn giản
- Dùng **SOPS** nếu dùng Flux (native integration)
- Dùng **Vault** nếu cần dynamic secrets (database credentials on-demand)

---

## 8. Drift Detection và Self-Healing

### Vấn đề thực tế

> "Developer debug lúc 2h sáng, chạy kubectl edit deployment thay image tag. Fix xong. Nhưng cluster state bây giờ khác Git. ArgoCD phát hiện drift và revert."
> — OneUptime

### Cấu hình Self-Heal

```yaml
# ArgoCD Application với self-heal
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-falco
spec:
  syncPolicy:
    automated:
      prune: true       # Xóa resources không còn trong Git
      selfHeal: true    # Tự revert manual changes
    syncOptions:
      - CreateNamespace=true
```

### Best Practices

| Workload type | selfHeal | Lý do |
|--------------|----------|-------|
| Platform components (Falco, Kyverno, Cilium) | true | Không ai nên sửa tay, luôn khớp Git |
| Application workloads | false | Cho phép hotfix emergency, review drift sau |
| Infrastructure (Crossplane) | true | Cloud resources phải luôn khớp Git |

### Quy tắc vàng

```
NEVER: kubectl edit/apply trực tiếp vào production
ALWAYS: commit vào Git → ArgoCD sync
EMERGENCY: kubectl hotfix → TẠO NGAY commit trong Git đồng bộ lại
```

---

## 9. Progressive Delivery

### Argo Rollouts (dùng với ArgoCD)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 10
  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: {duration: 5m}
        - analysis:
            templates:
              - templateName: success-rate
        - setWeight: 50
        - pause: {duration: 10m}
        - analysis:
            templates:
              - templateName: success-rate
        - setWeight: 100
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  metrics:
    - name: success-rate
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(http_requests_total{app="myapp",status=~"2.."}[5m]))
            / sum(rate(http_requests_total{app="myapp"}[5m])) * 100
      successCondition: result[0] >= 99
      failureLimit: 2
      interval: 60s
```

### Flagger (dùng với FluxCD)

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: myapp
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  progressDeadlineSeconds: 600
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99
        interval: 1m
```

---

## 10. GitOps At Scale — Challenges Và Giải Pháp

| Vấn đề | Triệu chứng | Giải pháp |
|---------|-------------|-----------|
| Monorepo quá lớn | Clone chậm, sync timeout | Tách repos, shallow clones, ApplicationSets |
| Controller quá tải | Sync chậm, queue backup | ArgoCD sharding, dedicated nodes |
| Nhiều team share ArgoCD | Permission conflicts | AppProject isolation, RBAC per project |
| Config lẫn lộn owner | PR reviews chậm, ai approve gì? | Tách repo: app team vs platform team |
| Promotion thủ công | Chậm, lỗi người | Kargo, hoặc CI-triggered PR automation |
| Secrets leaking | Plaintext trong Git history | ESO/Sealed/SOPS (never plaintext) |
| Controller down = no deploys | Single point of failure | HA replicas, backup config |
| Thousands of YAML files | Khó navigate, merge conflicts | Helm/Kustomize, generate from templates |

> "The problem isn't the tools — it's that application config, platform config, and policy definitions have different owners, different change frequencies, and different review requirements."
> — Pelo.tech

---

## 11. GitOps + IaC: Terraform vs Crossplane

| | Terraform | Crossplane |
|-|-----------|-----------|
| Reconciliation | Không liên tục (phải chạy apply) | Liên tục (giống K8s controller) |
| GitOps native | Bán-declarative (cần CI trigger) | Fully declarative (K8s CRDs) |
| Drift | Phát hiện khi plan, KHÔNG tự sửa | Phát hiện VÀ tự sửa |
| State | File-based (S3) | Trong K8s etcd |
| Maturity | Rất mature (10+ years) | CNCF Graduated, growing fast |
| Ecosystem | Khổng lồ (providers cho mọi thứ) | Lớn và đang mở rộng |

**Pattern 2026:**
- **Terraform** để bootstrap cluster + core infra (VPC, EKS, IAM)
- **Crossplane** để ongoing management cloud resources trong GitOps flow
- **ArgoCD** quản lý cả Crossplane resources

```
Terraform (chạy 1 lần)         Crossplane (chạy liên tục)
   |                              |
   | Bootstrap                    | Day-2 management
   v                              v
EKS cluster + VPC            S3 buckets, RDS, Redis
                             (K8s CRDs, auto-reconcile)
                                  |
                                  | Quản lý bởi
                                  v
                              ArgoCD (GitOps)
```

---

## 12. ArgoCD Production Setup

### ApplicationSet cho Multi-Cluster

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-all-clusters
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            environment: production
  template:
    metadata:
      name: 'myapp-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/company/gitops-config
        targetRevision: main
        path: 'apps/myapp/overlays/production'
      destination:
        server: '{{server}}'
        namespace: myapp
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### RBAC per Team

```yaml
# ArgoCD AppProject: team chỉ quản lý apps của mình
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-payments
  namespace: argocd
spec:
  description: Payment team applications
  sourceRepos:
    - 'https://github.com/company/gitops-config'
  destinations:
    - namespace: 'team-payments'
      server: 'https://kubernetes.default.svc'
  clusterResourceWhitelist: []  # Không cho tạo cluster-scoped resources
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota   # Không cho sửa quota
    - group: networking.k8s.io
      kind: NetworkPolicy    # Không cho sửa network policy
```

### Sync Waves (thứ tự deploy)

```yaml
# Namespace trước
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
---
# ConfigMaps/Secrets tiếp theo
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
---
# Deployments sau cùng
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"
```

---

## 13. Anti-Patterns Cần Tránh

| Anti-pattern | Vấn đề | Nên làm |
|-------------|---------|---------|
| kubectl apply trực tiếp production | Drift, mất audit trail | Commit vào Git |
| Secrets plaintext trong Git | Leak = toàn bộ credentials bị lộ | ESO/Sealed/SOPS |
| 1 monorepo cho tất cả | Chậm, RBAC khó, merge conflicts | Tách theo team/concern |
| Self-heal cho mọi thứ | Emergency hotfix bị revert ngay | Self-heal chỉ cho platform |
| Không có sync waves | Resources tạo sai thứ tự, fail | Dùng sync-wave annotations |
| Branch-per-environment | Branches diverge theo thời gian | Directory-based overlays |
| ArgoCD single replica | Downtime = block mọi deploy | HA (3 replicas minimum) |
| Không monitoring ArgoCD | Controller chết mà không ai biết | Prometheus metrics + alert |
| Auto-prune mà không review | Resources bị xóa ngoài ý muốn | Prune = true chỉ khi chắc chắn |

---

## 14. GitOps Security

| Concern | Giải pháp |
|---------|-----------|
| Git repo bị compromise | Branch protection, signed commits, CODEOWNERS |
| ArgoCD credentials | OIDC/SSO, không dùng local admin |
| Repo access | Deploy keys (read-only), không personal tokens |
| Image tampering | Cosign signing + Kyverno verify tại admission |
| Unauthorized deploy | AppProject RBAC, chỉ cho phép từ specified repos |
| Audit trail | Git history = complete audit. Không cần thêm gì |
| Drift bởi attacker | Self-heal revert về Git state (defense mechanism) |

---

## 15. Workflow Hoàn Chỉnh (End-to-End)

```
1. Developer push code
   └── Trigger CI (GitHub Actions)

2. CI Pipeline:
   ├── Build image
   ├── Run tests
   ├── Trivy scan (fail on CRITICAL)
   ├── Generate SBOM (Syft)
   ├── Sign image (Cosign)
   └── Update gitops-config repo (PR với image tag mới)

3. GitOps Config PR:
   ├── Kyverno lint (policy check trên manifests)
   ├── Kustomize build --dry-run
   └── Auto-merge (nếu CI pass) hoặc review

4. ArgoCD detects change:
   ├── Compare desired (Git) vs actual (cluster)
   ├── Kyverno admission verify image signature
   └── Sync (apply changes)

5. Argo Rollouts (nếu enabled):
   ├── Canary 10% → 50% → 100%
   ├── Analysis (error rate, latency, Falco alerts)
   └── Auto-rollback nếu fail

6. Post-deploy:
   ├── Falco runtime monitoring
   ├── Drift detection (continuous)
   └── Prometheus/Grafana dashboards
```

---

## 16. Tóm Tắt

```
GitOps = Git là source of truth + Agent tự reconcile

Push vs Pull:
  Push (CI/CD): pipeline push tới cluster → credentials ở CI, drift không detect
  Pull (GitOps): agent pull từ Git → credentials chỉ trong cluster, tự heal

Tools (2026):
  ArgoCD: UI tốt, multi-cluster, RBAC, phổ biến nhất
  FluxCD: composable, image automation native, per-cluster

Repository:
  Tách app source và gitops config
  Directory-based environments (Kustomize overlays)
  Platform config tách riêng application config

Secrets: KHÔNG BAO GIỜ plaintext trong Git
  → External Secrets Operator hoặc Sealed Secrets hoặc SOPS

Scale:
  ApplicationSets thay vì copy-paste YAML
  Sharding ArgoCD cho >500 apps
  Kargo cho environment promotion automation

Self-heal:
  Platform components: enabled (Falco, Kyverno luôn khớp Git)
  Applications: disabled (review drift, cho phép emergency hotfix)
```

---

## Nguồn Tham Khảo

- CNCF GitOps Survey 2025 (91% adoption)
- platformengineering.org — "How to Scale GitOps in the Enterprise", "GitOps Architecture Patterns and Anti-Patterns"
- OneUptime — "GitOps with ArgoCD vs Traditional CI/CD", "Monorepo vs Multi-Repo", "Environment Promotion", "kubectl edit vs GitOps Conflicts"
- TasrieIT — "ArgoCD vs Flux: We Run Both in Production"
- Harness — "Why GitOps Breaks Down at Scale"
- Akuity — "GitOps Is Incomplete Without Promotion — How Kargo Fixes That"
- CalmOps — "GitOps 2026 Complete Guide", "ArgoCD vs Flux Comparison"
- Spacelift — "GitOps at Scale: Strategies for Enterprise Adoption"
- Medium (ankurgoel-tech) — "GitOps vs Argo CD vs Jenkins vs GitHub Actions"
- Portainer — "Why Kubernetes Demands a Different Deployment Model"
- GitGuardian — "State of Secrets Sprawl 2026" (29M secrets exposed)
- BitsLovers — "GitLab + ArgoCD: GitOps Deployments on EKS", "Crossplane vs Terraform"
- MarkAICode — "ArgoCD Production Architecture", "Kubernetes + Helm + ArgoCD Stack"
