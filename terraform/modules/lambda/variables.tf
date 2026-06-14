variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, test, prod)"
  type        = string
}

variable "aws_account_id" {
  description = "ID de la cuenta AWS"
  type        = string
}

variable "aws_region" {
  description = "Region de AWS"
  type        = string
}
