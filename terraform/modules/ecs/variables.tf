variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, test, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "subnet_ids" {
  description = "IDs de las subnets"
  type        = list(string)
}

variable "aws_account_id" {
  description = "ID de la cuenta AWS"
  type        = string
}

variable "aws_region" {
  description = "Region de AWS"
  type        = string
}

variable "ecr_registry" {
  description = "URL del registro ECR"
  type        = string
}

variable "services" {
  description = "Mapa de servicios con su configuracion"
  type = map(object({
    cpu           = number
    memory        = number
    desired_count = number
    environment_vars = list(object({
      name  = string
      value = string
    }))
  }))
}
