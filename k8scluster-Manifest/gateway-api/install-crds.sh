#!/usr/bin/env bash
# Gateway API CRDs のインストール。
# Cilium 1.16 系がサポートするのは Gateway API v1.1.0（最新の v1.6系ではない）。
# 標準CRDに加え、Cilium側の既知の問題によりexperimental CRD（TLSRoute）も必要。
# 参照: https://docs.cilium.io/en/v1.16/network/servicemesh/gateway-api/gateway-api/
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-home-k8s}"

GATEWAY_API_VERSION="v1.1.0"
BASE_URL="https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_API_VERSION}/config/crd"

for crd in gatewayclasses gateways httproutes referencegrants grpcroutes; do
  kubectl apply -f "${BASE_URL}/standard/gateway.networking.k8s.io_${crd}.yaml"
done

# experimental（TLSRoute）
kubectl apply -f "${BASE_URL}/experimental/gateway.networking.k8s.io_tlsroutes.yaml"
