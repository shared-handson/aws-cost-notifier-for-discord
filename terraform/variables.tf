# AWS Cost Notifier for Discord - 変数定義

variable "aws_region" {
  description = "リソースをデプロイするAWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "環境名 (dev, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "環境は dev, prod のいずれかである必要があります。"
  }
}

variable "schedule_expression" {
  description = "料金通知用EventBridgeスケジュール式"
  type        = string
  default     = "cron(0 0 * * ? *)" # 毎日 JST 9:00 AM（UTC 0:00）

  validation {
    condition     = can(regex("^(rate\\(.*\\)|cron\\(.*\\))$", var.schedule_expression))
    error_message = "スケジュール式は有効なEventBridge rate または cron 式である必要があります。"
  }
}

variable "log_level" {
  description = "Lambda関数のPythonログレベル"
  type        = string
  default     = "ERROR"

  validation {
    condition = contains(
      ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
      var.log_level
    )
    error_message = "ログレベルは DEBUG, INFO, WARNING, ERROR, CRITICAL のいずれかである必要があります。"
  }
}

variable "webhook_url" {
  description = "通知送信用Discord Webhook URL"
  type        = string
  sensitive   = true
}

variable "webhook_username" {
  description = "Discord Webhook用のユーザー名"
  type        = string
  default     = "AWS Notifier"
}

variable "webhook_avatar_url" {
  description = "Discord Webhook用のアバター画像URL"
  type        = string
  default     = "https://shared-handson.github.io/icons-factory/aws/Cloud-logo.png"
}

variable "cost_period_days" {
  description = "コスト取得期間の日数（1-90日、省略時は7日）"
  type        = number
  default     = 7

  validation {
    condition     = var.cost_period_days == null || (var.cost_period_days >= 1 && var.cost_period_days <= 90)
    error_message = "コスト取得期間は1日から90日の範囲で指定してください。"
  }
}
