#!/usr/bin/env bash
# NFS CSIドライバ (csi-driver-nfs) のインストール + StorageClass作成。
# 前提: Local-Ansible/playbooks/setup.yml 実行済み（kubeconfig, helm導入済み）、
#       各k8sノードに nfs-utils 導入済み（VM-Ansible の nfs_client role）
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-home-k8s}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm repo update

# helm upgrade --install は初回導入・既存アップグレードの両方を1コマンドで扱える
helm upgrade --install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
  --namespace kube-system \
  --create-namespace

kubectl -n kube-system rollout status deployment/csi-nfs-controller --timeout=180s

kubectl apply -f "${script_dir}/storageclass-nfs.yaml"
