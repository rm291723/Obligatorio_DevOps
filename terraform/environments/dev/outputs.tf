output "vpc_id" {
  description = "ID de la VPC"
  value       = module.vpc.vpc_id
}

output "cluster_name" {
  description = "Nombre del cluster ECS"
  value       = module.ecs.cluster_name
}

output "ecr_repository_urls" {
  description = "URLs de los repositorios ECR"
  value       = module.ecr.repository_urls
}
