output "lambda_function_name" {
  description = "Nombre de la Lambda function"
  value       = aws_lambda_function.security_notifier.function_name
}

output "lambda_function_arn" {
  description = "ARN de la Lambda function"
  value       = aws_lambda_function.security_notifier.arn
}
