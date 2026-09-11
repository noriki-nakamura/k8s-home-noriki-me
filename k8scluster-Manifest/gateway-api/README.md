# Gateway API (HTTPS対応)

Cilium の Gateway API 機能を使い、`*.home.noriki.me` 宛のHTTPSトラフィックを
1つのLoadBalancer IPで受けて、複数サービスへルーティングする。

## 実行順序

```bash
export KUBECONFIG=~/.kube/config-home-k8s

# 1. Gateway API CRD (v1.1.0) をインストール
./install-crds.sh

# 2. Cilium の Gateway API機能を有効化
../cilium/enable-gateway-api.sh

# 3. GatewayClass を作成
kubectl apply -f gatewayclass.yaml

# 4. cert-manager でワイルドカード証明書を発行（cert-manager/README.md参照）

# 5. Gateway を作成（証明書Secretが存在してから）
kubectl apply -f gateway.yaml
```

## バージョンについて

Cilium 1.16系がサポートするのは Gateway API **v1.1.0** で、最新版（v1.6系）
ではない。`install-crds.sh` は明示的にv1.1.0を指定している。Ciliumを
アップグレードした場合は、対応するGateway APIバージョンを
https://docs.cilium.io/ で確認すること。

## サービスの公開方法（HTTPRouteの追加）

各サービスは `HTTPRoute` リソースで、この Gateway (`home-k8s-gateway`) に
ルーティングルールを追加する形で公開する。例:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: example-route
  namespace: default
spec:
  parentRefs:
    - name: home-k8s-gateway
      namespace: default
  hostnames:
    - "example.home.noriki.me"
  rules:
    - backendRefs:
        - name: example-svc
          port: 80
```

`example-svc` は通常の `ClusterIP` Serviceでよい（`type: LoadBalancer` は
Gateway自体が1つ持てば十分なので、個別サービスには不要）。

## 動作確認

```bash
kubectl get gateway home-k8s-gateway
kubectl get httproute
kubectl get svc -n default   # Gatewayが生成するLoadBalancer Serviceを確認
```

## 前提: 全ノードでTCP/80・443をfirewalldで許可しておくこと

L2 Announcementの担当ノード（Ciliumのリーダー選出で決まり、再起動のたびに
変わりうる）が firewalld で 80/tcp・443/tcp をブロックしていると、クライアント
からの接続は（ARP解決やCilium側のリスナー設定が全て正しくても）タイムアウト
し続ける。`VM-Ansible/roles/common/tasks/main.yml` の
「Cilium Gateway (HTTP/HTTPS) 用ポートを許可」タスクで全ノード共通に開放して
いるので、新規ノード追加時もこのタスクを含むPlaybookを流せば自動的に反映される。
