# CLAUDE.md

## Project Configuration

このファイルは AWS Cost Notifier for Discord プロジェクト専用のClaude設定です。

## Project Context

- **プロジェクト名**: AWS Cost Notifier for Discord
- **目的**: 定期的にAWSのコストを取得してDiscordにWebhookで通知するサーバレスシステム
- **技術スタック**: AWS Lambda, EventBridge, Terraform, Python 3.11
- **アーキテクチャ**: サーバレス、Infrastructure as Code (IaC)

## Development Guidelines

### Terraform Development

- **ベストプラクティスに従う**: AWS Terraform Provider Best Practicesを参照
- **セキュリティファースト**: 
  - KMS暗号化を優先
  - IAMロールは最小権限の原則
  - S3バケットはpublicアクセスブロック必須
- **プロバイダー優先順位**:
  1. AWSCC provider (推奨)
  2. AWS provider (フォールバック)
- **検証プロセス**: `terraform validate` → `checkov scan` → `terraform plan`

### Lambda Development

- **Python 3.11** を使用
- **ログレベル**: INFO以上
- **エラーハンドリング**: すべての例外をキャッチして適切にログ出力
- **環境変数**: センシティブな値は環境変数から取得
- **Cost Explorer API**: 必ずus-east-1リージョンを使用

### Code Style

- **Python**: PEP 8準拠
- **Terraform**: HashiCorp公式スタイルガイド準拠
- **コメント**: 特別に指示された場合のみ追加
- **変数命名**: snake_case使用

## Security Requirements

### 必須セキュリティ設定

- [ ] S3バケットのKMS暗号化
- [ ] S3バケットのpublic access block
- [ ] IAMロールの最小権限設定
- [ ] Discord Webhook URLの環境変数管理
- [ ] CloudWatch Logsでの監査ログ

### セキュリティスキャン

- Checkovを使用してTerraformコードをスキャン
- 重要度HIGHの問題は必ず修正
- MEDIUMレベルも可能な限り対応

## File Structure

```
aws-cost-notifier-for-discord/
├── lambda/
│   └── lambda_function.py          # Lambda関数のメインコード
├── terraform/
│   ├── main.tf                     # メインのTerraform設定
│   ├── variables.tf                # 変数定義
│   ├── outputs.tf                  # 出力値定義
│   ├── terraform.tfvars.example    # 設定ファイルの例
│   └── terraform.tfvars            # 実際の設定 (gitignore対象)
├── generated-diagrams/             # 自動生成されたアーキテクチャ図
├── README.md                       # プロジェクトドキュメント
└── CLAUDE.md                       # このファイル
```

## Deployment Process

### 推奨デプロイ手順

1. **準備**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # terraform.tfvarsを編集
   ```

2. **検証**
   ```bash
   terraform init
   terraform validate
   checkov -f main.tf
   ```

3. **デプロイ**
   ```bash
   terraform plan
   terraform apply
   ```

## Testing Strategy

### ローカルテスト
- Lambda関数は環境変数を設定して直接実行可能
- テスト用のWebhook URLを使用

### AWS環境テスト
- Lambda関数の手動実行でテスト
- CloudWatch Logsでログ確認

## Monitoring & Alerting

- **CloudWatch Logs**: Lambda実行ログの監視
- **Lambda Errors**: エラー発生時のアラート推奨
- **Cost Explorer API**: APIクォータ監視

## Environment Variables

### Lambda Function

| 変数名 | 説明 | 必須 |
|--------|------|------|
| `DISCORD_WEBHOOK_URL` | Discord Webhook URL | ✅ |

### Terraform Variables

| 変数名 | 説明 | デフォルト | 必須 |
|--------|------|-----------|------|
| `aws_region` | AWSリージョン | `us-east-1` | ✅ |
| `environment` | 環境名 | `dev` | ✅ |
| `discord_webhook_url` | Discord Webhook URL | - | ✅ |
| `schedule_expression` | 実行スケジュール | `cron(0 9 * * ? *)` | ❌ |

## Common Issues & Solutions

### Cost Explorer API エラー
- **問題**: Cost Explorer APIへのアクセスエラー
- **解決**: リージョンがus-east-1に設定されているか確認

### Discord通知が届かない
- **問題**: 通知が送信されない
- **解決**: Webhook URLの確認、Lambda関数のログ確認

### Terraform Plan失敗
- **問題**: AWS認証エラー
- **解決**: AWS CLIの認証設定確認

## Resource Naming Convention

- **Prefix**: `aws-cost-notifier-`
- **Environment suffix**: `-${var.environment}`
- **Example**: `aws-cost-notifier-lambda-role-dev`

## Tags Strategy

すべてのリソースに以下のタグを適用:

```hcl
tags = {
  Project     = "aws-cost-notifier-for-discord"
  Environment = var.environment
  ManagedBy   = "Terraform"
}
```

## Cost Optimization

- **S3ライフサイクル**: 30日後削除、バージョンは7日後削除
- **Lambda**: ARM64アーキテクチャ使用
- **KMS**: バケットキー有効化でコスト削減
- **EventBridge**: 必要最小限の実行頻度

## Documentation Updates

このファイルは以下の場合に更新してください:
- 新しいAWSリソースの追加
- セキュリティ要件の変更
- デプロイメントプロセスの変更
- 新しい環境変数の追加

---

**最終更新**: 2024年1月
**プロジェクトバージョン**: 1.0
**Terraform版**: >= 1.0
**AWS Provider版**: ~> 5.0