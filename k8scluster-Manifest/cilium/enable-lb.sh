#!/usr/bin/env bash
# LoadBalancer Service用のCilium L2 Announcements機能を有効化する。
# 既存Ciliumインストールへの設定追加は `cilium install` の再実行では反映されない
# （既にインストール済みならスキップされる仕組みのため）ので `cilium upgrade` を使う。
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-home-k8s}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cilium upgrade --set l2announcements.enabled=true
cilium status --wait

kubectl apply -f "${script_dir}/lb-ip-pool.yaml"
kubectl apply -f "${script_dir}/l2-announcement-policy.yaml"
