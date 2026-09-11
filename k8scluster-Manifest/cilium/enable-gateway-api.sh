#!/usr/bin/env bash
# Cilium の Gateway API 機能を有効化する。
# 前提: gateway-api/install-crds.sh を先に実行し、Gateway API CRD(v1.1.0)を
#       インストールしておくこと（Ciliumが起動時にCRDの存在を要求するため）。
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-home-k8s}"

cilium upgrade --set gatewayAPI.enabled=true
cilium status --wait

# `cilium upgrade` は ConfigMap を更新するだけで、cilium-agent / cilium-envoy の
# DaemonSet を自動では再起動しない（helmのconfigmap-checksumアノテーションが
# 更新されないため）。再起動しないと Envoy にGatewayのリスナーが反映されず、
# 接続がタイムアウトし続ける（このリポジトリで実際に踏んだバグ）。
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
kubectl -n kube-system rollout restart daemonset/cilium-envoy
kubectl -n kube-system rollout status daemonset/cilium-envoy --timeout=300s

# cilium-operator も同様に手動再起動が必要（LB-IPAM/L2 Announcement設定反映のため）
kubectl -n kube-system rollout restart deployment/cilium-operator
kubectl -n kube-system rollout status deployment/cilium-operator --timeout=180s
