output "repository_urls" {
  description = "URLs de los repositorios ECR"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}
