output "alb_dns_name" {
  description = "URL publica para entrar a RetailStore"
  value       = aws_lb.main.dns_name
}

output "target_group_arns" {
  description = "Mapeo de ARNs de Target Groups para conectar con el modulo de ECS"
  value       = { for k, v in aws_lb_target_group.services : k => v.arn }
}

output "alb_security_group_id" {
  description = "ID del SG del ALB para securizar el ECS"
  value       = aws_security_group.alb.id
}

output "alb_arn_suffix" {
  description = "ARN suffix del ALB para usar en métricas de CloudWatch"
  value       = aws_lb.main.arn_suffix
}
