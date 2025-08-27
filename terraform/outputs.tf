# AWS Cost Notifier for Discord - 出力定義

output "lambda_function_name" {
  description = "Lambda関数名"
  value       = awscc_lambda_function.cost_notifier.function_name
}

output "lambda_function_arn" {
  description = "Lambda関数ARN"
  value       = awscc_lambda_function.cost_notifier.arn
}

output "eventbridge_rule_name" {
  description = "EventBridgeルール名"
  value       = aws_cloudwatch_event_rule.cost_notification_schedule.name
}

output "eventbridge_rule_arn" {
  description = "EventBridgeルールARN"
  value       = aws_cloudwatch_event_rule.cost_notification_schedule.arn
}

output "s3_bucket_name" {
  description = "Lambda資産用S3バケット名"
  value       = aws_s3_bucket.lambda_assets.bucket
}

output "iam_role_arn" {
  description = "Lambda用IAMロールARN"
  value       = awscc_iam_role.lambda_role.arn
}