# AWS Cost Notifier for Discord

[![Terraform](https://img.shields.io/badge/Terraform-1.12.2+-purple.svg)](https://terraform.io)
[![AWS Provider](https://img.shields.io/badge/AWS%20Provider-6.0+-orange.svg)](https://registry.terraform.io/providers/hashicorp/aws/)
[![Python](https://img.shields.io/badge/Python-3.11-blue.svg)](https://python.org)
[![uv](https://img.shields.io/badge/uv-package%20manager-green.svg)](https://docs.astral.sh/uv/)

定期的にAWSのコストを取得してDiscordにWebhookで通知するサーバレスアプリケーションです。

## 🚀 概要

このプロジェクトは、AWSの利用料金を定期的に監視し、Discord WebhookでチャンネルやDMに通知するシステムです。Terraformを使用したInfrastructure as Code（IaC）で構築され、完全にサーバレスで動作します。

## ✨ 主な特徴

- 🎯 **JST対応**: EventBridge Schedulerで日本時間での正確な実行
- ⚡ **ARM64最適化**: コスト効率と性能を両立したLambda実行
- 🔧 **uv高速ビルド**: Rust製パッケージマネージャーによる高速デプロイ
- 🚀 **GitHub Actions**: 完全自動化されたCI/CDパイプライン
- 🔐 **セキュア設計**: 最小権限IAMロールとOIDC認証

## 📋 機能

- ✅ AWS Cost Explorer APIを使用したコスト取得
- ✅ 過去7日間の利用料金の集計（設定可能）
- ✅ Discord Webhookでの美しい通知
- ✅ EventBridge Scheduler による JST 定期実行
- ✅ Terraformによる完全なIaC構成
- ✅ 動的ログレベル制御
- ✅ GitHub Actions CI/CD
- ✅ セキュアなIAM権限設定

## 🏗️ アーキテクチャ

```
EventBridge Scheduler (JST) → Lambda Function (ARM64) → Cost Explorer API
         ↓                             ↓
  Schedule Group              Discord Webhook Notification
```

### 使用するAWSサービス

- **AWS Lambda**: コスト取得と通知処理（Python 3.11 ARM64）
- **EventBridge Scheduler**: JST対応の定期実行スケジューリング
- **Cost Explorer API**: コストデータの取得（us-east-1必須）
- **CloudWatch Logs**: ログ管理と監視（3日間保持）
- **IAM**: 最小権限でのアクセス制御

## 🛠️ セットアップ

### 前提条件

- AWS CLI設定済み（OIDC推奨）
- Terraform >= 1.12.2
- Discord Webhook URL
- Python 3.11+ & [uv](https://docs.astral.sh/uv/)（開発時）

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
aws_region          = "ap-northeast-1"  # 任意のリージョン
environment         = "prod"
webhook_url         = "YOUR_DISCORD_WEBHOOK_URL"
schedule_expression = "cron(0 9 * * ? *)"  # 毎日JST 9:00 AM
log_level           = "ERROR"            # DEBUG,INFO,WARNING,ERROR,CRITICAL
webhook_username    = "AWS Cost Notifier"
webhook_avatar_url  = "https://shared-handson.github.io/icons-factory/aws/Cloud-logo.png"
cost_period_days    = 7                  # 1-90日
```

### 4. デプロイ

```bash
terraform init
terraform validate
terraform fmt
terraform plan
terraform apply
```

## 📊 通知内容

Discord通知には以下の情報が含まれます：

- 📅 **期間**: 設定可能な日数（デフォルト7日間）
- 💸 **合計金額**: USD表示
- 🎨 **視覚的な埋め込み**: AWSブランディング
- ⚡ **メタデータ**: 実行時刻とランタイム情報
- 🕐 **JST時刻**: 日本時間での正確な実行

## ⚙️ カスタマイズ

### スケジュール変更（JST対応）

EventBridge Schedulerは `Asia/Tokyo` タイムゾーンで実行されます：

```hcl
# 毎日JST午前9時
schedule_expression = "cron(0 9 * * ? *)"

# 毎週月曜日JST午前8時
schedule_expression = "cron(0 8 ? * MON *)"

# 毎時（テスト用）
schedule_expression = "cron(0 * * * ? *)"
```

### ログレベル制御

Terraform変数でLambda関数のログレベルを制御：

```hcl
log_level = "DEBUG"    # 詳細なデバッグ情報
log_level = "INFO"     # 一般的な情報
log_level = "WARNING"  # 警告メッセージ
log_level = "ERROR"    # エラーのみ（デフォルト）
log_level = "CRITICAL" # 重大なエラーのみ
```

### コスト取得期間の変更

```hcl
cost_period_days = 30  # 過去30日間のコスト
cost_period_days = 1   # 過去1日間のコスト
cost_period_days = 90  # 過去90日間のコスト（最大）
```

## 🔧 開発・テスト

現在、テスト環境は本番Lambda環境での手動実行を推奨しています。

### Lambda関数の手動テスト

AWS Consoleまたは AWS CLI でテスト実行:

```bash
aws lambda invoke \
  --function-name aws-cost-notifier-prod \
  --payload '{}' \
  response.json

cat response.json
```

### ログの確認

```bash
# CloudWatch Logsでリアルタイム監視
aws logs tail /aws/lambda/aws-cost-notifier-lambda-prod --follow

# EventBridge Schedulerの実行履歴確認
aws scheduler list-schedules --group-name aws-cost-notification-group-prod
```

## 🚀 GitHub Actions CI/CD

### ワークフロー構成

- **terraform-plan.yml**: PR時の計画確認
- **terraform-apply.yml**: main ブランチへの自動デプロイ  
- **terraform-destroy-plan.yml**: 破棄計画の確認
- **terraform-destroy-exec.yml**: リソース破棄実行

### セキュリティ機能

- AWS OIDC認証（IAMロール）
- Terraform State の S3 バックエンド
- Discord 通知での自動メンション
- デプロイスキップ制御（`no_terraform.txt`）

### デプロイスキップ

緊急時にデプロイを停止する場合：

```bash
# デプロイ停止
echo "emergency stop" > no_terraform.txt
git add no_terraform.txt
git commit -m "Stop terraform deployment"
git push

# デプロイ再開
rm no_terraform.txt
git add -A
git commit -m "Resume terraform deployment"
git push
```

## 📝 設定変数

| 変数名 | 説明 | デフォルト | 必須 |
|--------|------|-----------|------|
| `aws_region` | AWSリージョン | `ap-northeast-1` | ✅ |
| `environment` | 環境名 | `dev` | ✅ |
| `webhook_url` | Discord Webhook URL | - | ✅ |
| `schedule_expression` | 実行スケジュール | `cron(0 9 * * ? *)` | ❌ |
| `log_level` | Pythonログレベル | `ERROR` | ❌ |
| `webhook_username` | Discordユーザー名 | `AWS Notifier` | ❌ |
| `webhook_avatar_url` | アバター画像URL | AWSロゴURL | ❌ |
| `cost_period_days` | コスト取得期間 | `7` | ❌ |

## 🔒 セキュリティ

- IAMロールには最小限の権限のみを付与
  - Lambda実行用: Cost Explorer + CloudWatch Logs
  - EventBridge Scheduler用: Lambda実行権限のみ
- Discord Webhook URLは環境変数で管理
- Lambda実行ログをCloudWatch Logsで監視（3日間保持）
- KMS暗号化を使用せずコスト削減
- GitHub OIDC認証でシークレット不要

## 💰 コスト最適化

このシステムは超低コスト運用を実現：

### コスト要因
- **Lambda実行**: ARM64で従来の20%削減、月間 $0.005未満
- **EventBridge Scheduler**: 月間数回の実行で $0.005未満  
- **CloudWatch Logs**: 短期保持（3日）で $0.005未満
- **Cost Explorer API**: 月間数回の呼び出しで無料

**月間推定コスト: $0.02未満**

### 最適化施策
- ARM64 Lambdaでコスト効率向上
- uv高速パッケージングで実行時間短縮
- ログレベル制御でログ量削減
- 短期ログ保持でストレージコスト削減

## 🏗️ プロジェクト構成

```
aws-cost-notifier-for-discord/
├── .github/
│   ├── actions/                # Composite Actions
│   │   ├── setup/             # Terraform環境セットアップ
│   │   ├── check-no-terraform/ # デプロイスキップ制御
│   │   ├── discord-notify/     # Discord通知
│   │   └── pr-failure-handler/ # PR失敗処理
│   └── workflows/             # GitHub Actions ワークフロー
├── lambda/                    # Lambda関数コード
│   └── lambda_function.py     # メイン関数（Python 3.11）
├── terraform/                 # Terraform設定
│   ├── main.tf               # メインリソース定義
│   ├── variables.tf          # 変数定義
│   ├── outputs.tf            # 出力定義
│   └── terraform.tfvars.example # 変数サンプル
├── pyproject.toml            # Python依存関係管理
├── uv.lock                   # ロックファイル
├── README.md                 # このファイル
├── CLAUDE.md                 # 開発者向け詳細ドキュメント
└── no_terraform.txt          # デプロイスキップ制御
```

## 🐛 トラブルシューティング

### よくある問題

1. **Cost Explorer APIエラー**
   - Cost Explorer APIは `us-east-1` でアクセス必要
   - Lambda関数は別リージョンでも問題なし

2. **Discord通知が届かない**
   - Webhook URLの形式確認: `https://discord.com/api/webhooks/{id}/{token}`
   - Lambda関数のCloudWatch Logsで詳細確認

3. **EventBridge Scheduler実行エラー**  
   - JST時刻設定確認: `Asia/Tokyo` タイムゾーン
   - スケジュール式確認: cron形式

4. **ARM64パッケージエラー**
   - `aarch64-manylinux2014` プラットフォーム指定確認
   - pyproject.toml の setuptools 設定確認

5. **GitHub Actions失敗**
   - AWS OIDC IAMロール設定確認
   - Terraform State S3バケット権限確認

### ログの確認方法

```bash
# Lambda実行ログ
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/aws-cost-notifier"
aws logs tail /aws/lambda/aws-cost-notifier-lambda-prod --follow

# EventBridge Scheduler実行履歴
aws scheduler get-schedule \
  --name aws-cost-notification-schedule-prod \
  --group-name aws-cost-notification-group-prod

# Terraform State確認
terraform show
terraform output
```

## 🔧 高度な設定

### 複数環境対応

```bash
# 開発環境
terraform workspace new dev
terraform apply -var-file="dev.tfvars"

# 本番環境  
terraform workspace new prod
terraform apply -var-file="prod.tfvars"
```

### カスタム通知の実装

Lambda関数 `lambda/lambda_function.py` の Discord関連関数を編集：

- `create_discord_embed()`: 埋め込みメッセージのカスタマイズ
- `format_cost_message()`: コスト表示形式の変更
- `post_to_discord()`: 送信ロジックの変更

## 📚 参考資料

- [AWS Cost Explorer API](https://docs.aws.amazon.com/cost-explorer/)
- [Discord Webhooks](https://discord.com/developers/docs/resources/webhook)
- [Terraform AWS Provider v6.0](https://registry.terraform.io/providers/hashicorp/aws/)
- [EventBridge Scheduler](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-create-schedule.html)
- [uv Package Manager](https://docs.astral.sh/uv/)
- [AWS Lambda ARM64](https://docs.aws.amazon.com/lambda/latest/dg/foundation-arch.html)

## 🤝 コントリビューション

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### 開発環境セットアップ

```bash
# uv環境セットアップ
uv venv
source .venv/bin/activate  # Linux/macOS
# .venv\Scripts\activate   # Windows

# 依存関係インストール
uv sync
```

## 📄 ライセンス

このプロジェクトは MIT License の下で公開されています。詳細は [LICENSE](LICENSE) ファイルをご覧ください。

---

⚡ **Generated with Terraform, uv & Claude Code**  
🏗️ **Architecture: EventBridge Scheduler + Lambda ARM64 + Cost Explorer API**  
🚀 **CI/CD: GitHub Actions + AWS OIDC**