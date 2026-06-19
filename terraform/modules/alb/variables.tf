variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, test, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se desplegará el ALB"
  type        = string
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Lista de IDs de las subnets publicas de la VPC"
}

variable "service_names" {
  type        = list(string)
  description = "Lista de nombres de microservicios para armar las rutas y TGs"
}
