# Headlamp (ブラウザでのクラスタ閲覧UI)

[Headlamp](https://headlamp.dev/) はCNCFプロジェクトのKubernetes Web UI。
`https://k8s-dashboard.home.noriki.me` でクラスタ内リソースをブラウザから
閲覧できるようにする。

## 前提

- `gateway-api/` ・ `cert-manager/` のセットアップが完了していること
  （Gateway と `*.home.noriki.me` のワイルドカード証明書が存在すること）
- 自宅LAN内のDNS（またはhostsファイル）で `k8s-dashboard.home.noriki.me` が
  クラスタのLoadBalancer IPを指すよう設定されていること
- LAN内からのみアクセスされる想定（外部公開・追加の認証基盤は導入していない）

## インストール

```bash
export KUBECONFIG=~/.kube/config-home-k8s
./install.sh
```

`install.sh` は以下を行う。

1. Helm chart `headlamp/headlamp` を `kube-system` namespace にインストール
   （Pod自身のServiceAccountはchartデフォルトの `cluster-admin` のまま）
2. 閲覧専用ログイン用の `headlamp-viewer` ServiceAccountをRBAC
   （`view` ClusterRole + Node/Namespace等cluster-scopedリソース閲覧権限）
   付きで作成し、有効期限なしの長期トークンを発行（`viewer-rbac.yaml`）
3. `home-k8s-gateway` にHTTPRouteを追加して公開（`httproute.yaml`）

## ログイン方法

Headlampはブラウザで入力したトークンをそのままKubernetes APIへの認証情報
として使うプロキシとして動作する。そのため、ここで発行したトークンでログ
インする限り「閲覧のみ」の権限に制限される。

```bash
kubectl -n kube-system get secret headlamp-viewer-token \
  -o jsonpath='{.data.token}' | base64 -d
```

1. ブラウザで `https://k8s-dashboard.home.noriki.me` を開く
2. 上記コマンドで取得したトークンを貼り付けてログイン

トークンはブラウザのlocalStorageに保存されるため、次回以降の入力は不要。

## 動作確認

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=headlamp
kubectl -n kube-system get svc headlamp
kubectl -n kube-system get httproute headlamp
```

## 権限を変更したい場合

`viewer-rbac.yaml` の `headlamp-cluster-view` ClusterRole・
ClusterRoleBinding を編集して `kubectl apply -f viewer-rbac.yaml` を再実行
する。Pod自身の権限（chartデフォルトの `cluster-admin`）を絞りたい場合は
`install.sh` の `helm upgrade --install` に
`--set clusterRoleBinding.clusterRoleName=view` 等を追加する。
