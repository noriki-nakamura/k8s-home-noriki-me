#!/usr/bin/env bash
# cert-manager のインストール。
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-home-k8s}"

CERT_MANAGER_VERSION="v1.21.1"

helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version "${CERT_MANAGER_VERSION}" \
  --set crds.enabled=true

kubectl -n cert-manager rollout status deployment/cert-manager --timeout=180s
kubectl -n cert-manager rollout status deployment/cert-manager-webhook --timeout=180s
