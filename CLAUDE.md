# CLAUDE.md

## Project Configuration

このファイルは AWS Cost Notifier for Discord プロジェクト専用の Claude 設定なのだず。

## Project Context

- **プロジェクト名**: AWS Cost Notifier for Discord
- **目的**: AWS のコストを定期的に取得して Discord に Webhook で通知するサーバレスシステム
- **技術スタック**: AWS Lambda (ARM64, Python 3.11), EventBridge Scheduler, Terraform, uv パッケージマネージャー
- **アーキテクチャ**: サーバレス、Infrastructure as Code (IaC)

## Development Guidelines

### Terraform Development

- **プロバイダー**: AWS Provider v6.0, null provider v3.0
- **Backend**: ローカル状態管理（S3バックエンドはコメントアウト済み）
- **ベストプラクティス**: AWS Terraform Provider v6.0 に準拠
- **セキュリティファースト**:
  - IAM ロールは最小権限の原則
  - CloudWatch Logs は 3 日間保持でコスト削減
  - KMS 暗号化は不使用でコスト削減
- **検証プロセス**: `terraform init` → `terraform validate` → `terraform fmt` → `terraform plan`
- **EventBridge Scheduler**: JST タイムゾーン対応の定期実行

### Lambda Development

- **Runtime**: Python 3.11 ARM64 アーキテクチャでコスト効率化
- **Dependencies**: discord.py + aiohttp の組み合わせで Discord 通知
- **AWS SDK**: boto3 で Cost Explorer API アクセス（us-east-1 固定）
- **エラーハンドリング**: 包括的な例外キャッチとログ出力
- **環境変数**: LOG_LEVEL で動的ログレベル制御
- **イベント**: EventBridge からの設定値を動的受け取り
- **パッケージング**: uv + null_resource でのローカル実行パッケージング

### Package Management

- **uv**: Rust 製高速 Python パッケージマネージャー
- **pyproject.toml**: 依存関係とプロジェクト設定を管理
- **Dependencies**: 
  - boto3>=1.34.0 (AWS SDK)
  - discord.py>=2.4.0 (Discord API)
- **Lambda パッケージング**: ARM64 aarch64-manylinux2014 ターゲットでビルド
- **ロックファイル**: uv.lock による厳密なバージョン管理

### Code Style

- **Python**: PEP 8 準拠、詳細な docstring
- **Terraform**: HashiCorp 公式スタイルガイド準拠
- **変数命名**: snake_case 使用
- **コメント**: 特別に指示された場合のみ追加

## Security Requirements

### 必須セキュリティ設定

- [x] IAM ロールの最小権限設定
  - Lambda: Cost Explorer + Logs アクセス
  - EventBridge Scheduler: Lambda Invoke 権限のみ
- [x] Discord Webhook URL の機密変数管理
- [x] CloudWatch Logs での監査ログ（3 日間保持）
- [x] KMS 暗号化を使用せずコスト削減
- [x] EventBridge Scheduler 専用 IAM ロール分離

## Architecture Overview

### 現在のアーキテクチャ

```
EventBridge Scheduler (JST) → Lambda Function (ARM64 Python 3.11) → Cost Explorer API
        ↓                                   ↓
Schedule Group                    Discord Webhook Notification
        ↓                                   ↓
CloudWatch Logs (3d)              Discord Channel (Embed)
```

### AWS サービス構成

- **EventBridge Scheduler**: 
  - JST タイムゾーン設定（Asia/Tokyo）
  - Schedule Group による論理管理
  - 設定値の動的渡し（webhookUrl, budget など）
- **Lambda Function**: 
  - Python 3.11 ARM64 ランタイム
  - 128MB メモリ、30 秒タイムアウト
  - uv パッケージング済み依存関係
- **IAM Roles**: 
  - Lambda 実行用ロール（Cost Explorer + CloudWatch Logs）
  - EventBridge Scheduler 用ロール（Lambda Invoke 権限）
- **CloudWatch Logs**: 3 日間保持設定

## Environment Variables

### Terraform Variables

| 変数名                | 説明                     | デフォルト                    | 必須 | バリデーション              |
| --------------------- | ------------------------ | ----------------------------- | ---- | --------------------------- |
| `aws_region`          | AWS リージョン           | `ap-northeast-1`              | ✅   | -                           |
| `environment`         | 環境名                   | `dev`                         | ✅   | dev, prod のみ              |
| `webhook_url`         | Discord Webhook URL      | -                             | ✅   | Discord URL 形式            |
| `schedule_expression` | EventBridge スケジュール | `cron(0 0 * * ? *)`           | ❌   | rate/cron 形式              |
| `log_level`           | Python ログレベル        | `ERROR`                       | ❌   | 標準ログレベル              |
| `webhook_username`    | Discord ユーザー名       | `AWS Notifier`                | ❌   | -                           |
| `webhook_avatar_url`  | アバター画像 URL         | AWS Cloud ロゴ URL            | ❌   | -                           |
| `cost_period_days`    | コスト取得期間           | `1`                           | ❌   | 1-30 日                     |
| `budget`              | 月次予算額（USD）        | `1`                           | ❌   | $1-9999                     |

### Lambda 環境変数

| 変数名     | 説明           | 設定方法           |
| ---------- | -------------- | ------------------ |
| `LOG_LEVEL` | ログレベル     | Terraform変数から  |

### 使用可能なログレベル

- `DEBUG` - 詳細なデバッグ情報
- `INFO` - 一般的な情報  
- `WARNING` - 警告メッセージ
- `ERROR` - エラーメッセージのみ（デフォルト）
- `CRITICAL` - 重大なエラーのみ

## EventBridge Scheduler Configuration

### スケジュール設定

- **タイムゾーン**: Asia/Tokyo (JST)
- **デフォルト実行時間**: 毎日 9:00 AM JST (cron: `0 0 * * ? *` = UTC 0:00)
- **柔軟実行**: 無効 (正確な時間で実行)
- **状態**: 有効
- **設定値渡し**: JSON 形式で Lambda に設定値を動的渡し

### スケジュールグループ

- **名前**: `aws-cost-notification-group-{environment}`
- **用途**: 関連スケジュールの論理グループ管理
- **タグ**: プロジェクト識別用

## Lambda Function Details

### 主要機能

1. **設定値取得**: EventBridge イベントから動的設定値を取得
2. **コスト取得**: Cost Explorer API で日次・月次コストを取得
3. **Discord 通知**: aiohttp + discord.py で Embed 形式通知
4. **エラーハンドリング**: 包括的な例外処理とログ出力

### 設定値フロー

```
EventBridge Event → Lambda Handler → Config Extraction → Cost Retrieval → Discord Notification
```

### Discord Embed 通知内容

- **タイトル**: AWS料金通知 💰
- **期間表示**: 指定期間の料金情報
- **日次コスト**: 期間と料金表示  
- **月次コスト**: 予算と消化率計算
- **先月コスト**: 期間跨ぎ時の比較情報

## Project Structure

```
aws-cost-notifier-for-discord/
├── lambda/
│   └── lambda_function.py        # メイン Lambda 関数
├── terraform/
│   ├── main.tf                   # メインリソース定義
│   ├── variables.tf              # 変数定義
│   ├── outputs.tf                # 出力定義
│   ├── terraform.tfvars.example  # 変数サンプル
│   ├── lambda_package.zip        # パッケージ済み依存関係（生成）
│   └── lambda_package/           # 依存関係ディレクトリ（生成）
├── pyproject.toml               # Python プロジェクト設定
├── uv.lock                      # 依存関係ロックファイル
├── CLAUDE.md                    # このファイル
├── .github/
│   └── README.md                # GitHub 用 README
└── no_terraform.txt             # デプロイスキップ制御
```

## Deployment Process

### ローカルデプロイ手順

1. **環境準備**
   ```bash
   # uv インストール（未インストールの場合）
   curl -LsSf https://astral.sh/uv/install.sh | sh
   
   # プロジェクトのセットアップ
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # terraform.tfvars を実際の値に編集
   ```

2. **Terraform 実行**
   ```bash
   # 初期化
   terraform init
   
   # 検証
   terraform validate
   terraform fmt
   
   # プラン確認
   terraform plan
   
   # デプロイ実行
   terraform apply
   ```

3. **デプロイ時の処理フロー**
   ```
   terraform apply
   ↓
   null_resource.lambda_dependencies (local-exec)
   ↓
   uv pip install (ARM64 パッケージング)
   ↓
   lambda_package.zip 生成
   ↓
   AWS Lambda 関数デプロイ
   ```

## Monitoring & Alerting

- **CloudWatch Logs**: Lambda 実行ログの監視（3 日間保持）
- **EventBridge Scheduler**: 実行履歴とエラー監視
- **Discord 通知**: 成功/失敗の通知機能内蔵
- **Lambda メトリクス**: 実行時間、エラー率、実行回数

## Cost Optimization

- **CloudWatch Logs**: 3 日間保持でログコスト削減
- **Lambda**: ARM64 アーキテクチャ使用で約 20% コスト削減
- **ログレベル**: ERROR 以上でログ量削減
- **EventBridge Scheduler**: 必要最小限の実行頻度
- **デプロイ**: uv による高速で効率的なパッケージング
- **KMS**: 暗号化を使用せずコスト削減
- **メモリ**: 128MB 最小設定

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

## Testing Strategy

### ローカルテスト

Lambda 関数には直接実行可能なテストコードが含まれている:

```bash
cd lambda
python lambda_function.py
```

### 本番環境でのテスト

- Lambda 関数の手動実行でテスト
- CloudWatch Logs でログ確認
- EventBridge Scheduler の実行履歴確認

## Common Issues & Solutions

### Cost Explorer API エラー

- **問題**: Cost Explorer API へのアクセスエラー
- **解決**: Cost Explorer API は us-east-1 リージョン固定

### Discord 通知が届かない

- **問題**: 通知が送信されない
- **解決**: Webhook URL の確認、Lambda 関数のログ確認

### uv パッケージングエラー

- **問題**: ARM64 パッケージのビルドエラー
- **解決**: `aarch64-manylinux2014` プラットフォーム指定を確認

### EventBridge Scheduler タイムゾーン

- **問題**: UTC で実行される
- **解決**: `schedule_expression_timezone = "Asia/Tokyo"` が設定されているか確認

### Terraform 依存関係エラー

- **問題**: Lambda パッケージの更新が反映されない
- **解決**: `terraform apply -replace="null_resource.lambda_dependencies"`

## Important Files

### 必須設定ファイル

- `terraform/terraform.tfvars` (要作成): 実際の設定値
- `lambda/lambda_function.py`: Lambda 関数本体
- `pyproject.toml`: 依存関係定義

### 生成ファイル（編集禁止）

- `terraform/lambda_package.zip`: パッケージ済み依存関係
- `terraform/lambda_package/`: 依存関係展開ディレクトリ
- `uv.lock`: 依存関係ロック

## Documentation Updates

このファイルは以下の場合に更新してください:

- 新しい AWS リソースの追加
- セキュリティ要件の変更  
- Lambda 関数の機能変更
- 新しい環境変数の追加
- 依存関係の変更

---

**最終更新**: 2025年9月  
**プロジェクトバージョン**: 1.0.0  
**Terraform 版**: >= 1.12.2  
**AWS Provider 版**: ~> 6.0  
**Python**: 3.11 (ARM64)  
**パッケージマネージャー**: uv