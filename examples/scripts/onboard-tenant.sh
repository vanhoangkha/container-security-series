#!/bin/bash
# onboard-tenant.sh
# Creates a fully-secured namespace for a new team.
# Usage: ./onboard-tenant.sh <team-name> [cpu-quota] [memory-quota]

set -euo pipefail

TEAM="${1:?Usage: $0 <team-name> [cpu-quota] [memory-quota]}"
CPU="${2:-10}"
MEMORY="${3:-20Gi}"
NS="team-${TEAM}"

echo "Onboarding tenant: $TEAM"
echo "  Namespace: $NS"
echo "  CPU quota: $CPU"
echo "  Memory quota: $MEMORY"
echo ""

kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${NS}
  labels:
    tenant: "${TEAM}"
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-quota
  namespace: ${NS}
spec:
  hard:
    requests.cpu: "${CPU}"
    requests.memory: "${MEMORY}"
    limits.cpu: "$((CPU * 2))"
    limits.memory: "$((${MEMORY%Gi} * 2))Gi"
    pods: "50"
    services: "10"
    secrets: "20"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: tenant-limits
  namespace: ${NS}
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
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: ${NS}
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
  ingress:
    - from:
        - podSelector: {}
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-system
  egress:
    - to:
        - podSelector: {}
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
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tenant-edit
  namespace: ${NS}
subjects:
  - kind: Group
    name: "${TEAM}"
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${TEAM}-app
  namespace: ${NS}
automountServiceAccountToken: false
EOF

echo ""
echo "Tenant '$TEAM' onboarded successfully:"
echo "  - Namespace: $NS (PSS Restricted)"
echo "  - ResourceQuota: ${CPU} CPU / ${MEMORY} memory"
echo "  - NetworkPolicy: default-deny (internal + DNS allowed)"
echo "  - RBAC: group '${TEAM}' has edit access"
echo "  - ServiceAccount: ${TEAM}-app (no auto-mount)"
