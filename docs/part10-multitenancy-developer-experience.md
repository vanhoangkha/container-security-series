# Container Security Series - Part 10: Multi-tenancy, Developer Experience & Day-2 Operations

> Series: Container Security Toan Dien (2026 Edition)
> Date: June 2026
> Audience: Platform Engineers, SREs, DevOps Leads

---

## 1. Multi-tenancy Security Patterns

### 1.1. Hard vs Soft Tenancy

| Aspect | Soft Tenancy | Hard Tenancy |
|--------|-------------|--------------|
| Isolation unit | Namespace | Cluster (or vCluster) |
| Shared components | Control plane, nodes, CNI | Nothing shared |
| Risk | Noisy neighbor, lateral movement | Higher cost, more ops |
| Cost | Lower (shared infra) | Higher (dedicated clusters) |
| Compliance | OK for same-org teams | Required for multi-customer |
| Use case | Internal teams | SaaS platform, regulated industries |

### 1.2. Namespace-Based Multi-tenancy (Soft)

```yaml
# tenant-onboarding.yaml — everything a new team gets
---
apiVersion: v1
kind: Namespace
metadata:
  name: team-payments
  labels:
    tenant: payments
    environment: production
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/warn: restricted
---
# Resource Quotas — prevent resource exhaustion
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-quota
  namespace: team-payments
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
    pods: "50"
    services: "10"
    secrets: "20"
    configmaps: "30"
    persistentvolumeclaims: "10"
---
# LimitRange — enforce per-pod defaults
apiVersion: v1
kind: LimitRange
metadata:
  name: tenant-limits
  namespace: team-payments
spec:
  limits:
    - type: Container
      default:
        cpu: "500m"
        memory: "256Mi"
      defaultRequest:
        cpu: "100m"
        memory: "128Mi"
      max:
        cpu: "2"
        memory: "4Gi"
    - type: Pod
      max:
        cpu: "4"
        memory: "8Gi"
---
# NetworkPolicy — isolate tenant from other tenants
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-isolation
  namespace: team-payments
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow traffic only from same namespace
    - from:
        - podSelector: {}
    # Allow from ingress controller
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-system
  egress:
    # Same namespace
    - to:
        - podSelector: {}
    # DNS
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
        - podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - port: 53
          protocol: UDP
    # Shared services (database, cache)
    - to:
        - namespaceSelector:
            matchLabels:
              role: shared-services
      ports:
        - port: 5432
        - port: 6379
---
# RBAC — team can only access their namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tenant-admin
  namespace: team-payments
subjects:
  - kind: Group
    name: team-payments   # OIDC group
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit             # Built-in: create/edit resources, no RBAC changes
  apiGroup: rbac.authorization.k8s.io
---
# ServiceAccount for workloads
apiVersion: v1
kind: ServiceAccount
metadata:
  name: team-payments-app
  namespace: team-payments
automountServiceAccountToken: false
```

### 1.3. Automated Tenant Onboarding

```bash
#!/bin/bash
# onboard-tenant.sh <team-name> <cpu-quota> <memory-quota> <oidc-group>

TEAM="${1:?Usage: $0 <team-name> <cpu> <memory> <oidc-group>}"
CPU="${2:-10}"
MEMORY="${3:-20Gi}"
GROUP="${4:-$TEAM}"

echo "Onboarding tenant: $TEAM"

# Generate from template
cat templates/tenant-namespace.yaml | \
  sed "s/TENANT_NAME/$TEAM/g" | \
  sed "s/CPU_QUOTA/$CPU/g" | \
  sed "s/MEMORY_QUOTA/$MEMORY/g" | \
  sed "s/OIDC_GROUP/$GROUP/g" | \
  kubectl apply -f -

# Create ExternalSecret for the team
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: team-secrets
  namespace: team-$TEAM
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: app-secrets
  dataFrom:
    - extract:
        key: "teams/$TEAM/production"
EOF

echo "Tenant $TEAM onboarded: namespace, quotas, network policies, RBAC, secrets"
```

---

## 2. Developer Experience (DX)

### 2.1. The Problem

Security that creates too much friction gets bypassed. Platform engineers must provide:
- Secure defaults that require zero effort from developers
- Self-service workflows that do not require tickets
- Fast feedback loops (seconds, not days)

### 2.2. Golden Base Images

Maintain a set of pre-hardened base images that developers use instead of pulling from Docker Hub:

```dockerfile
# company-images/node/Dockerfile
FROM node:20.11.1-alpine3.19@sha256:abc123...

# Security hardening already applied
RUN apk add --no-cache tini && \
    addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup && \
    rm -rf /var/cache/apk/*

# Tini as init process (reaps zombies, handles signals)
ENTRYPOINT ["/sbin/tini", "--"]

USER appuser:appgroup
WORKDIR /app
```

```
# Available golden images (rebuilt weekly with latest patches):
registry.company.com/base/node:20-alpine      # Node.js
registry.company.com/base/python:3.12-alpine   # Python
registry.company.com/base/java:21-distroless   # Java (GraalVM native)
registry.company.com/base/go:static            # Go (distroless static)
registry.company.com/base/nginx:hardened       # Nginx (custom config)
```

Kyverno policy forces use of golden images:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-golden-base-images
spec:
  validationFailureAction: Audit  # Start with Audit, move to Enforce
  rules:
    - name: check-base-image
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["team-*"]
      validate:
        message: "Use company golden base images (registry.company.com/base/*)"
        pattern:
          spec:
            containers:
              - image: "registry.company.com/* | gcr.io/distroless/*"
```

### 2.3. Developer Self-Service Portal

What developers get without opening a ticket:

| Action | How | Security Built-in |
|--------|-----|-------------------|
| New namespace | PR to `tenants/` folder, auto-approved if template matches | PSS Restricted, NetworkPolicy, Quotas |
| Deploy app | Push to main branch | Trivy scan, Cosign sign, ArgoCD sync |
| View logs | Grafana Loki (OIDC-scoped to their namespace) | No cross-tenant access |
| View metrics | Grafana (namespace-filtered dashboards) | OIDC group filtering |
| Add secrets | AWS Secrets Manager console (IAM-scoped) | ESO syncs, never in git |
| Scale up | Update replica count in git, ArgoCD syncs | HPA limits enforced by ResourceQuota |
| Debug pod | `kubectl exec` (allowed by RBAC, logged by audit) | Falco alerts on suspicious exec commands |

### 2.4. Pre-commit Hooks

```yaml
# .pre-commit-config.yaml — developers install this
repos:
  - repo: https://github.com/hadolint/hadolint
    rev: v2.12.0
    hooks:
      - id: hadolint-docker

  - repo: https://github.com/zricethezav/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks

  - repo: https://github.com/gruntwork-io/pre-commit
    rev: v0.1.23
    hooks:
      - id: tflint

  - repo: local
    hooks:
      - id: trivy-config
        name: Trivy config scan
        entry: trivy config --exit-code 1 --severity HIGH,CRITICAL
        language: system
        files: '(\.ya?ml|Dockerfile)$'
```

### 2.5. Namespace Template (What Developers See)

Developers add their team by creating a single file:

```yaml
# tenants/team-payments.yaml
apiVersion: platform.company.com/v1
kind: TenantRequest
metadata:
  name: team-payments
spec:
  owner: payments-team@company.com
  oidcGroup: team-payments
  environment: production
  resources:
    cpu: "10"
    memory: "20Gi"
    pods: "50"
  ingress:
    enabled: true
    hosts:
      - payments.internal.company.com
  externalServices:
    - name: postgres
      port: 5432
    - name: redis
      port: 6379
```

Platform controller generates all the YAML from this single spec.

---

## 3. Day-2 Operations

### 3.1. Alert Tuning Playbook (First 30 Days)

```
Week 1: Deploy Falco in LOG-ONLY mode
  - Collect baseline events
  - Identify noisy rules (high volume, low signal)
  - Document legitimate patterns that trigger alerts

Week 2: Tune rules
  - Add exceptions for known-good patterns
  - Adjust priorities (WARNING -> NOTICE for expected behavior)
  - Example: Java apps legitimately read /proc/self/status

Week 3: Enable alerting (WARNING and above)
  - Route to Slack channel
  - Monitor false positive rate
  - Target: < 5 alerts/day that are not actionable

Week 4: Enable CRITICAL enforcement
  - PagerDuty for CRITICAL only
  - Automated response for known-bad (quarantine pod)
  - Maintain runbook for each alert type
```

### 3.2. Alert Tuning Example

```yaml
# falco/rules.d/tuning.yaml — suppress known false positives

# Java apps reading /proc/self/status is normal (JVM metrics)
- rule: Read sensitive file untrusted
  append: true
  condition: >
    and not (proc.name = "java" and fd.name startswith "/proc/self/")

# Node.js apps spawning child processes for health checks
- rule: Shell Spawned by Web Server
  append: true
  condition: >
    and not (proc.pname = "node" and proc.cmdline startswith "sh -c curl")

# ArgoCD legitimately reads secrets
- rule: Read Secret in Namespace
  append: true
  condition: >
    and not (k8s.ns.name = "argocd")
```

### 3.3. Secret Rotation Runbook

```
Scenario: Credential leaked (found in git, Falco alert, etc.)
Time budget: 60 minutes maximum

T+0min   Acknowledge alert
T+5min   Identify scope: which secret? which services use it?
T+10min  Rotate credential in AWS Secrets Manager
T+12min  ESO auto-syncs new secret to cluster (refreshInterval: 1m for emergency)
T+15min  Rolling restart affected deployments:
         kubectl rollout restart deployment/<name> -n <namespace>
T+20min  Verify new credential working (health checks pass)
T+30min  Revoke old credential in source system (AWS, database, API provider)
T+45min  Audit: who accessed the old credential? (CloudTrail, K8s audit logs)
T+60min  Post-incident note (what leaked, how, prevention)

If credential was K8s service account token:
  - Delete and recreate ServiceAccount
  - All pods using it will get new token on restart
  - Check if token was used for unauthorized API calls (audit logs)
```

### 3.4. Cluster Compromise Recovery

```
Scenario: Cluster fully compromised (attacker has cluster-admin)
Assumption: Infrastructure code is in git and untouched

Phase 1: Contain (< 15 minutes)
  - Revoke all IAM roles attached to the cluster
  - Block cluster's security group (no ingress/egress)
  - Rotate AWS credentials used by CI/CD
  - Disable ArgoCD sync (prevent attacker using GitOps)

Phase 2: Forensics (parallel with Phase 3)
  - Export CloudTrail logs for the cluster period
  - Export K8s audit logs from CloudWatch
  - Snapshot EBS volumes of affected nodes
  - Record Falco alerts timeline
  - Identify: entry point, lateral movement, data accessed

Phase 3: Rebuild (< 4 hours)
  - terraform destroy the compromised cluster
  - terraform apply a fresh cluster (same config from git)
  - Run bootstrap-security-stack.sh
  - ArgoCD re-syncs all workloads from git
  - Rotate ALL secrets (database passwords, API keys, certificates)
  - Verify: fresh cluster, fresh secrets, no persistent access

Phase 4: Harden (< 24 hours)
  - Fix the vulnerability that allowed initial access
  - Add detection rule for the attack pattern
  - Update NetworkPolicies if lateral movement was possible
  - Review and tighten RBAC based on forensics findings
```

### 3.5. Component Failure Handling

| Component Down | Impact | Auto-Recovery | Manual Action |
|----------------|--------|---------------|---------------|
| Falco pod dies | No runtime detection on that node | DaemonSet restarts | Check eBPF driver compatibility |
| Kyverno down | Pods deploy without policy check | failurePolicy: Fail blocks all deploys | Restart, or temporarily set Ignore |
| Cilium agent down | Node loses network policy enforcement | DaemonSet restarts | Cordon node until recovered |
| ArgoCD down | No new syncs, existing workloads unaffected | Deployment restart | Manual kubectl if emergency |
| ESO down | Secrets stop syncing (stale but functional) | Deployment restart | Secrets remain valid until rotated |

---

## 4. Security SLOs

Define measurable security targets:

| SLO | Target | Measurement | Breach Action |
|-----|--------|-------------|---------------|
| Image scan coverage | 100% of production images scanned | Kyverno policy report | Block deploy (admission) |
| Critical CVE patch time | < 24h from disclosure | Trivy continuous scan + ticket SLA | Escalate to engineering lead |
| PSS compliance | > 99% pods pass Restricted | Kyverno audit report | Weekly compliance review |
| Network policy coverage | 100% production namespaces | Script check (see Part 7) | Platform team fixes within 48h |
| MTTD (mean time to detect) | < 60 seconds | Falco alert timestamp | Tune rules, add coverage |
| MTTR (mean time to respond) | < 5 minutes (automated) | Alert to containment time | Improve automation |
| Secret rotation age | < 90 days for all secrets | AWS SM rotation status | Automated rotation alert |
| False positive rate | < 5% of alerts | Weekly alert review | Tune rules |
| CIS benchmark score | > 85% | Monthly kube-bench run | Sprint backlog items |

### Reporting Dashboard

```
Monthly Security Report (auto-generated)
=========================================
Period: June 2026

Compliance Score:         87% (target: 85%)  PASS
PSS Compliance:           99.2%              PASS
Critical CVE Patches:     3 patched, avg 18h PASS
Network Policy Coverage:  100%               PASS
Image Scan Coverage:      100%               PASS
Falco Alerts:             47 (42 true, 5 FP) 10.6% FP — needs tuning
Incidents:                1 (contained in 3min)
Secret Rotation:          2 overdue (>90 days) — ACTION NEEDED
```

---

## 5. Production Checklists

### New Service Deployment Checklist (for developers)

```
Before merging PR:
  [ ] Dockerfile uses golden base image
  [ ] No secrets in code or Dockerfile
  [ ] Health check endpoint defined
  [ ] Resource requests and limits set
  [ ] SecurityContext defined (nonRoot, readOnly, dropAll)
  [ ] CI pipeline passes (Trivy, Hadolint, tests)

Before production rollout:
  [ ] Image signed (Cosign, verified by Kyverno)
  [ ] NetworkPolicy allows only required connections
  [ ] ExternalSecret configured (no K8s Secret in git)
  [ ] HPA configured with sane limits
  [ ] Runbook exists for this service
```

### Platform Engineer On-Call Checklist (daily)

```
  [ ] Falco: any CRITICAL alerts in last 24h?
  [ ] Kyverno: any new policy violations?
  [ ] ArgoCD: any apps out of sync?
  [ ] Node health: any NotReady nodes?
  [ ] Certificate expiry: any certs expiring < 14 days?
  [ ] Vulnerability scan: any new CRITICAL CVEs in running images?
```

---

## 6. Key Takeaways

1. Multi-tenancy is namespace isolation + NetworkPolicy + RBAC + Quotas — all four together
2. Tenant onboarding should be a single YAML file, not a ticket
3. Golden base images remove 80% of security friction for developers
4. Kyverno in Audit mode first, Enforce after you understand what breaks
5. Alert tuning takes 30 days — budget for it, do not skip
6. Secret rotation must have a runbook with time budget (60 min max)
7. Cluster compromise recovery = destroy and rebuild from git (never patch compromised infra)
8. Security SLOs make security measurable and accountable
9. Developer self-service with baked-in security > ticket-based gatekeeping
10. Day-2 is where security succeeds or fails — setup is just the beginning

---

## References

- Kubernetes Multi-tenancy Working Group
- Hierarchical Namespace Controller documentation
- ArgoCD ApplicationSet Controller
- External Secrets Operator documentation
- Kyverno Policy Library
- Platform Engineering community patterns

---

Previous: [Part 9: Reference Architecture](./part9-platform-engineering-reference-architecture.md)
