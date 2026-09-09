#!/usr/bin/env bash
# Cilium (CNI) のインストール。
# 前提: Local-Ansible/playbooks/setup.yml 実行済み（kubeconfig, cilium CLI導入済み）
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-home-k8s}"

CILIUM_VERSION="1.16.5"
CONTROL_PLANE_VIP="10.32.192.10"
APISERVER_PORT="6443"

cilium install \
  --version "${CILIUM_VERSION}" \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="${CONTROL_PLANE_VIP}" \
  --set k8sServicePort="${APISERVER_PORT}"

cilium status --wait
