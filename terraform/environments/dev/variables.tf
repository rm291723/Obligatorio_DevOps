variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente"
  type        = string
}

variable "aws_region" {
  description = "Region de AWS"
  type        = string
}

variable "aws_account_id" {
  description = "ID de la cuenta AWS"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR de la VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDRs de subnets publicas"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}

variable "ecr_registry" {
  description = "URL del registro ECR"
  type        = string
}

variable "services_list" {
  description = "Lista de microservicios"
  type        = list(string)
}

variable "services" {
  description = "Configuracion de servicios"
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

variable "private_subnet_cidrs" {
  description = "CIDRs de subnets privadas"
  type        = list(string)
}

variable "db_username" {
  description = "Usuario de la base de datos"
  type        = string
}

variable "db_password" {
  description = "Contraseña de la base de datos"
  type        = string
  sensitive   = true
}

