# AWS Cost Notifier for Discord - 出力定義

output "lambda_function_name" {
  description = "Lambda関数名"
  value       = aws_lambda_function.cost_notifier.function_name
}

output "lambda_function_arn" {
  description = "Lambda関数ARN"
  value       = aws_lambda_function.cost_notifier.arn
}

output "scheduler_schedule_name" {
  description = "EventBridge Schedulerスケジュール名"
  value       = aws_scheduler_schedule.cost_notification_schedule.name
}

output "scheduler_schedule_arn" {
  description = "EventBridge SchedulerスケジュールARN"
  value       = aws_scheduler_schedule.cost_notification_schedule.arn
}


output "iam_role_arn" {
  description = "Lambda用IAMロールARN"
  value       = aws_iam_role.lambda_role.arn
}