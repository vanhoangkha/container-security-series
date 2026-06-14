# Container Security Series - Part 4: Kubernetes Security Hardening

> **Series:** Container Security Toàn Diện (2026 Edition)
> **Author:** Security Research Series
> **Date:** June 2026

---

## 1. Kubernetes Ships Insecure By Default

Một Kubernetes cluster mới cài đặt mặc định cho phép:
- Pods chạy as **root**
- Access **host network**
- Mount **arbitrary host paths**
- Communicate với **mọi pod** trong cluster (no network isolation)
- Service account token **auto-mounted** vào mọi pod → API access từ bất kỳ compromised container

**CIS Kubernetes Benchmark** documents **100+ security checks**. Fresh cluster thường fail **40-60%** trong số đó.

> Kubernetes clusters mới nhận attack attempt đầu tiên trong vòng **18 phút** sau khi deploy.

---

## 2. Kubernetes Security Layers

```
┌─────────────────────────────────────────────────────────┐
│                EXTERNAL ACCESS                            │
│  API Server │ Ingress │ LoadBalancer │ NodePort           │
├─────────────────────────────────────────────────────────┤
│                CONTROL PLANE                              │
│  API Server │ etcd │ Controller Manager │ Scheduler       │
├─────────────────────────────────────────────────────────┤
│                AUTHENTICATION & AUTHORIZATION             │
│  RBAC │ Service Accounts │ OIDC │ Admission Controllers  │
├─────────────────────────────────────────────────────────┤
│                WORKLOAD SECURITY                          │
│  Pod Security Standards │ Security Context │ Seccomp     │
├─────────────────────────────────────────────────────────┤
│                NETWORK                                    │
│  Network Policies │ Service Mesh │ DNS Policies          │
├─────────────────────────────────────────────────────────┤
│                DATA                                       │
│  Secrets Encryption │ etcd Encryption │ Volume Security  │
├─────────────────────────────────────────────────────────┤
│                NODE                                       │
│  OS Hardening │ Container Runtime │ Kubelet Security     │
└─────────────────────────────────────────────────────────┘
```

---

## 3. RBAC: Role-Based Access Control

### 3.1. Principle of Least Privilege

```yaml
# ✅ Good: Minimal role - read-only pods in one namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: production
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
  # NEVER use: "*", "create", "delete" unless needed
```

```yaml
# ❌ Bad: Overly permissive cluster-admin binding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: bad-binding
subjects:
- kind: ServiceAccount
  name: my-app
  namespace: default
roleRef:
  kind: ClusterRole
  name: cluster-admin  # ← NEVER do this for workloads
```

### 3.2. Service Account Security

```yaml
# Disable automatic token mounting
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: production
automountServiceAccountToken: false
---
# If token IS needed, use projected volume with expiration
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  serviceAccountName: my-app
  automountServiceAccountToken: false
  containers:
    - name: app
      image: myapp:latest
      volumeMounts:
        - name: token
          mountPath: /var/run/secrets/kubernetes.io/serviceaccount
          readOnly: true
  volumes:
    - name: token
      projected:
        sources:
          - serviceAccountToken:
              expirationSeconds: 3600  # 1 hour, auto-rotated
              audience: "my-app"
```

### 3.3. RBAC Audit Commands

```bash
# Check what default service account can do
kubectl auth can-i --list --as=system:serviceaccount:default:default

# Find all cluster-admin bindings
kubectl get clusterrolebindings -o json | \
  jq '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'

# Find roles with wildcard verbs
kubectl get roles,clusterroles -A -o json | \
  jq '.items[] | select(.rules[]?.verbs[]? == "*") | .metadata.name'

# Check specific permission
kubectl auth can-i create pods --as=system:serviceaccount:production:my-app

# Use kube-bench for CIS compliance
kube-bench run --targets=master,node,policies
```

### 3.4. Real-World RBAC Audit Findings (40+ Clusters)

> "After auditing more than 40 Kubernetes clusters for healthcare, fintech, SaaS, and enterprise clients, we can say with confidence that RBAC is the single most misconfigured aspect of Kubernetes security."
> — TasrieIT (2026)

**Key data points:**
- **90%** organizations experienced ≥1 K8s security incident (Red Hat State of K8s Security)
- **50%+** cite misconfigurations as leading cause
- Machine identities outnumber humans **40,000 to 1** — every one carries RBAC permissions (Sysdig 2025)
- **93%** respondents experienced ≥1 security incident in past year (CNCF 2023 Survey)
- **78%** lacked confidence in their security posture

**Top RBAC Mistakes Found in Audits:**

| Rank | Mistake | Prevalence | Impact |
|------|---------|-----------|--------|
| 1 | `*` wildcard verbs on roles | 73% of clusters | Full resource access |
| 2 | cluster-admin bound to CI service accounts | 45% | Complete cluster control |
| 3 | Default service account auto-mounted tokens | 89% | Every pod gets API access |
| 4 | ClusterRoleBinding for namespace-scoped SA | 38% | Access to ALL namespaces |
| 5 | No token expiration (static tokens) | 67% | Permanent access if leaked |
| 6 | Stale/unused RBAC bindings never cleaned | 82% | Expanded attack surface |

**The Kill Chain (anonymous → cluster-admin):**

```
1. Anonymous auth enabled (default in some setups)
2. List namespaces, pods, services (discovery)
3. Find ServiceAccount with create pods permission
4. Create pod with hostPath mount to /etc/kubernetes/
5. Read admin.conf or SA tokens from host
6. Use extracted token → cluster-admin
Total time: < 5 minutes
```

### 3.5. Critical Kubernetes CVEs (2025-2026)

| CVE | Severity | Component | Impact |
|-----|----------|-----------|--------|
| **CVE-2025-1767** | High | ingress-nginx | Inject arbitrary NGINX config via Ingress objects |
| **CVE-2026-39987** | Critical | marimo notebook | Exploited by AI agent for container escape |
| **CVE-2024-21626** | High | runc (Leaky Vessels) | Container escape via working directory |
| **CVE-2024-3177** | Medium | K8s API | Bypass mountable secrets policy via ephemeral containers |
| **CVE-2025-0426** | High | Kubernetes | Node-level access via kubelet API |

**GitGuardian Q1 2026:** ~2,000 Kubernetes credentials leaked on GitHub, **28% valid** at time of leak. A single leaked K8s credential opens: registry credentials, private Docker images, and private GitHub repos.

---

## 4. Pod Security Standards (PSS)

### 4.1. Three Enforcement Levels

| Level | Description | Use Case |
|-------|-------------|----------|
| **Privileged** | Unrestricted | System components (kube-system) |
| **Baseline** | Prevents known privilege escalations | General workloads |
| **Restricted** | Security best practices enforced | Production, sensitive workloads |

### 4.2. Apply PSS to Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    # Enforce: reject pods that violate
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    # Warn: log warning but allow
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
    # Audit: record in audit log
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
```

### 4.3. Pod Security Context (Restricted Compliant)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: production
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    runAsGroup: 10001
    fsGroup: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: myapp:v1.0@sha256:abc123...
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
      resources:
        requests:
          memory: "128Mi"
          cpu: "100m"
        limits:
          memory: "256Mi"
          cpu: "500m"
      volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/cache
  volumes:
    - name: tmp
      emptyDir:
        sizeLimit: "100Mi"
    - name: cache
      emptyDir:
        sizeLimit: "50Mi"
```

### 4.4. What Restricted Policy Blocks

| Setting | Required Value | Why |
|---------|---------------|-----|
| `runAsNonRoot` | `true` | Prevent root exploitation |
| `allowPrivilegeEscalation` | `false` | Block setuid/setgid abuse |
| `capabilities.drop` | `["ALL"]` | Remove all Linux capabilities |
| `seccompProfile` | `RuntimeDefault` or `Localhost` | Restrict syscalls |
| `hostNetwork` | `false` | No host network access |
| `hostPID` | `false` | No host PID namespace |
| `hostIPC` | `false` | No host IPC namespace |
| `privileged` | `false` | No privileged mode |

---

## 5. Network Policies

### 5.1. Default Deny All

```yaml
# CRITICAL: Apply this to every production namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}  # Apply to ALL pods
  policyTypes:
    - Ingress
    - Egress
  # No rules = deny all traffic
```

### 5.2. Allow Specific Traffic

```yaml
# Allow frontend → backend communication only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
---
# Allow backend → database only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-db
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
    # Allow DNS
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
```

### 5.3. Block Metadata Service Access

```yaml
# Block access to cloud metadata endpoint (169.254.169.254)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-metadata-access
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 169.254.169.254/32  # Block metadata service
```

### 5.4. Important: CNI Plugin Required

| CNI Plugin | NetworkPolicy Support | Additional Features |
|-----------|----------------------|-------------------|
| **Calico** | ✅ Full | Global policies, DNS policies |
| **Cilium** | ✅ Full | L7 policies, eBPF, service mesh |
| **Weave Net** | ✅ Full | Encryption |
| **Flannel** | ❌ None | Need to add Calico on top |
| **Default (kubenet)** | ❌ None | Not suitable for production |

---

## 6. Secrets Management

### 6.1. Problem: K8s Secrets Are NOT Encrypted

```bash
# Anyone with kubectl get secret access can read plaintext
kubectl get secret my-secret -o jsonpath='{.data.password}' | base64 -d
# Output: actual-password-value

# etcd stores secrets in base64 (NOT encryption)
```

### 6.2. Solution 1: Encrypt etcd at Rest

```yaml
# /etc/kubernetes/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64-encoded-32-byte-key>
      - identity: {}  # Fallback for reading old unencrypted secrets
```

```bash
# Apply to API server
# Add to kube-apiserver: --encryption-provider-config=/etc/kubernetes/encryption-config.yaml

# Verify encryption is working
kubectl create secret generic test-secret --from-literal=key=value
# Check etcd directly - should see encrypted data
```

### 6.3. Solution 2: External Secrets Manager

```yaml
# External Secrets Operator + AWS Secrets Manager
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: db-credentials
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: production/database
        property: username
    - secretKey: password
      remoteRef:
        key: production/database
        property: password
```

### 6.4. Solution 3: Sealed Secrets (GitOps)

```bash
# Encrypt secret for git storage
kubeseal --format=yaml < secret.yaml > sealed-secret.yaml

# Only the cluster can decrypt
# Safe to commit to git repository
```

### 6.5. Secrets Management Comparison (2026)

> "The Kubernetes Secrets API stores data as base64-encoded values in etcd. That is not encryption — it is obfuscation."
> — sanj.dev

| Feature | External Secrets Operator (ESO) | HashiCorp Vault | Sealed Secrets | SOPS |
|---------|-------------------------------|-----------------|----------------|------|
| **Architecture** | K8s operator syncs from external store | Separate server + agent/injector | Controller decrypts in cluster | CLI encrypts/decrypts files |
| **Secret storage** | AWS SM, GCP SM, Azure KV, Vault | Vault server (self-managed) | Encrypted in git (cluster decrypts) | Encrypted in git (keys in KMS) |
| **Rotation** | ✅ Auto (refreshInterval) | ✅ Dynamic secrets (TTL) | ❌ Manual re-seal | ❌ Manual re-encrypt |
| **GitOps friendly** | ✅ (ExternalSecret CRD in git) | Partial (agent config in git) | ✅ (SealedSecret in git) | ✅ (encrypted files in git) |
| **Complexity** | Low-Medium | High (Vault ops overhead) | Low | Low |
| **Multi-cluster** | ✅ (ClusterSecretStore) | ✅ (centralized Vault) | ❌ (per-cluster keys) | ✅ (shared KMS keys) |
| **Audit trail** | Cloud provider logs | Vault audit logs (detailed) | Limited | Cloud KMS logs |
| **Dynamic secrets** | ❌ (syncs static secrets) | ✅ (DB creds on-demand, TTL) | ❌ | ❌ |
| **Cost** | Free + cloud provider pricing | Free (OSS) or $$$ (Enterprise) | Free | Free + KMS pricing |
| **Best for** | Cloud-native teams, multi-cloud | Enterprises needing dynamic secrets | Simple GitOps, small teams | Developers, simple encryption |

**Decision guide:**
- **Start with ESO** if you already use AWS/GCP/Azure secrets manager
- **Use Vault** if you need dynamic database credentials or complex access policies
- **Use Sealed Secrets** for simple GitOps with small number of secrets
- **Use SOPS** for encrypting config files managed by developers

---

## 7. API Server Hardening

### 7.1. Critical API Server Flags

```bash
# Disable anonymous authentication
--anonymous-auth=false

# Authorization mode (RBAC only, remove AlwaysAllow)
--authorization-mode=Node,RBAC

# Enable audit logging
--audit-log-path=/var/log/kubernetes/audit.log
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
--audit-log-maxage=30
--audit-log-maxbackup=10
--audit-log-maxsize=100

# Disable insecure port (default in 1.20+)
--insecure-port=0

# Enable admission controllers
--enable-admission-plugins=NodeRestriction,PodSecurity,\
  MutatingAdmissionWebhook,ValidatingAdmissionWebhook

# TLS configuration
--tls-min-version=VersionTLS12
--tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,...
```

### 7.2. Audit Policy

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Log all requests to secrets
  - level: Metadata
    resources:
      - group: ""
        resources: ["secrets"]
  
  # Log pod exec/attach (potential attack vector)
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["pods/exec", "pods/attach"]
  
  # Log RBAC changes
  - level: RequestResponse
    resources:
      - group: "rbac.authorization.k8s.io"
        resources: ["clusterroles", "clusterrolebindings", "roles", "rolebindings"]
  
  # Log all changes in kube-system
  - level: Request
    namespaces: ["kube-system"]
    verbs: ["create", "update", "patch", "delete"]
  
  # Default: log metadata for everything
  - level: Metadata
```

---

## 8. Admission Controllers

### 8.1. Kyverno Policies

```yaml
# Require resource limits on all containers
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-limits
      match:
        any:
          - resources:
              kinds: ["Pod"]
      validate:
        message: "CPU and memory limits are required"
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
---
# Disallow privileged containers
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged
spec:
  validationFailureAction: Enforce
  rules:
    - name: no-privileged
      match:
        any:
          - resources:
              kinds: ["Pod"]
      validate:
        message: "Privileged containers are not allowed"
        pattern:
          spec:
            containers:
              - securityContext:
                  privileged: "false"
---
# Require image from trusted registry
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-image-registries
spec:
  validationFailureAction: Enforce
  rules:
    - name: allowed-registries
      match:
        any:
          - resources:
              kinds: ["Pod"]
      validate:
        message: "Images must come from approved registries"
        pattern:
          spec:
            containers:
              - image: "myregistry.com/* | gcr.io/distroless/*"
```

### 8.2. OPA Gatekeeper Constraints

```yaml
# Constraint template: disallow host namespaces
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sdisallowednamespaces
spec:
  crd:
    spec:
      names:
        kind: K8sDisallowedNamespaces
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sdisallowednamespaces
        violation[{"msg": msg}] {
          input.review.object.spec.hostNetwork == true
          msg := "hostNetwork is not allowed"
        }
        violation[{"msg": msg}] {
          input.review.object.spec.hostPID == true
          msg := "hostPID is not allowed"
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDisallowedNamespaces
metadata:
  name: no-host-namespaces
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces: ["kube-system"]
```

---

## 9. OWASP Kubernetes Top 10 (2025)

| # | Risk | Mitigation |
|---|------|-----------|
| K01 | Insecure Workload Configuration | Pod Security Standards (Restricted) |
| K02 | Supply Chain Vulnerabilities | Image scanning + signing + admission control |
| K03 | Overly Permissive RBAC | Least privilege roles, audit regularly |
| K04 | Lack of Centralized Policy Enforcement | Kyverno/OPA Gatekeeper |
| K05 | Inadequate Logging and Monitoring | Audit logs + Falco + SIEM |
| K06 | Broken Authentication | Disable anonymous auth, use OIDC |
| K07 | Missing Network Segmentation | Default-deny NetworkPolicies |
| K08 | Secrets Management Failures | External secrets manager + etcd encryption |
| K09 | Misconfigured Cluster Components | CIS benchmark + kube-bench |
| K10 | Vulnerable & Outdated Components | Regular upgrades, image scanning |

---

## 10. CIS Benchmark Automation

### 10.1. Run kube-bench

```bash
# Run CIS benchmark on master node
kube-bench run --targets=master

# Run on worker nodes
kube-bench run --targets=node

# Run policies check
kube-bench run --targets=policies

# JSON output for automation
kube-bench run --json > cis-results.json

# Run as Kubernetes Job
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs -l app=kube-bench
```

### 10.2. Kubescape (NSA/CISA Hardening)

```bash
# Scan cluster against NSA-CISA framework
kubescape scan framework nsa

# Scan against CIS benchmark
kubescape scan framework cis-v1.23-t1.0.1

# Scan specific namespace
kubescape scan framework nsa --include-namespaces production

# Scan YAML files before deploy
kubescape scan *.yaml
```

---

## 11. EKS/GKE/AKS Specific Hardening

### 11.1. AWS EKS

```bash
# Restrict public API access
aws eks update-cluster-config \
  --name my-cluster \
  --resources-vpc-config endpointPublicAccess=false,endpointPrivateAccess=true

# Enable envelope encryption for secrets
aws eks create-cluster \
  --encryption-config '[{"resources":["secrets"],"provider":{"keyArn":"arn:aws:kms:..."}}]'

# Enable control plane logging
aws eks update-cluster-config \
  --name my-cluster \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'
```

### 11.2. EKS Hardened Cluster with Terraform

```hcl
# terraform/eks-hardened.tf — Production-grade EKS cluster

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "production-cluster"
  cluster_version = "1.30"

  # SECURITY: Private endpoint only
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  # SECURITY: Enable envelope encryption for secrets
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = aws_kms_key.eks_secrets.arn
  }

  # SECURITY: Enable all control plane logging
  cluster_enabled_log_types = [
    "api", "audit", "authenticator",
    "controllerManager", "scheduler"
  ]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # SECURITY: Managed node groups with hardened config
  eks_managed_node_groups = {
    production = {
      instance_types = ["m6i.large"]
      min_size       = 2
      max_size       = 10
      desired_size   = 3

      # SECURITY: Use Bottlerocket OS (minimal, immutable)
      ami_type = "BOTTLEROCKET_x86_64"

      # SECURITY: Encrypt node volumes
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 50
            volume_type = "gp3"
            encrypted   = true
            kms_key_id  = aws_kms_key.ebs.arn
          }
        }
      }
    }
  }

  # SECURITY: Restrict access to cluster
  access_entries = {
    admin = {
      kubernetes_groups = []
      principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/EKSAdmin"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  tags = {
    Environment = "production"
    Security    = "hardened"
  }
}

# KMS key for secret encryption
resource "aws_kms_key" "eks_secrets" {
  description             = "EKS secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# SECURITY: GuardDuty EKS Runtime Monitoring
resource "aws_guardduty_detector_feature" "eks_runtime" {
  detector_id = aws_guardduty_detector.main.id
  name        = "EKS_RUNTIME_MONITORING"
  status      = "ENABLED"

  additional_configuration {
    name   = "EKS_ADDON_MANAGEMENT"
    status = "ENABLED"
  }
}

# SECURITY: ECR with scanning enabled
resource "aws_ecr_repository" "app" {
  name                 = "production/myapp"
  image_tag_mutability = "IMMUTABLE"  # Prevent tag overwrite attacks

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }
}
```

### 11.3. Pod Identity (Replace IRSA)

```yaml
# EKS Pod Identity: fine-grained IAM for pods
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: production
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/my-app-role
---
# Pod automatically gets temporary credentials
# No need for long-lived secrets
```

### 11.4. GKE Hardening

```bash
# Enable Workload Identity
gcloud container clusters update my-cluster \
  --workload-pool=my-project.svc.id.goog

# Enable Binary Authorization
gcloud container clusters update my-cluster \
  --binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE

# Enable GKE Security Posture
gcloud container clusters update my-cluster \
  --security-posture=standard \
  --workload-vulnerability-scanning=standard
```

### 11.5. Managed K8s Security Comparison (EKS vs GKE vs AKS)

| Security Feature | EKS | GKE | AKS |
|-----------------|-----|-----|-----|
| **Control plane managed** | ✅ | ✅ | ✅ |
| **Auto security patches** | Node groups only | Autopilot: full | AKS Automatic |
| **Secrets encryption** | KMS envelope (opt-in) | Application-layer (opt-in) | Azure Key Vault (opt-in) |
| **Workload identity** | Pod Identity / IRSA | Workload Identity | Workload Identity |
| **Binary authorization** | ❌ (use Kyverno) | ✅ Native | ❌ (use Ratify) |
| **Built-in image scanning** | ECR + Inspector | Artifact Analysis | Defender for Containers |
| **Network policy** | Calico/Cilium (add-on) | Dataplane V2 (Cilium) | Calico / Cilium (Azure CNI) |
| **Runtime threat detection** | GuardDuty EKS Runtime | Security Command Center | Defender for Containers |
| **Audit logging** | CloudWatch (opt-in) | Cloud Audit Logs (default) | Azure Monitor (opt-in) |
| **Private cluster** | ✅ Private endpoint | ✅ Private cluster | ✅ Private cluster |
| **Node OS** | AL2, Bottlerocket, Ubuntu | Container-Optimized OS, Ubuntu | Ubuntu, Azure Linux |
| **FIPS 140-2** | ✅ (Bottlerocket FIPS) | ✅ (GKE Sandbox) | ✅ (Azure Linux FIPS) |

> **Key insight:** Managed K8s = provider manages control plane. You still own: workload security, RBAC, network policies, secrets, image verification, and runtime monitoring.

### 11.6. Compliance Framework Mapping

| K8s Control | PCI-DSS 4.0 | SOC 2 (CC) | HIPAA | NIST 800-53 | CIS K8s |
|------------|-------------|------------|-------|-------------|---------|
| RBAC least privilege | 7.2, 7.3 | CC6.1, CC6.3 | §164.312(a) | AC-3, AC-6 | 5.1.1 |
| Pod Security Standards | 7.1 | CC6.1 | §164.312(a) | AC-6, SC-7 | 5.2.x |
| Network Policies | 1.2, 1.3 | CC6.6 | §164.312(e) | SC-7 | 4.1 |
| Secrets encryption at rest | 3.4, 3.5 | CC6.1 | §164.312(a)(2) | SC-28 | 1.2.6 |
| mTLS in transit | 4.1, 4.2 | CC6.7 | §164.312(e) | SC-8, SC-13 | 4.2 |
| Audit logging | 10.2, 10.3 | CC7.2 | §164.312(b) | AU-2, AU-3 | 3.2.1 |
| Image scanning | 6.3, 6.5 | CC7.1 | §164.308(a)(8) | RA-5, SI-2 | 5.1 |
| Runtime monitoring | 10.6, 11.4 | CC7.2, CC7.3 | §164.312(b) | SI-4, IR-4 | N/A |
| Incident response | 12.10 | CC7.4, CC7.5 | §164.308(a)(6) | IR-1 through IR-8 | N/A |
| Vulnerability mgmt | 6.1, 6.2 | CC7.1 | §164.308(a)(1) | RA-5 | 5.1 |

> **Frameworks overlap 60-80%** — building the second framework mapping is far cheaper than the first if you design controls deliberately. (Source: CSOH.org)

---

## 12. Kubernetes Security Hardening Checklist

### Control Plane
- [ ] API server: `--anonymous-auth=false`
- [ ] API server: `--authorization-mode=Node,RBAC`
- [ ] API server: audit logging enabled
- [ ] API server: TLS 1.2+ only
- [ ] etcd: encrypted at rest
- [ ] etcd: mutual TLS authentication
- [ ] Control plane: private endpoint (no public access)

### RBAC & Authentication
- [ ] No wildcard verbs (`*`) in roles
- [ ] No unnecessary cluster-admin bindings
- [ ] `automountServiceAccountToken: false` by default
- [ ] Service account tokens have expiration (projected volumes)
- [ ] OIDC integration for user authentication
- [ ] Regular RBAC audit (quarterly minimum)

### Workload Security
- [ ] Pod Security Standards: Restricted on production namespaces
- [ ] All containers: `runAsNonRoot: true`
- [ ] All containers: `readOnlyRootFilesystem: true`
- [ ] All containers: `allowPrivilegeEscalation: false`
- [ ] All containers: `capabilities.drop: ["ALL"]`
- [ ] All containers: `seccompProfile: RuntimeDefault`
- [ ] Resource limits set on all containers
- [ ] Images pinned by digest, not tag

### Network
- [ ] Default-deny NetworkPolicy on all production namespaces
- [ ] Explicit allow rules per service communication
- [ ] Metadata service (169.254.169.254) blocked from application pods
- [ ] CNI plugin with NetworkPolicy enforcement (Calico/Cilium)
- [ ] Ingress controller with WAF/rate limiting

### Secrets
- [ ] etcd encryption at rest enabled
- [ ] External secrets manager (Vault/AWS SM/GCP SM)
- [ ] No secrets in environment variables (use volume mounts)
- [ ] Sealed Secrets for GitOps workflows
- [ ] Regular secret rotation

### Supply Chain
- [ ] Image scanning in CI pipeline
- [ ] Image signing with Cosign/Sigstore
- [ ] Admission controller verifies image signatures
- [ ] Only approved registries allowed
- [ ] SBOM generated and stored

### Monitoring & Detection
- [ ] Falco deployed for runtime detection
- [ ] API server audit logs shipped to SIEM
- [ ] CIS benchmark run quarterly (kube-bench)
- [ ] Alert on suspicious pod creation/modification
- [ ] Alert on RBAC privilege escalation

---

## 13. Key Takeaways

1. **Kubernetes ships insecure by default** — hardening is mandatory, not optional
2. **RBAC least privilege** — no wildcards, no cluster-admin for workloads
3. **Pod Security Standards Restricted** — enforce on all production namespaces
4. **Default-deny NetworkPolicies** — verify CNI plugin enforcement
5. **Secrets encryption** — etcd at rest + external secrets manager
6. **Disable anonymous auth** + enable audit logging on API server
7. **Admission controllers** (Kyverno/OPA) — enforcement at deploy time
8. **Service account tokens** — disable auto-mount, use projected volumes with expiration
9. **CIS benchmark quarterly** — automate with kube-bench
10. **Layer all controls** — RBAC + PSS + NetworkPolicy + Admission + Runtime = defense in depth

---

## References

- AquilaX. "Kubernetes Security Hardening: A Practical Guide" (March 2026)
- AppSecSanta. "Kubernetes Security Best Practices"
- FreeCodeCamp. "RBAC, Pod Hardening, and Runtime Protection"
- Inventivehq. "Kubernetes Security & Hardening Workflow"
- Atmosly. "Kubernetes Security Checklist: 50 Best Practices 2025"
- OWASP. "Kubernetes Top 10 (2025)"
- CIS. "Kubernetes Benchmark"

---

*← [Part 3: Runtime Security & Monitoring](./part3-runtime-security-monitoring.md)*
*→ Tiếp theo: [Part 5: Network Security & Zero Trust](./part5-network-security-zero-trust.md)*
