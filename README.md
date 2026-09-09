# k8s-home-noriki-me

Proxmox 上の AlmaLinux 10.2 VM に、kubeadm + Cilium + kube-vip で
HA 構成の Kubernetes クラスタを構築する構成一式です。

## クラスタ構成

- コントロールプレーン: 3台（etcd クォーラム確保のため）
- ワーカー: 2台
- Kubernetes: kubeadm（vanilla）
- コンテナランタイム: containerd（GitHub Releases バイナリを直接展開）
- CNI: Cilium（VXLAN オーバーレイ、kube-proxy 置き換え有効）
- API サーバ VIP: kube-vip（ARP/L2 モード、外部LB不要）
- 永続化ストレージ: 既存NFSサーバー（TrueNAS）+ csi-driver-nfs
- LoadBalancer: Cilium L2 Announcements（MetalLB相当、追加ソフトウェア不要）

## 全体構成（4分割）

関心事ごとに、使うツールとディレクトリを分けています。

| ディレクトリ | 役割 | ツール |
|---|---|---|
| `Proxmox-Terraform/` | VM・Proxmox SDNネットワークの作成 | Terraform |
| `VM-Ansible/` | OS設定〜kubeadmクラスタ構築（ノードプロビジョニング） | Ansible |
| `Local-Ansible/` | kubeconfig取得、Helm/cilium CLIのローカル環境セットアップ | Ansible |
| `k8scluster-Manifest/` | Cilium拡張設定・NFS CSI等、クラスタ内リソースの管理 | kubectl / Helm / cilium CLI |

### なぜこう分けているか

- **VM-Ansible と Local-Ansible を分けている理由**: 前者は「k8sノードに対する」操作、後者は「Ansible実行ホスト自身に対する」操作で、対象ホストの種類が異なる。混在させると、`site.yml`を1回実行するたびに無関係な処理まで評価され、実行時間が伸びる。
- **k8scluster-Manifest をAnsibleでラップしていない理由**: `kubectl apply` や `helm upgrade --install` は、それ自体が既に宣言的で冪等な操作。Ansibleでラップすると、Ansible側で`changed_when`判定を手動実装する必要が生じ、Helm/kubectlが本来持つ冪等性の仕組みを劣化コピーすることになるため、直接実行する方針にしている。
- **NFSクライアント（`nfs-utils`）の導入だけはVM-Ansible側にある理由**: これは各k8sノードのOSパッケージであり、クラスタ内リソースではないため。

## セットアップ手順（実行順序）

### 1. Proxmox-Terraform（VM・ネットワーク作成）

```bash
cd Proxmox-Terraform
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集（APIトークン、SSH公開鍵）
terraform init
terraform plan
terraform apply -parallelism=1   # 複数VMの同時フルクローンでストレージロック競合が起きるため
```

詳細は「Proxmox SDN ネットワーク準備」セクションを参照。

### 2. VM-Ansible（クラスタ構築）

```bash
cd VM-Ansible
ansible-galaxy collection install -r requirements.yml
ansible k8s_cluster -m ping   # 疎通確認
ansible-playbook playbooks/site.yml
```

### 3. Local-Ansible（管理環境セットアップ）

```bash
cd Local-Ansible
ansible-playbook playbooks/setup.yml
```

kubeconfig（`~/.kube/config-home-k8s`）と、Helm/cilium CLI（`~/.local/bin/`）が
セットアップされる。既存の `~/.kube/config` は上書きしない。

### 4. k8scluster-Manifest（Cilium拡張・NFS CSI）

```bash
cd k8scluster-Manifest
export KUBECONFIG=~/.kube/config-home-k8s

./cilium/install.sh          # Cilium (CNI) インストール（初回のみ）
./cilium/enable-lb.sh        # LoadBalancer用のL2 Announcements有効化
./storage/install-nfs-csi.sh # NFS CSI + StorageClass
```

詳細は `k8scluster-Manifest/README.md` を参照。

## Proxmox SDN ネットワーク準備

既存のサーバ用 Simple Zone（`simple0`）とは別に、k8s専用の **Simple Zone**（`k8szone`）
を新規作成します。`Proxmox-Terraform/` 配下のコードで一式管理しています
（`Proxmox-Terraform/network.tf`）。手動で構築する場合は以下の手順です。

**重要**: Zone種別は VLAN Zone / VXLAN Zone ではなく **Simple Zone** を使ってください。
「Proxmoxホスト自身がこのセグメントのゲートウェイとして機能する」構成にする場合、
VLAN Zone・VXLAN Zoneのどちらも、VNetが実ポート（VLANサブインターフェースやVXLAN
トンネル）を持つbridgeになるため、SDN Subnetの `gateway` 設定がインターフェースに
自動反映されないことを実地検証済みです。Simple Zoneの `vnet0` のような
`bridge_ports none` の純粋な仮想インターフェースだけが、gatewayを正しく保持できます。
単一Proxmoxノード構成であれば、Simple Zoneの「ノードをまたぐL2非対応」という制約は
問題になりません。

1. **物理スイッチ/ルーター側**
   - 既存LANとの間で必要な通信のみ許可するルーティング/ファイアウォールを設定
   - （VLANタグ付けは不要。Simple ZoneはProxmoxホスト内で完結するため）

2. **Proxmox SDN側**（`データセンター → SDN`）
   - `Zones` → 新規作成 → タイプ「Simple」（Zone ID: `k8szone`）
   - `VNets` → 新規作成（Name: `k8snet`、Zone: `k8szone`）
   - `Subnets`（VNet `k8snet` 配下）→ 新規作成
     - CIDR: `10.32.192.0/24`、Gateway: `10.32.192.1`、SNAT: 無効
   - `Options` → **Apply**（適用を忘れると全ノードに反映されません）

3. **VM側**
   - 各k8sノードのNICの Bridge に `k8snet` を指定

4. **IPアドレス**（本構成の初期値と対応）

   | 項目 | 値 |
   |---|---|
   | サブネット | 10.32.192.0/24 |
   | ゲートウェイ | 10.32.192.1（Simple ZoneのSubnetが `k8snet` に直接付与） |
   | k8s-cp-01〜03 | .11 〜 .13 |
   | k8s-worker-01〜02 | .21 〜 .22 |
   | kube-vip VIP | .10 |
   | LoadBalancer IPプール | .128 〜 .255（`/25`） |

## 変更が必要な設定

1. `VM-Ansible/inventory/hosts.yml`
   - `ansible_host` を実際のノードIPに置き換える
2. `VM-Ansible/inventory/group_vars/all.yml`
   - `control_plane_vip`: kube-vip が広報するVIP（未使用IPを指定）
   - `control_plane_vip_interface`: VIPを broadcast するNIC名（`ip a` で確認）
   - `pod_subnet` / `service_subnet`: 既存ネットワークと重複しないCIDR
   - `k8s_minor_version`: 導入時点の最新安定版に合わせる
     （https://kubernetes.io/releases/ を確認）
3. `k8scluster-Manifest/` 配下の各スクリプト・YAML
   - Cilium/Helmバージョン、NFSサーバー情報、LoadBalancer IPプール範囲等は
     各ファイルに直接記載しているので、変更する場合は該当ファイルを編集する
   - NFSサーバー側は事前に対象ネットワークからのアクセス許可・root squash設定が必要

## 構築後の確認

```bash
export KUBECONFIG=~/.kube/config-home-k8s
kubectl get nodes -o wide
kubectl -n kube-system get pods
cilium status
```

VIP 経由での疎通確認:

```bash
curl -k https://<control_plane_vip>:6443/healthz
```

## ディレクトリ構成

```
Proxmox-Terraform/     # VM・Proxmox SDNネットワーク作成（Terraform）
VM-Ansible/            # ノードプロビジョニング（Ansible）
  inventory/             # インベントリ・変数
  playbooks/site.yml     # 一括実行用エントリポイント
  roles/
    common/                # OS共通セットアップ（swap無効化, sysctl, firewalld, chrony等）
    container_runtime/     # containerd インストール
    kubernetes_packages/   # kubeadm/kubelet/kubectl インストール
    kube_vip/              # kube-vip static pod 配置（全CPノード）
    control_plane_init/    # 最初のCPノードで kubeadm init
    control_plane_join/    # 2, 3台目のCPノードを join
    workers_join/          # ワーカーノードを join
    nfs_client/            # NFSクライアントパッケージ導入（全ノード）
Local-Ansible/         # Ansible実行ホスト自身のセットアップ（Ansible）
  playbooks/setup.yml    # kubeconfig取得 + Helm/cilium CLI導入
  roles/kube_tools/      # Helm/cilium CLIのダウンロード・配置
k8scluster-Manifest/   # クラスタ内リソース管理（kubectl/Helm/cilium CLI直接実行）
  cilium/                # Cilium本体 + LoadBalancer(L2 Announcements)設定
  storage/               # NFS CSI + StorageClass
```

## 永続化ストレージ（NFS CSI）の利用

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: example-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-csi
  resources:
    requests:
      storage: 5Gi
```

`storageClassName: nfs-csi` を指定するだけで、既存NFSサーバー上に動的にボリューム
（サブディレクトリ）が作成されます。MySQL等のStatefulSetでは、この形式の
`volumeClaimTemplates` を使ってください。

## LoadBalancer Service の利用

```yaml
apiVersion: v1
kind: Service
metadata:
  name: example-svc
spec:
  type: LoadBalancer
  selector:
    app: example
  ports:
    - port: 80
      targetPort: 80
```

`type: LoadBalancer` を指定するだけで、IPプール（既定: `10.32.192.128/25`）
の範囲からIPが自動的に割り当てられ、ARP経由で既存LANから到達可能になります
（動作確認済み）。クラウド環境のような外部ロードバランサープロビジョナーは不要です。

## 既知の注意点

- SELinux は kubeadm 公式手順に準拠し `permissive` を既定にしています
  （`VM-Ansible/inventory/group_vars/all.yml` の `selinux_state` で変更可能）。
- kube-proxy 置き換え（Cilium eBPF）を有効にしているため、
  `kubeadm init` 時に `--skip-phases=addon/kube-proxy` を付与しています。
- コントロールプレーンの証明書キー（`certificate-key`）は 2時間で失効します。
  `site.yml` は同一実行内で発行〜join まで完結するため通常は問題ありませんが、
  join だけをやり直す場合は certificate-key の再発行が必要です。
- 本構成は Ingress Controller を含みません。必要に応じて別途導入してください。
- kube-vipの「鶏と卵」問題: kubeadm 1.31以降、`admin.conf` のOrganizationが
  `system:masters` ではなく `kubeadm:cluster-admins` に変わり、そのグループへの
  `cluster-admin` バインディングは `kubeadm init` 完了時に作成される。しかし
  `wait-control-plane` フェーズの段階では、`admin.conf` をマウントするkube-vipが
  まだ十分な権限を持たずリーダー選出に失敗し、VIPが機能しないため、VIP経由の
  ヘルスチェックがタイムアウトする。これを避けるため `control_plane_init` role は
  `kubeadm init` を非同期実行し、完了を待つ間に `super-admin.conf`
  （`system:masters` 相当）経由で `kubeadm:cluster-admins` グループへの
  ClusterRoleBindingとkube-vip用RBACを先に適用している。
- Generic Cloud Imageのテンプレートは、初回のパッケージ更新でカーネルが
  更新されるが再起動されていない状態のことがある。`common` roleは
  `kernel-core` の最新インストール済みバージョンと稼働中カーネルを比較し、
  異なれば自動的に再起動する（`br_netfilter` 等のカーネルモジュールが
  稼働中カーネルのモジュールディレクトリに存在しないため必須）。
- 複数回 `kubeadm reset` を行ったノードでは、containerdが内部的に古い
  CNI状態をキャッシュし、CNI設定ファイルが正しくてもkubeletが
  `cni plugin not initialized` を報告し続けることがある。この場合は
  `systemctl restart containerd` で解消する（kubelet再起動だけでは直らない）。
- `control_plane_init` role で `async(poll:0) + creates` を組み合わせたタスクは、
  `creates` 条件でスキップされる場合でも `changed` 判定が信頼できないことがある
  （既存クラスタに対して `site.yml` を再実行した際、`kubeadm init` はスキップ
  されたのに後続タスクの `when: kubeadm_init_async.changed` が誤って `true` に
  なり、RBAC作成タスクが再実行され重複エラーになった）。そのため
  `ansible.builtin.stat` で `admin.conf` の事前存在を明示的に確認し、
  そちらを `when` 条件に使っている。
- 永続化ストレージ（NFS CSI）: 既存NFSサーバーの Authorized Networks は
  k8sノードのセグメント（`10.32.192.0/24`）に限定し、root squash設定
  （Maproot User/Group を `root` 等）も確認すること。
- Cilium CLIには `install`（初回導入）と `upgrade`（既存設定への追加変更）が
  明確に分かれており、Helmの `upgrade --install` のような統合コマンドはない。
  初回は必ず `cilium install`、既存クラスタへの設定変更は `cilium upgrade` を使う。
