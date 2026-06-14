#!/bin/bash
# bootstrap-security-stack.sh
# Deploys the full security stack on a fresh EKS cluster.
# Run ONCE after terraform apply creates the cluster.
# Usage: ./bootstrap-security-stack.sh <cluster-name> [region]

set -euo pipefail

CLUSTER_NAME="${1:?Usage: $0 <cluster-name> [region]}"
REGION="${2:-ap-southeast-1}"

echo "=== Configuring kubeconfig ==="
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

echo ""
echo "=== Phase 1: Cilium CNI ==="
helm repo add cilium https://helm.cilium.io/ --force-update
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --set eni.enabled=true \
  --set ipam.mode=eni \
  --set egressMasqueradeInterfaces=eth0 \
  --set routingMode=native \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --wait --timeout 5m
echo "  Cilium installed."

echo ""
echo "=== Phase 1: External Secrets Operator ==="
helm repo add external-secrets https://charts.external-secrets.io --force-update
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace \
  --wait --timeout 3m
echo "  ESO installed."

echo ""
echo "=== Phase 2: Kyverno ==="
helm repo add kyverno https://kyverno.github.io/kyverno/ --force-update
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno --create-namespace \
  --set admissionController.replicas=3 \
  --set backgroundController.replicas=2 \
  --wait --timeout 3m
echo "  Kyverno installed."

echo ""
echo "=== Phase 2: Apply Kyverno Policies ==="
kubectl apply -f "$(dirname "$0")/../kyverno/policies.yaml"
echo "  Policies applied."

echo ""
echo "=== Phase 3: Falco ==="
helm repo add falcosecurity https://falcosecurity.github.io/charts --force-update
helm upgrade --install falco falcosecurity/falco \
  --namespace falco --create-namespace \
  -f "$(dirname "$0")/../falco/values.yaml" \
  --wait --timeout 5m
echo "  Falco installed."

echo ""
echo "=== Phase 3: Apply Custom Falco Rules ==="
kubectl create configmap falco-custom-rules \
  --from-file="$(dirname "$0")/../falco/custom-rules.yaml" \
  --namespace falco --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart daemonset/falco -n falco
echo "  Custom rules applied."

echo ""
echo "=== Phase 4: ArgoCD ==="
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --set server.extraArgs[0]="--insecure" \
  --wait --timeout 3m
echo "  ArgoCD installed."

echo ""
echo "==========================================="
echo "  Bootstrap complete."
echo "  ArgoCD manages all future changes via git."
echo ""
echo "  Access ArgoCD UI:"
echo "    kubectl port-forward svc/argocd-server -n argocd 8443:443"
echo "    Username: admin"
echo "    Password: kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d"
echo "==========================================="
