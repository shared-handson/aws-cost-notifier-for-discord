# AWS Cost Notifier for Discord - メインTerraform設定ファイル

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 0.70"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "aws-cost-notifier-for-discord"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

provider "awscc" {
  region = var.aws_region
}

# データソース
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Lambda関数のソースコードをZIP化
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "../lambda/lambda_function.py"
  output_path = "lambda_function.zip"
}

# Lambdaデプロイメントパッケージ用S3バケット
resource "aws_s3_bucket" "lambda_assets" {
  bucket_prefix = "aws-cost-notifier-lambda-assets-"
}

resource "aws_s3_bucket_versioning" "lambda_assets" {
  bucket = aws_s3_bucket.lambda_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3バケット暗号化用のKMSキー
resource "aws_kms_key" "lambda_assets" {
  description             = "AWS Cost Notifier Lambda assets S3バケット暗号化用KMSキー"
  deletion_window_in_days = 7
  
  tags = {
    Name = "aws-cost-notifier-lambda-assets-key"
  }
}

# KMSキーのエイリアス
resource "aws_kms_alias" "lambda_assets" {
  name          = "alias/aws-cost-notifier-lambda-assets-${var.environment}"
  target_key_id = aws_kms_key.lambda_assets.key_id
}

# S3バケットのサーバーサイド暗号化設定
resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_assets" {
  bucket = aws_s3_bucket.lambda_assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.lambda_assets.arn
    }
    bucket_key_enabled = true
  }
}

# S3バケットのライフサイクル設定（コスト最適化）
resource "aws_s3_bucket_lifecycle_configuration" "lambda_assets" {
  bucket = aws_s3_bucket.lambda_assets.id

  rule {
    id     = "delete_old_versions"
    status = "Enabled"
    
    filter {}

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# S3バケットのパブリックアクセスブロック設定
resource "aws_s3_bucket_public_access_block" "lambda_assets" {
  bucket = aws_s3_bucket.lambda_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# LambdaデプロイメントパッケージをS3にアップロード
resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_assets.id
  key    = "lambda_function.zip"
  source = data.archive_file.lambda_zip.output_path
  etag   = data.archive_file.lambda_zip.output_md5
}

# Lambda関数用IAMロール
resource "awscc_iam_role" "lambda_role" {
  role_name = "aws-cost-notifier-lambda-role-${var.environment}"
  description = "AWS Cost Notifier Lambda関数用IAMロール"
  
  assume_role_policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
  
  policies = [
    {
      policy_name = "CostExplorerAccess"
      policy_document = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "ce:GetCostAndUsage",
              "ce:GetUsageReport"
            ]
            Resource = "*"
          }
        ]
      })
    }
  ]
  
  tags = [
    {
      key   = "Name"
      value = "aws-cost-notifier-lambda-role"
    }
  ]
}

# Lambda関数
resource "awscc_lambda_function" "cost_notifier" {
  function_name = "aws-cost-notifier-${var.environment}"
  description   = "Discord用AWS料金通知Lambda関数"
  
  code = {
    s3_bucket = aws_s3_bucket.lambda_assets.id
    s3_key    = aws_s3_object.lambda_zip.key
  }
  
  package_type  = "Zip"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 256
  role          = awscc_iam_role.lambda_role.arn
  architectures = ["arm64"]
  
  environment = {
    variables = {
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
    }
  }
  
  tags = [
    {
      key   = "Name"
      value = "aws-cost-notifier"
    }
  ]
}

# スケジュール実行用EventBridgeルール
resource "aws_cloudwatch_event_rule" "cost_notification_schedule" {
  name                = "aws-cost-notification-schedule-${var.environment}"
  description         = "AWS料金通知Lambda関数を毎日実行"
  schedule_expression = var.schedule_expression
  state               = "ENABLED"
  
  tags = {
    Name = "aws-cost-notification-schedule"
  }
}

# Lambda関数用EventBridgeターゲット
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.cost_notification_schedule.name
  target_id = "CostNotifierLambdaTarget"
  arn       = awscc_lambda_function.cost_notifier.arn
}

# EventBridgeからLambda関数を実行するための権限
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = awscc_lambda_function.cost_notifier.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cost_notification_schedule.arn
}