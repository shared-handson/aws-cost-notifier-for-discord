# AWS Cost Notifier for Discord

定期的にAWSのコストを取得してDiscordにWebhookで通知するサーバレスアプリケーションです。

## 🚀 概要

このプロジェクトは、AWSの利用料金を定期的に監視し、Discord WebhookでチャンネルやDMに通知するシステムです。Terraformを使用したInfrastructure as Code（IaC）で構築され、完全にサーバレスで動作します。

## 📋 機能

- ✅ AWS Cost Explorer APIを使用したコスト取得
- ✅ 過去7日間の利用料金の集計
- ✅ Discord Webhookでの美しい通知
- ✅ EventBridge（CloudWatch Events）による定期実行
- ✅ Terraformによる完全なIaC構成
- ✅ セキュアなIAM権限設定
- ✅ 詳細なロギングとエラーハンドリング

## 🏗️ アーキテクチャ

```
EventBridge Rule (cron) → Lambda Function → Cost Explorer API
                                    ↓
                          Discord Webhook Notification
```

### 使用するAWSサービス

- **AWS Lambda**: コスト取得と通知処理
- **EventBridge**: 定期実行スケジューリング
- **Cost Explorer API**: コストデータの取得
- **S3**: Lambdaデプロイメントパッケージの保存
- **IAM**: 最小権限でのアクセス制御

## 🛠️ セットアップ

### 前提条件

- AWS CLI設定済み
- Terraform >= 1.0
- Discord Webhook URL

### 1. リポジトリのクローン

```bash
git clone <repository-url>
cd aws-cost-notifier-for-discord
```

### 2. Discord Webhookの設定

1. Discordサーバーで設定 → インテグレーション → Webhook を作成
2. Webhook URLをコピー

### 3. Terraform設定

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` を編集:

```hcl
aws_region          = "us-east-1"  # Cost Explorer APIはus-east-1が必要
environment         = "prod"
discord_webhook_url = "YOUR_DISCORD_WEBHOOK_URL"
schedule_expression = "cron(0 9 * * ? *)"  # 毎日午前9時 (UTC)
```

### 4. デプロイ

```bash
terraform init
terraform plan
terraform apply
```

## 📊 通知内容

Discord通知には以下の情報が含まれます：

- 📅 **期間**: 過去7日間
- 💸 **合計金額**: USD表示
- 🎨 **視覚的な埋め込み**: AWSブランディング
- ⚡ **メタデータ**: Terraform生成の表示

## ⚙️ カスタマイズ

### スケジュール変更

`schedule_expression` 変数で実行頻度を変更できます：

```hcl
# 毎日午前9時
schedule_expression = "cron(0 9 * * ? *)"

# 毎週月曜日午前8時
schedule_expression = "cron(0 8 ? * MON *)"

# 5分ごと（テスト用）
schedule_expression = "rate(5 minutes)"
```

### コスト期間の変更

Lambda関数内の `timedelta(days=7)` を変更することで、異なる期間のコストを取得できます。

## 🔧 開発・テスト

### ローカルテスト

```bash
cd lambda
# 環境変数を設定
export DISCORD_WEBHOOK_URL="YOUR_WEBHOOK_URL"

# 直接実行
python lambda_function.py
```

### Lambda関数の手動実行

AWS Consoleまたは AWS CLI でテスト実行:

```bash
aws lambda invoke \
  --function-name aws-cost-notifier-prod \
  --payload '{}' \
  response.json
```

## 📝 設定変数

| 変数名 | 説明 | デフォルト | 必須 |
|--------|------|-----------|------|
| `aws_region` | AWSリージョン | `us-east-1` | ✅ |
| `environment` | 環境名 | `dev` | ✅ |
| `discord_webhook_url` | Discord Webhook URL | - | ✅ |
| `schedule_expression` | 実行スケジュール | `cron(0 9 * * ? *)` | ❌ |

## 🔒 セキュリティ

- IAMロールには最小限の権限のみを付与
- Discord Webhook URLは環境変数で管理
- S3バケットはpublicアクセスをブロック
- Lambda実行ログをCloudWatch Logsで監視

## 💰 コスト

このシステムの運用コストは非常に低く、以下の要素で構成されます：

- Lambda実行: 月間数回の実行で $0.01未満
- EventBridge: 月間数回のイベントで $0.01未満  
- S3ストレージ: デプロイパッケージで $0.01未満
- Cost Explorer API: 月間数回の呼び出しで無料

**月間推定コスト: $0.10未満**

## 🚀 高度な設定

### 複数環境対応

```bash
# 開発環境
terraform workspace new dev
terraform apply -var="environment=dev"

# 本番環境  
terraform workspace new prod
terraform apply -var="environment=prod"
```

### 通知のカスタマイズ

Lambda関数の `post_to_discord()` 関数を編集して、通知内容や外観を変更できます。

## 🐛 トラブルシューティング

### よくある問題

1. **Cost Explorer APIエラー**
   - リージョンが `us-east-1` に設定されているか確認
   - IAM権限に `ce:GetCostAndUsage` が含まれているか確認

2. **Discord通知が届かない**
   - Webhook URLが正しいか確認
   - Lambda関数のログをCloudWatch Logsで確認

3. **Lambda実行エラー**
   - 環境変数 `DISCORD_WEBHOOK_URL` が設定されているか確認
   - IAMロールの権限を確認

### ログの確認

```bash
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/aws-cost-notifier"
aws logs tail /aws/lambda/aws-cost-notifier-prod --follow
```

## 📚 参考資料

- [AWS Cost Explorer API](https://docs.aws.amazon.com/cost-explorer/)
- [Discord Webhooks](https://discord.com/developers/docs/resources/webhook)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)
- [EventBridge Cron Expressions](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-create-rule-schedule.html)

## 🤝 コントリビューション

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 ライセンス

このプロジェクトは MIT License の下で公開されています。詳細は [LICENSE](LICENSE) ファイルをご覧ください。

---

⚡ **Generated with Terraform & Claude Code**