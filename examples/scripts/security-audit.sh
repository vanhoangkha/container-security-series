#!/bin/bash
# security-audit.sh
# Quick cluster security posture assessment.
# Usage: ./security-audit.sh

set -euo pipefail

echo "==========================================="
echo "  KUBERNETES SECURITY AUDIT"
echo "  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "  Cluster: $(kubectl config current-context)"
echo "==========================================="

ISSUES=0

echo ""
echo "--- CRITICAL: Privileged Containers ---"
PRIV=$(kubectl get pods -A -o json | jq -r '
  .items[] | select(
    .spec.containers[].securityContext.privileged == true
  ) | "\(.metadata.namespace)/\(.metadata.name)"' | grep -cv "kube-system\|falco\|cilium" || echo 0)
echo "  Found: $PRIV (excluding system namespaces)"
ISSUES=$((ISSUES + PRIV))

echo ""
echo "--- CRITICAL: Containers Running as Root ---"
ROOT=$(kubectl get pods -A -o json | jq -r '
  [.items[] | select(
    (.spec.securityContext.runAsNonRoot != true) and
    (.spec.containers[].securityContext.runAsNonRoot != true) and
    (.metadata.namespace | startswith("kube-") | not)
  )] | length')
echo "  Found: $ROOT pods without runAsNonRoot"
ISSUES=$((ISSUES + ROOT))

echo ""
echo "--- HIGH: Namespaces Without NetworkPolicy ---"
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  if echo "kube-system kube-public kube-node-lease" | grep -qw "$ns"; then continue; fi
  count=$(kubectl get networkpolicy -n "$ns" --no-headers 2>/dev/null | wc -l)
  if [ "$count" -eq 0 ]; then
    echo "  MISSING: $ns"
    ISSUES=$((ISSUES + 1))
  fi
done

echo ""
echo "--- HIGH: Images Using :latest ---"
LATEST=$(kubectl get pods -A -o json | jq -r '
  [.items[].spec.containers[].image | select(endswith(":latest") or (contains(":") | not))] | unique | .[]')
if [ -n "$LATEST" ]; then
  echo "$LATEST" | while read -r img; do echo "  $img"; done
  ISSUES=$((ISSUES + $(echo "$LATEST" | wc -l)))
else
  echo "  None found."
fi

echo ""
echo "--- HIGH: cluster-admin Bindings ---"
ADMINS=$(kubectl get clusterrolebindings -o json | jq -r '
  .items[] | select(.roleRef.name=="cluster-admin") |
  "\(.metadata.name) -> \(.subjects[0].kind)/\(.subjects[0].name)"')
echo "$ADMINS" | head -10
echo "  Total: $(echo "$ADMINS" | wc -l) bindings"

echo ""
echo "--- MEDIUM: Pods With automountServiceAccountToken (default) ---"
AUTO=$(kubectl get pods -A -o json | jq -r '
  [.items[] | select(
    .spec.automountServiceAccountToken != false and
    (.metadata.namespace | startswith("kube-") | not)
  )] | length')
echo "  $AUTO pods auto-mounting SA tokens"

echo ""
echo "--- INFO: Pod Security Standards Coverage ---"
PSS=$(kubectl get ns -l pod-security.kubernetes.io/enforce --no-headers 2>/dev/null | wc -l)
TOTAL_NS=$(kubectl get ns --no-headers | wc -l)
echo "  $PSS / $TOTAL_NS namespaces have PSS enforce label"

echo ""
echo "--- INFO: Security Components Status ---"
echo "  Falco:    $(kubectl get pods -n falco --no-headers 2>/dev/null | grep -c Running || echo 'NOT INSTALLED')"
echo "  Kyverno:  $(kubectl get pods -n kyverno --no-headers 2>/dev/null | grep -c Running || echo 'NOT INSTALLED')"
echo "  Cilium:   $(kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium-agent --no-headers 2>/dev/null | grep -c Running || echo 'NOT INSTALLED')"

echo ""
echo "==========================================="
echo "  TOTAL ISSUES: $ISSUES"
if [ "$ISSUES" -gt 0 ]; then
  echo "  STATUS: NEEDS ATTENTION"
else
  echo "  STATUS: PASS"
fi
echo "==========================================="
