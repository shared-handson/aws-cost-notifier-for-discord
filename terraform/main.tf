# AWS Cost Notifier for Discord - メインTerraform設定ファイル

terraform {
  #backend "s3" {}
  required_version = ">= 1.12.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
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


# データソース
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


# Lambda関数用IAMロール
resource "aws_iam_role" "lambda_role" {
  name        = "aws-cost-notifier-lambda-role-${var.environment}"
  description = "AWS Cost Notifier Lambda Role"

  assume_role_policy = jsonencode({
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

  tags = {
    Name = "aws-cost-notifier-lambda-role"
  }
}

# Lambda基本実行ロールのアタッチ
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Cost Explorer アクセス用のインラインポリシー
resource "aws_iam_role_policy" "cost_explorer_access" {
  name = "CostExplorerAccess"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
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

# Lambda関数（インラインコード版）
resource "aws_lambda_function" "cost_notifier" {
  function_name = "aws-cost-notifier-${var.environment}"
  description   = "Discord用AWS料金通知Lambda関数"

  filename = "${path.module}/lambda_package.zip"

  package_type  = "Zip"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 128
  role          = aws_iam_role.lambda_role.arn
  architectures = ["arm64"]

  environment {
    variables = {
      LOG_LEVEL = var.log_level
    }
  }

  tags = {
    Name = "aws-cost-notifier"
  }
}

# Lambdaパッケージ用のローカル実行（依存関係インストール）
resource "null_resource" "lambda_dependencies" {
  triggers = {
    requirements_hash = filemd5("../pyproject.toml")
    lambda_code_hash  = filemd5("../lambda/lambda_function.py")
  }

  provisioner "local-exec" {
    command = <<-EOT
      # ディレクトリとファイルの準備
      [ -f ${path.module}/lambda_package.zip ] && rm -rf ${path.module}/lambda_package.zip
      [ -d ${path.module}/lambda_package ] && rm -rf ${path.module}/lambda_package
      mkdir ${path.module}/lambda_package
      
      # pyproject.tomlの依存関係をLambdaパッケージディレクトリにインストール
      uv pip install \
        --no-installer-metadata \
        --no-compile-bytecode \
        --python-platform aarch64-manylinux2014 \
        --python 3.11 \
        --target ${path.module}/lambda_package \
        ${path.module}/..

      # Lambda関数コードをコピー
      cp ${path.module}/../lambda/lambda_function.py ${path.module}/lambda_package/

      # ZIP化（依存関係含む）
      cd ${path.module}/lambda_package
      zip -r ../lambda_package.zip ./*
    EOT
  }
}

# EventBridge Schedulerグループ
resource "aws_scheduler_schedule_group" "cost_notification_group" {
  name = "aws-cost-notification-group-${var.environment}"

  tags = {
    Name = "aws-cost-notification-group"
  }
}

# スケジュール実行用EventBridge Scheduler
resource "aws_scheduler_schedule" "cost_notification_schedule" {
  name        = "aws-cost-notification-schedule-${var.environment}"
  group_name  = aws_scheduler_schedule_group.cost_notification_group.name
  description = "AWS料金通知Lambda関数を毎日実行（JST）"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = "Asia/Tokyo"
  state                        = "ENABLED"

  target {
    arn      = aws_lambda_function.cost_notifier.arn
    role_arn = aws_iam_role.eventbridge_scheduler_role.arn

    input = jsonencode({
      detail = {
        webhookUrl       = var.webhook_url
        webhookUsername  = var.webhook_username
        webhookAvatarUrl = var.webhook_avatar_url
        costPeriodDays   = var.cost_period_days
        budget           = var.budget
      }
    })
  }
}

# EventBridge Scheduler用IAMロール
resource "aws_iam_role" "eventbridge_scheduler_role" {
  name = "eventbridge-scheduler-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })
}

# EventBridge SchedulerからLambda関数を実行するためのポリシー
resource "aws_iam_role_policy" "eventbridge_scheduler_lambda_invoke" {
  name = "eventbridge-scheduler-lambda-invoke-${var.environment}"
  role = aws_iam_role.eventbridge_scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.cost_notifier.arn
      }
    ]
  })
}

# CloudWatch Logsグループ（ログ保持期間を短く設定してコスト削減）
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.cost_notifier.function_name}"
  retention_in_days = 3

  tags = {
    Name = "aws-cost-notifier-lambda-logs"
  }
}
