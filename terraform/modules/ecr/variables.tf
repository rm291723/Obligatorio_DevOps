variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, test, prod)"
  type        = string
}

variable "services" {
  description = "Lista de microservicios"
  type        = list(string)
}
