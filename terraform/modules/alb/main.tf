# Security Group para el ALB (Abierto a internet en el puerto 80)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg-${var.environment}"
  description = "Security group para el Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-sg-${var.environment}"
    Environment = var.environment
  }
}

# nosemgrep: terraform.aws.security.aws-elb-access-logs-not-enabled.aws-elb-access-logs-not-enabled
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids # Recibe las subnets públicas de la VPC

  tags = {
    Name        = "${var.project_name}-alb-${var.environment}"
    Environment = var.environment
  }
}

# Target Group base (Apunta a IP porque Fargate usa modo de red awsvpc)
resource "aws_lb_target_group" "services" {
  for_each    = toset(var.service_names)
  name        = "${var.project_name}-${each.key}-tg-${var.environment}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # OBLIGATORIO para ECS Fargate

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/" # Ajusta la ruta de healthcheck de RetailStore si es necesario
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-${each.value}-tg-${var.environment}"
    Environment = var.environment
  }
}

# nosemgrep: terraform.aws.security.insecure-load-balancer-tls-version.insecure-load-balancer-tls-version
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Por defecto da un error fijo si no machea ninguna regla de microservicio
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Servicio no encontrado en RetailStore"
      status_code  = "404"
    }
  }
}

# Reglas de enrutamiento basadas en rutas (Path-based routing) para tus microservicios
resource "aws_lb_listener_rule" "services" {
  for_each     = toset(var.service_names)
  listener_arn = aws_lb_listener.http.arn

  # CORRECCIÓN AQUÍ: Usamos tolist y each.key para que no rompa la prioridad del ALB
  priority = index(tolist(var.service_names), each.key) + 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }

  condition {
    path_pattern {
      values = ["/${each.key}/*", "/${each.key}"]
    }
  }
}
