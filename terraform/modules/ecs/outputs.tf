output "cluster_id" {
  description = "ID del cluster ECS"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "Nombre del cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "security_group_id" {
  description = "ID del security group de ECS"
  value       = aws_security_group.ecs.id
}
