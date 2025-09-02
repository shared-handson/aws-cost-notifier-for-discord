# CLAUDE.md

## Project Configuration

このファイルは AWS Cost Notifier for Discord プロジェクト専用の Claude 設定です。

## Project Context

- **プロジェクト名**: AWS Cost Notifier for Discord
- **目的**: 定期的に AWS のコストを取得して Discord に Webhook で通知するサーバレスシステム
- **技術スタック**: AWS Lambda (ARM64), EventBridge Scheduler, Terraform, Python 3.11, uv パッケージマネージャー
- **アーキテクチャ**: サーバレス、Infrastructure as Code (IaC)、GitHub Actions CI/CD

## Development Guidelines

### Terraform Development

- **ベストプラクティスに従う**: AWS Terraform Provider v6.0 Best Practices を参照
- **セキュリティファースト**:
  - IAM ロールは最小権限の原則
  - CloudWatch Logs はコスト削減のため短期保持
  - KMS 暗号化はコスト削減のため使用しない
- **プロバイダー**: 標準 AWS provider v6.0 のみ使用
- **検証プロセス**: `terraform validate` → `terraform fmt` → `terraform plan`
- **EventBridge Scheduler**: タイムゾーン指定でJST対応

### Lambda Development

- **Python 3.11** を使用
- **ARM64 アーキテクチャ**: コスト効率の良い ARM64 Lambda を使用
- **エラーハンドリング**: すべての例外をキャッチして適切にログ出力
- **環境変数**: センシティブな値は環境変数から取得
- **Cost Explorer API**: 必ず us-east-1 リージョンを使用
- **デプロイ**: uv + pyproject.toml ベースの依存関係管理
- **ログレベル**: 環境変数 `LOG_LEVEL` で動的制御可能

### Package Management

- **uv**: Rust製高速Pythonパッケージマネージャーを使用
- **pyproject.toml**: 依存関係とプロジェクト設定を管理
- **依存関係**: boto3, discord.py の最小構成
- **Lambda パッケージング**: ARM64 manylinux2014 ターゲットでビルド

### Code Style

- **Python**: PEP 8 準拠
- **Terraform**: HashiCorp 公式スタイルガイド準拠
- **コメント**: 特別に指示された場合のみ追加
- **変数命名**: snake_case 使用

## Security Requirements

### 必須セキュリティ設定

- [x] IAM ロールの最小権限設定
- [x] Discord Webhook URL の環境変数管理
- [x] CloudWatch Logs での監査ログ（3 日間保持）
- [x] KMS 暗号化を使用せずコスト削減
- [x] EventBridge Scheduler 専用 IAM ロール

## Deployment Process

### CI/CD Pipeline (GitHub Actions)

#### ワークフロー構成
- **terraform-plan.yml**: PR時の計画確認
- **terraform-apply.yml**: main ブランチへの自動デプロイ
- **terraform-destroy-plan.yml**: 破棄計画の確認
- **terraform-destroy-exec.yml**: リソース破棄実行

#### Composite Actions
- **setup**: Terraform環境のセットアップ
- **check-no-terraform**: デプロイスキップ制御
- **discord-notify**: Discord通知
- **pr-failure-handler**: PR失敗時の処理

#### セキュリティ機能
- AWS OIDC認証 (IAMロール)
- Terraform State の S3 バックエンド
- Discord 通知での自動メンション

### ローカルデプロイ手順

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
   terraform fmt
   ```

3. **デプロイ**
   ```bash
   terraform plan
   terraform apply
   ```

## Testing Strategy

### 本番環境でのテスト

- Lambda 関数の手動実行でテスト
- CloudWatch Logs でログ確認
- EventBridge Scheduler の実行履歴確認

### テスト用設定

- 本番用とは別のテスト用 Discord チャンネルを作成
- テスト用 Webhook URL を terraform.tfvars に設定

## Architecture Overview

### 現在のアーキテクチャ

```
EventBridge Scheduler (JST) → Lambda Function (ARM64) → Cost Explorer API
        ↓                            ↓
Schedule Group              Discord Webhook Notification
```

### AWS サービス構成

- **EventBridge Scheduler**: JST タイムゾーン対応の定期実行
- **EventBridge Scheduler Group**: スケジュール管理の論理グループ
- **Lambda Function**: Python 3.11 ARM64 ランタイム
- **IAM Roles**: 
  - Lambda 実行用ロール (Cost Explorer + Logs アクセス)
  - EventBridge Scheduler 用ロール (Lambda 実行権限)
- **CloudWatch Logs**: 3日間保持設定

## Environment Variables

### Terraform Variables

| 変数名                | 説明                | デフォルト          | 必須 |
| --------------------- | ------------------- | ------------------- | ---- |
| `aws_region`          | AWS リージョン      | `ap-northeast-1`    | ✅   |
| `environment`         | 環境名              | `dev`               | ✅   |
| `webhook_url`         | Discord Webhook URL | -                   | ✅   |
| `schedule_expression` | 実行スケジュール    | `cron(0 9 * * ? *)` | ❌   |
| `log_level`           | Python ログレベル   | `ERROR`             | ❌   |
| `webhook_username`    | Discord ユーザー名  | `AWS Notifier`      | ❌   |
| `webhook_avatar_url`  | アバター画像 URL    | AWS ロゴ URL        | ❌   |
| `cost_period_days`    | コスト取得期間      | `7`                 | ❌   |

### Lambda 環境変数

| 変数名                | 説明                       | 設定方法               |
| --------------------- | -------------------------- | ---------------------- |
| `LOG_LEVEL`           | ログレベル                 | Terraform変数から設定 |

### 使用可能なログレベル

- `DEBUG` - 詳細なデバッグ情報
- `INFO` - 一般的な情報
- `WARNING` - 警告メッセージ  
- `ERROR` - エラーメッセージのみ（デフォルト）
- `CRITICAL` - 重大なエラーのみ

## EventBridge Scheduler Configuration

### スケジュール設定

- **タイムゾーン**: Asia/Tokyo (JST)
- **実行時間**: 毎日 9:00 AM JST (cron: `0 9 * * ? *`)
- **柔軟実行**: 無効 (正確な時間で実行)
- **状態**: 有効

### スケジュールグループ

- **名前**: `aws-cost-notification-group-{environment}`
- **用途**: 関連スケジュールの論理グループ管理
- **タグ**: プロジェクト識別用

## Project Structure

```
aws-cost-notifier-for-discord/
├── .github/
│   ├── actions/                # 共通 Composite Actions
│   │   ├── setup/             # Terraform 環境セットアップ
│   │   ├── check-no-terraform/ # デプロイスキップ制御
│   │   ├── discord-notify/     # Discord 通知
│   │   └── pr-failure-handler/ # PR 失敗処理
│   └── workflows/             # GitHub Actions ワークフロー
├── lambda/                    # Lambda 関数コード
│   └── lambda_function.py     # メイン関数
├── terraform/                 # Terraform 設定
│   ├── main.tf               # メインリソース定義
│   ├── variables.tf          # 変数定義
│   ├── outputs.tf            # 出力定義
│   └── terraform.tfvars.example # 変数サンプル
├── pyproject.toml            # Python プロジェクト設定
├── uv.lock                   # 依存関係ロックファイル
├── README.md                 # プロジェクト説明
├── CLAUDE.md                 # このファイル
└── no_terraform.txt          # デプロイスキップ制御
```

## Monitoring & Alerting

- **CloudWatch Logs**: Lambda 実行ログの監視 (3日間保持)
- **EventBridge Scheduler**: 実行履歴とエラー監視
- **Discord 通知**: 成功/失敗の通知機能内蔵
- **GitHub Actions**: CI/CD パイプラインの監視

## Cost Optimization

- **CloudWatch Logs**: 3 日間保持でコスト削減
- **Lambda**: ARM64 アーキテクチャ使用でコスト効率向上
- **ログレベル**: ERROR 以上でログ量削減
- **EventBridge Scheduler**: 必要最小限の実行頻度
- **デプロイ**: uv による高速で効率的なパッケージング
- **KMS**: 暗号化を使用せずコスト削減

## Resource Naming Convention

- **Prefix**: `aws-cost-notifier-`
- **Environment suffix**: `-${var.environment}`
- **Example**: `aws-cost-notifier-lambda-role-dev`

## Tags Strategy

すべてのリソースに以下のタグを適用:

```hcl
default_tags {
  tags = {
    Project     = "aws-cost-notifier-for-discord"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

## Common Issues & Solutions

### Cost Explorer API エラー

- **問題**: Cost Explorer API へのアクセスエラー
- **解決**: リージョンが us-east-1 に設定されているか確認

### Discord 通知が届かない

- **問題**: 通知が送信されない
- **解決**: Webhook URL の確認、Lambda 関数のログ確認

### Terraform Plan 失敗

- **問題**: AWS 認証エラー
- **解決**: AWS CLI の認証設定確認

### EventBridge Scheduler タイムゾーン

- **問題**: UTC で実行される
- **解決**: `schedule_expression_timezone = "Asia/Tokyo"` が設定されているか確認

### uv パッケージングエラー

- **問題**: ARM64 パッケージのビルドエラー
- **解決**: `aarch64-manylinux2014` プラットフォーム指定を確認

## Documentation Updates

このファイルは以下の場合に更新してください:

- 新しい AWS リソースの追加
- セキュリティ要件の変更
- デプロイメントプロセスの変更
- 新しい環境変数の追加
- GitHub Actions ワークフローの変更

---

**最終更新**: 2025年1月
**プロジェクトバージョン**: 2.0  
**Terraform 版**: >= 1.12.2
**AWS Provider 版**: ~> 6.0
**Python**: 3.11 (ARM64)
**パッケージマネージャー**: uv