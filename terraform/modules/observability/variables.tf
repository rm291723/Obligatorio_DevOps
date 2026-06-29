variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, test, prod)"
  type        = string
}

variable "aws_region" {
  description = "Región AWS"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix del ALB (output del módulo alb)"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Nombre del cluster ECS (output del módulo ecs)"
  type        = string
}

variable "rds_instance_id" {
  description = "Identificador de la instancia RDS"
  type        = string
}

variable "services" {
  description = "Lista de microservicios a monitorear"
  type        = list(string)
}
