output "vpc_id" {
  description = "ID de la VPC"
  value       = module.vpc.vpc_id
}

output "cluster_name" {
  description = "Nombre del cluster ECS"
  value       = module.ecs.cluster_name
}

output "alb_dns_name" {
  description = "URL publica para acceder a la aplicacion en Produccion"
  value       = module.alb.alb_dns_name
}

output "dashboard_url" {
  description = "URL del dashboard de observabilidad en CloudWatch"
  value       = module.observability.dashboard_url
}

output "sns_alerts_arn" {
  description = "ARN del SNS topic para suscribirse a las alertas"
  value       = module.observability.sns_topic_arn
}
