resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster-${var.environment}"

  tags = {
    Name        = "${var.project_name}-cluster-${var.environment}"
    Environment = var.environment
  }
}

# NUEVO: Grupo de logs gestionado explícitamente para evitar fallos del LabRole
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 7
}

resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-ecs-sg-${var.environment}"
  description = "Security group para ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 8080
    to_port   = 8081
    protocol  = "tcp"
    # MEJORA: Ya no expone a internet. Solo recibe tráfico que venga desde el ALB
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ecs-sg-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_ecs_task_definition" "services" {
  for_each                 = var.services
  family                   = "${var.project_name}-${each.key}-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = "arn:aws:iam::${var.aws_account_id}:role/LabRole"
  task_role_arn            = "arn:aws:iam::${var.aws_account_id}:role/LabRole"

  container_definitions = jsonencode([{
    name      = each.key
    image     = "${var.ecr_registry}/${var.project_name}/${each.key}:latest"
    essential = true
    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]
    environment = each.value.environment_vars
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        # MEJORA: Apunta al log group gestionado de arriba para que no falle por permisos
        "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = each.key
      }
    }
  }])

  tags = {
    Name        = "${var.project_name}-${each.key}-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_ecs_service" "services" {
  for_each        = var.services
  name            = "${each.key}-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"

  # NUEVO: Conecta cada microservicio con su respectivo Target Group del ALB
  load_balancer {
    target_group_arn = var.target_group_arns[each.key]
    container_name   = each.key
    container_port   = 8080
  }

  network_configuration {
    subnets         = var.subnet_ids # Pasar aquí las subnets privadas de tu VPC
    security_groups = [aws_security_group.ecs.id]
    # MEJORA: false para que no tengan IP publica. Salen de forma segura por el NAT Gateway
    assign_public_ip = false
  }

  tags = {
    Name        = "${each.key}-${var.environment}"
    Environment = var.environment
  }
}

