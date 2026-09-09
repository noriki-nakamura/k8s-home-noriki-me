# k8scluster-Manifest

Kubernetesクラスタ内リソース（CNI/CSI等のアドオン）を、kubectl/Helm/cilium CLI で
直接管理するためのマニフェスト・スクリプト一式です。

Ansibleでラップしない理由: `kubectl apply` や `helm upgrade --install` は
それ自体が既に宣言的で冪等な操作です。Ansibleでラップすると、Ansible側で
`changed_when` 判定を手動実装する必要が生じ、Helm/kubectlが本来持つ
冪等性の仕組みを劣化コピーすることになるため、直接実行する方針にしています。

## 前提条件

`Local-Ansible/playbooks/setup.yml` を実行済みで、以下が揃っていること。

- `~/.kube/config-home-k8s`（kubeconfig）
- `~/.local/bin/helm`, `~/.local/bin/cilium`（CLI）

## 実行順序

```bash
# 1. Cilium (CNI) インストール
./cilium/install.sh

# 2. LoadBalancer Service用のL2 Announcements有効化
./cilium/enable-lb.sh

# 3. NFS CSIドライバ + StorageClass
./storage/install-nfs-csi.sh
```

## ディレクトリ構成

```
cilium/
  install.sh                    # Cilium本体のインストール
  enable-lb.sh                  # L2 Announcements有効化 + マニフェスト適用
  lb-ip-pool.yaml                # CiliumLoadBalancerIPPool
  l2-announcement-policy.yaml    # CiliumL2AnnouncementPolicy
storage/
  install-nfs-csi.sh            # csi-driver-nfs導入 + StorageClass適用
  storageclass-nfs.yaml         # StorageClass定義
```

## 設定値を変更する場合

各スクリプト・YAMLファイルに直接値を記載しています（バージョン、IPプール範囲、
NFSサーバー情報等）。変更する場合はファイルを直接編集してください。
