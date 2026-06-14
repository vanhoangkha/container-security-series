# Container Security Series - Part 9: Platform Engineering Reference Architecture

> Series: Container Security Toan Dien (2026 Edition)
> Date: June 2026
> Audience: Platform Engineers, SREs, DevOps Leads

---

## 1. Architecture Overview

This is the end-to-end security architecture for a production Kubernetes platform. Every component is deployable via Terraform and managed through GitOps.

```
Developer Workstation
    |
    | git push
    v
+------------------+     +------------------+     +------------------+
|  GitHub / GitLab |---->|  CI Pipeline     |---->|  Container       |
|  (source + IaC)  |     |  (GitHub Actions)|     |  Registry (ECR)  |
|                  |     |                  |     |                  |
|  - App code      |     |  - Build image   |     |  - Immutable tags|
|  - Terraform     |     |  - Trivy scan    |     |  - Scan on push  |
|  - K8s manifests |     |  - SBOM (Syft)   |     |  - Signed images |
|  - Kyverno rules |     |  - Sign (Cosign) |     |                  |
|  - Falco rules   |     |  - Hadolint      |     |                  |
+------------------+     +------------------+     +------------------+
                                                          |
                                                          | pull
                                                          v
+------------------+     +------------------+     +------------------+
|  ArgoCD          |---->|  Admission       |---->|  EKS Cluster     |
|  (GitOps)        |     |  Control         |     |  (Production)    |
|                  |     |                  |     |                  |
|  - Sync from git |     |  - Kyverno       |     |  - Private API   |
|  - Drift detect  |     |  - Verify sig    |     |  - Bottlerocket  |
|  - Auto rollback |     |  - Enforce PSS   |     |  - KMS encryption|
|                  |     |  - Block :latest  |     |  - Pod Identity  |
+------------------+     +------------------+     +------------------+
                                                          |
                                                          | runtime
                                                          v
+------------------+     +------------------+     +------------------+
|  Falco           |     |  Cilium          |     |  External        |
|  (Runtime)       |     |  (Network)       |     |  Secrets (ESO)   |
|                  |     |                  |     |                  |
|  - eBPF driver   |     |  - Default deny  |     |  - AWS SM sync   |
|  - Custom rules  |     |  - L7 policies   |     |  - Auto rotation |
|  - Sidekick      |     |  - Hubble viz    |     |  - No etcd plain |
+------------------+     +------------------+     +------------------+
         |                       |                        |
         v                       v                        v
+------------------------------------------------------------------+
|                     OBSERVABILITY STACK                            |
|  Prometheus + Grafana + OpenSearch + PagerDuty + Slack            |
+------------------------------------------------------------------+
```

---

## 2. Infrastructure Layer (Terraform)

### 2.1. Module Structure

```
terraform/
  modules/
    eks-cluster/          # EKS with hardened defaults
    vpc-network/          # VPC with private subnets
    ecr-registry/         # ECR with scanning + immutability
    kms-keys/             # KMS for secrets + EBS + ECR
    guardduty/            # GuardDuty EKS runtime monitoring
    iam-roles/            # Pod Identity roles (least privilege)
  environments/
    production/
      main.tf
      variables.tf
      backend.tf
    staging/
      main.tf
```

### 2.2. Core EKS Module

```hcl
# modules/eks-cluster/main.tf

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  # Private-only API endpoint
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  # Envelope encryption for secrets
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = var.kms_key_arn
  }

  # All control plane logs
  cluster_enabled_log_types = [
    "api", "audit", "authenticator",
    "controllerManager", "scheduler"
  ]

  # Addons
  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }

    # EKS Pod Identity Agent
    eks-pod-identity-agent = { most_recent = true }
  }

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  eks_managed_node_groups = {
    platform = {
      instance_types = ["m6i.xlarge"]
      ami_type       = "BOTTLEROCKET_x86_64"
      min_size       = 3
      max_size       = 20
      desired_size   = 5

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 100
            volume_type = "gp3"
            encrypted   = true
            kms_key_id  = var.ebs_kms_key_arn
          }
        }
      }

      labels = {
        "node-role" = "platform"
      }
    }
  }

  # RBAC: only specified roles can access cluster
  enable_cluster_creator_admin_permissions = false
  access_entries = var.access_entries

  tags = var.tags
}
```

### 2.3. ECR with Security Controls

```hcl
# modules/ecr-registry/main.tf

resource "aws_ecr_repository" "repos" {
  for_each = toset(var.repository_names)

  name                 = each.value
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }
}

resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["v"]
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Remove untagged after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}
```

---

## 3. GitOps Layer (ArgoCD)

### 3.1. ArgoCD Security Configuration

```yaml
# argocd/values-production.yaml

server:
  # Disable admin account after initial setup
  config:
    admin.enabled: "false"
    # OIDC integration
    oidc.config: |
      name: Okta
      issuer: https://company.okta.com
      clientID: $oidc-client-id
      clientSecret: $oidc-client-secret
      requestedScopes: ["openid", "profile", "email", "groups"]

  # RBAC: map OIDC groups to ArgoCD roles
  rbacConfig:
    policy.csv: |
      p, role:platform-admin, applications, *, */*, allow
      p, role:platform-admin, clusters, *, *, allow
      p, role:developer, applications, get, */*, allow
      p, role:developer, applications, sync, */*, allow
      g, platform-team, role:platform-admin
      g, developers, role:developer
    policy.default: role:readonly

  # TLS
  ingress:
    enabled: true
    annotations:
      alb.ingress.kubernetes.io/scheme: internal
      alb.ingress.kubernetes.io/certificate-arn: ${acm_cert_arn}
```

### 3.2. Application Sets for Security Stack

```yaml
# argocd/applicationsets/security-stack.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: security-stack
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - name: falco
            namespace: falco
            repoPath: security/falco
          - name: kyverno
            namespace: kyverno
            repoPath: security/kyverno
          - name: external-secrets
            namespace: external-secrets
            repoPath: security/external-secrets
          - name: cilium
            namespace: kube-system
            repoPath: security/cilium
  template:
    metadata:
      name: "security-{{name}}"
    spec:
      project: platform
      source:
        repoURL: https://github.com/company/platform-config.git
        targetRevision: main
        path: "{{repoPath}}"
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{namespace}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true
```

### 3.3. Drift Detection

```yaml
# ArgoCD detects manual kubectl changes automatically
# Configure notification on drift:
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    notifications.argoproj.io/subscribe.on-sync-status-unknown.slack: security-alerts
```

---

## 4. CI Pipeline (GitHub Actions)

### 4.1. Secure Build Pipeline

```yaml
# .github/workflows/secure-build.yaml
name: Secure Build & Deploy

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read
  id-token: write   # For OIDC + Cosign keyless signing
  packages: write
  security-events: write

env:
  AWS_REGION: ap-southeast-1
  ECR_REGISTRY: ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.ap-southeast-1.amazonaws.com
  IMAGE_NAME: myapp

jobs:
  # Gate 1: Code quality + secrets scan
  lint-and-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Dockerfile lint
        uses: hadolint/hadolint-action@v3
        with:
          dockerfile: Dockerfile
          failure-threshold: warning

      - name: Secret scanning
        uses: trufflesecurity/trufflehog@main
        with:
          extra_args: --only-verified

  # Gate 2: Build + vulnerability scan + SBOM
  build-and-scan:
    needs: lint-and-scan
    runs-on: ubuntu-latest
    outputs:
      image-digest: ${{ steps.build.outputs.digest }}
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-ecr
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to ECR
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build and push
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ${{ env.ECR_REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            ${{ env.ECR_REGISTRY }}/${{ env.IMAGE_NAME }}:latest
          labels: |
            org.opencontainers.image.revision=${{ github.sha }}
            org.opencontainers.image.source=${{ github.server_url }}/${{ github.repository }}

      - name: Trivy vulnerability scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.ECR_REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          format: sarif
          output: trivy-results.sarif
          severity: CRITICAL,HIGH
          exit-code: "1"

      - name: Upload scan results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: trivy-results.sarif

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: ${{ env.ECR_REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          format: cyclonedx-json
          output-file: sbom.cdx.json
          upload-artifact: true

  # Gate 3: Sign image
  sign:
    needs: build-and-scan
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: sigstore/cosign-installer@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-ecr
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to ECR
        uses: aws-actions/amazon-ecr-login@v2

      - name: Sign image (keyless)
        run: |
          cosign sign --yes \
            ${{ env.ECR_REGISTRY }}/${{ env.IMAGE_NAME }}@${{ needs.build-and-scan.outputs.image-digest }}

      - name: Attach SBOM attestation
        run: |
          cosign attest --yes \
            --predicate sbom.cdx.json \
            --type cyclonedx \
            ${{ env.ECR_REGISTRY }}/${{ env.IMAGE_NAME }}@${{ needs.build-and-scan.outputs.image-digest }}
```

---

## 5. Cluster Security Stack Deployment Order

```
Phase 1: Cluster Foundation
  1. EKS cluster (Terraform)
  2. Cilium CNI (replaces aws-vpc-cni for policy enforcement)
  3. External Secrets Operator (secrets before anything else needs them)

Phase 2: Policy Enforcement
  4. Kyverno (admission control)
  5. Kyverno policies (PSS, image registry, resource limits)

Phase 3: Runtime Security
  6. Falco (eBPF driver, custom rules)
  7. Falcosidekick (alert routing)

Phase 4: Observability
  8. Prometheus + Grafana (metrics)
  9. OpenSearch (logs + Falco alerts)
  10. Hubble (network observability)

Phase 5: GitOps
  11. ArgoCD (manages everything above after initial bootstrap)
```

### Bootstrap Script

```bash
#!/bin/bash
# bootstrap-security-stack.sh
# Run ONCE after Terraform creates the cluster

set -euo pipefail

CLUSTER_NAME="${1:?Usage: $0 <cluster-name>}"
REGION="${2:-ap-southeast-1}"

echo "=== Updating kubeconfig ==="
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

echo "=== Phase 1: Cilium CNI ==="
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --namespace kube-system \
  --set eni.enabled=true \
  --set ipam.mode=eni \
  --set egressMasqueradeInterfaces=eth0 \
  --set routingMode=native \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --wait

echo "=== Phase 1: External Secrets Operator ==="
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace --wait

echo "=== Phase 2: Kyverno ==="
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno --namespace kyverno --create-namespace \
  --set admissionController.replicas=3 \
  --set backgroundController.replicas=2 \
  --wait

echo "=== Phase 2: Apply Kyverno Policies ==="
kubectl apply -f policies/kyverno/

echo "=== Phase 3: Falco ==="
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco --namespace falco --create-namespace \
  -f security/falco/values-production.yaml --wait

echo "=== Phase 5: ArgoCD ==="
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd --namespace argocd --create-namespace \
  -f argocd/values-production.yaml --wait

echo "=== Bootstrap complete. ArgoCD manages from here. ==="
echo "Access ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8443:443"
```

---

## 6. Security Validation Pipeline

After deployment, run automated validation:

```bash
#!/bin/bash
# validate-security-posture.sh

echo "=== CIS Benchmark ==="
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
sleep 30
kubectl logs -l app=kube-bench | tail -5

echo ""
echo "=== Kubescape NSA Framework ==="
kubescape scan framework nsa --format json --output nsa-results.json
kubescape scan framework nsa 2>&1 | grep "Controls:"

echo ""
echo "=== Kyverno Policy Reports ==="
kubectl get policyreport -A --no-headers | awk '{print $1, $3, $4, $5}'

echo ""
echo "=== Network Policy Coverage ==="
total_ns=$(kubectl get ns --no-headers | wc -l)
covered_ns=$(kubectl get ns -l 'kubernetes.io/metadata.name!=kube-system' -o name | while read ns; do
  name=${ns#namespace/}
  count=$(kubectl get networkpolicy -n "$name" --no-headers 2>/dev/null | wc -l)
  [ "$count" -gt 0 ] && echo "$name"
done | wc -l)
echo "NetworkPolicy coverage: $covered_ns / $total_ns namespaces"

echo ""
echo "=== Falco Status ==="
kubectl get pods -n falco -o wide
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=5

echo ""
echo "=== Images Without Signature ==="
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u | head -20
```

---

## 7. Monitoring Security Posture

### Prometheus Metrics to Expose

```yaml
# prometheus-rules/security-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: security-posture
spec:
  groups:
    - name: container-security
      rules:
        - alert: FalcoHighPriorityAlert
          expr: sum(rate(falco_events{priority=~"Critical|Error"}[5m])) > 0
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "Falco critical/error alert firing"

        - alert: KyvernoPolicyViolation
          expr: sum(kyverno_policy_results_total{rule_result="fail"}) > 10
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "More than 10 Kyverno policy violations"

        - alert: UnsignedImageRunning
          expr: sum(kyverno_policy_results_total{rule_name="verify-image-signature", rule_result="fail"}) > 0
          for: 0m
          labels:
            severity: critical
          annotations:
            summary: "Unsigned image detected in cluster"

        - alert: NetworkPolicyDeniedTraffic
          expr: sum(rate(hubble_drop_total{reason="POLICY_DENIED"}[5m])) by (source_pod) > 50
          for: 2m
          labels:
            severity: warning
          annotations:
            summary: "High rate of denied network traffic from {{ $labels.source_pod }}"
```

### Grafana Dashboard (Key Panels)

```
Row 1: Security Overview
  - Falco alerts (last 24h) by priority
  - Kyverno violations by policy
  - CIS compliance score (%)

Row 2: Image Security
  - Images scanned vs unscanned
  - Critical CVEs in running images
  - Unsigned images count

Row 3: Network
  - Denied connections (Hubble)
  - Namespaces without NetworkPolicy
  - Egress to internet (volume)

Row 4: Access Control
  - RBAC audit events
  - Failed authentication attempts
  - Service accounts with excessive permissions
```

---

## 8. Upgrade and Maintenance Strategy

### Component Upgrade Order

```
1. Cilium (CNI) — most disruptive, schedule maintenance window
2. Kyverno — brief webhook downtime, use failurePolicy: Ignore during upgrade
3. Falco — rolling DaemonSet update, no detection gap if done correctly
4. External Secrets — stateless, safe anytime
5. ArgoCD — last, since it manages the others
```

### Falco Rule Update Workflow

```
1. Developer proposes rule change in git (PR)
2. CI validates rule syntax: falco -V /path/to/rules.yaml
3. Platform team reviews (security implications)
4. Merge to main
5. ArgoCD syncs to cluster
6. Monitor for false positives (7 days)
7. Adjust if needed (new PR)
```

### Security Patch SLA

| Severity | Patch Window | Who |
|----------|-------------|-----|
| Critical CVE in running image | 24 hours | Developer team (rebuild image) |
| Critical CVE in platform component | 48 hours | Platform team (upgrade Helm chart) |
| High CVE | 7 days | Developer team |
| Medium CVE | 30 days | Sprint backlog |
| Kyverno policy violation | 72 hours | Developer team (fix manifest) |

---

## 9. Key Takeaways

1. Everything is code — Terraform for infra, Helm for platform, YAML for policies, all in git
2. ArgoCD is the single source of truth — manual kubectl should never touch production
3. Security stack deploys in order — CNI before policies, policies before workloads
4. Bootstrap once, then GitOps manages — the bootstrap script runs exactly once
5. Validate continuously — CIS benchmark, Kubescape, policy reports are automated
6. Upgrade order matters — CNI first, GitOps controller last
7. Patch SLAs must be defined — otherwise "we'll fix it later" becomes never
8. Monitor the security stack itself — Falco going down is a security event

---

## References

- Terraform AWS EKS Module documentation
- ArgoCD Security Best Practices
- Cilium Getting Started on EKS
- Falco Helm Chart Configuration
- Kyverno Policy Library
- AWS EKS Best Practices Guide

---

Previous: [Part 8: K8s Security in the AI Era](./part8-kubernetes-security-ai-era.md)
Next: [Part 10: Multi-tenancy & Developer Experience](./part10-multitenancy-developer-experience.md)
