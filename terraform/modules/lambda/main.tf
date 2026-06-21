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
  depends_on  = [local_file.dummy_handler]
}

# 3. Lambda security-notifier
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

# 4. Security group para Lambda db-initializer
resource "aws_security_group" "lambda_db_init" {
  name        = "${var.project_name}-lambda-db-init-sg-${var.environment}"
  description = "Security group para Lambda db-initializer"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-lambda-db-init-sg-${var.environment}"
    Environment = var.environment
  }
}

# 5. Lambda db-initializer
resource "aws_lambda_function" "db_initializer" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-db-initializer-${var.environment}"
  role             = "arn:aws:iam::${var.aws_account_id}:role/LabRole"
  handler          = "db_init.handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 60
  layers           = ["arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p312-psycopg2-binary:1"]

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_db_init.id]
  }

  # nosemgrep: aws-lambda-environment-unencrypted
  environment {
    variables = {
      DB_HOST     = split(":", var.db_endpoint)[0]
      DB_PORT     = "5432"
      DB_USERNAME = var.db_username
      DB_PASSWORD = var.db_password
      ENVIRONMENT = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-db-initializer-${var.environment}"
    Environment = var.environment
  }
}
