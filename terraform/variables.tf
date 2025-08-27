# AWS Cost Notifier for Discord - 変数定義

variable "aws_region" {
  description = "リソースをデプロイするAWSリージョン"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "環境名 (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "環境は dev, staging, prod のいずれかである必要があります。"
  }
}

variable "discord_webhook_url" {
  description = "通知送信用Discord Webhook URL"
  type        = string
  sensitive   = true
}

variable "schedule_expression" {
  description = "料金通知用EventBridgeスケジュール式"
  type        = string
  default     = "cron(0 9 * * ? *)"  # 毎日UTC 9:00 AM
  
  validation {
    condition     = can(regex("^(rate\\(.*\\)|cron\\(.*\\))$", var.schedule_expression))
    error_message = "スケジュール式は有効なEventBridge rate または cron 式である必要があります。"
  }
}