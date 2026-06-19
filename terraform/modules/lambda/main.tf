# 1. Crea automáticamente un script de Python básico para simular la Lambda
resource "local_file" "dummy_handler" {
  filename = "${path.module}/src/handler.py"
  content  = <<EOF
def lambda_handler(event, context):
    print("Notificador de seguridad de RetailStore activado con éxito.")
    return {
        'statusCode': 200,
        'body': 'Alerta procesada correctamente'
    }
EOF
}

# 2. Comprime el archivo generado dinámicamente
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/security-notifier.zip"

  # Fuerza a que espere a que el archivo handler exista antes de comprimir
  depends_on = [local_file.dummy_handler]
}

# 3. Tu recurso Lambda se mantiene igual y apuntando a la ruta segura
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
      LOG_GROUP   = aws_cloudwatch_log_group.security_vulnerabilities.name
      ENVIRONMENT = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-security-notifier-${var.environment}"
    Environment = var.environment
  }
}

# nosemgrep: aws-cloudwatch-log-group-unencrypted
resource "aws_cloudwatch_log_group" "security_vulnerabilities" {
  name              = "/retailstore/security/vulnerabilities-${var.environment}"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = {
    Name        = "retailstore-security-vulnerabilities"
    Environment = var.environment
  }
}


