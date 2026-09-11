#!/usr/bin/env bash
# Headlamp (k8sクラスタ閲覧用Web UI) のインストール。
# 前提: gateway-api/ ・ cert-manager/ のセットアップが完了していること
#       （*.home.noriki.me のワイルドカード証明書がdefault namespaceに存在する）
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-home-k8s}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm repo update

helm upgrade --install headlamp headlamp/headlamp \
  --namespace kube-system \
  --create-namespace

kubectl -n kube-system rollout status deployment/headlamp --timeout=180s

# 閲覧専用ログイン用ServiceAccount + RBAC + 長期トークン
kubectl apply -f "${script_dir}/viewer-rbac.yaml"

# Gateway API経由での公開 (https://k8s-dashboard.home.noriki.me)
kubectl apply -f "${script_dir}/httproute.yaml"

echo
echo "ログイン用トークンは以下で取得できます:"
echo "  kubectl -n kube-system get secret headlamp-viewer-token -o jsonpath='{.data.token}' | base64 -d"
