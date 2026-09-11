# cert-manager + Let's Encrypt (Route53 DNS-01)

ワイルドカード証明書（`*.home.noriki.me`）を Let's Encrypt から自動発行・更新する。
DNS-01チャレンジには AWS Route53 の DNS レコードを書き換える権限が必要。

## 1. AWS側の準備（先に実施）

cert-manager専用の最小権限IAMユーザーを作成する。

**IAMポリシー例**（`hostedZoneID` を `cluster-issuer.yaml` で指定する場合は
3番目のStatementは不要）:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "route53:GetChange",
      "Resource": "arn:aws:route53:::change/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/*"
    },
    {
      "Effect": "Allow",
      "Action": "route53:ListHostedZonesByName",
      "Resource": "*"
    }
  ]
}
```

このIAMユーザーのアクセスキー（Access Key ID / Secret Access Key）を発行する。

## 2. cert-manager のインストール

```bash
./install.sh
```

## 3. Route53認証情報をSecretとして作成

**アクセスキーはファイルに書かず、その場でコマンド実行してください**
（このリポジトリのファイルには一切含まれません）。

```bash
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic route53-credentials \
  --namespace cert-manager \
  --from-literal=access-key-id='<AWS Access Key ID>' \
  --from-literal=secret-access-key='<AWS Secret Access Key>'
```

## 4. ClusterIssuer と Certificate を適用

```bash
kubectl apply -f cluster-issuer.yaml
kubectl apply -f wildcard-certificate.yaml
```

## 5. 証明書発行の確認

```bash
kubectl get certificate wildcard-home-noriki-me -w
# READY が True になるまで数分かかる（DNS-01チャレンジのTXTレコード伝播待ち）

kubectl describe certificate wildcard-home-noriki-me   # 失敗時の詳細確認
kubectl -n cert-manager logs -l app=cert-manager --tail=50   # cert-managerのログ
```

発行された証明書は `default` namespace の `wildcard-home-noriki-me-tls` Secret
に保存され、`gateway-api/gateway.yaml` の Gateway リソースから参照される。

## 更新について

Let's Encrypt証明書の有効期限は90日。cert-managerが有効期限の約2/3が
経過した時点で自動更新するため、手動対応は不要。
