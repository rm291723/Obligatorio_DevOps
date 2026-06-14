data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../../../lambda/security-notifier"
  output_path = "${path.module}/security-notifier.zip"
}

resource "aws_lambda_function" "security_notifier" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-security-notifier-${var.environment}"
  role             = "arn:aws:iam::${var.aws_account_id}:role/LabRole"
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30

  tracing_config {
    mode = "Active"
  }

  # nosemgrep: aws-lambda-environment-unencrypted
  environment {
    variables = {
      LOG_GROUP = "/retailstore/security/vulnerabilities"
    }
  }

  tags = {
    Name        = "${var.project_name}-security-notifier-${var.environment}"
    Environment = var.environment
  }
}

# nosemgrep: aws-cloudwatch-log-group-unencrypted
resource "aws_cloudwatch_log_group" "security_vulnerabilities" {
  name              = "/retailstore/security/vulnerabilities"
  retention_in_days = 30

  tags = {
    Name        = "retailstore-security-vulnerabilities"
    Environment = var.environment
  }
}
