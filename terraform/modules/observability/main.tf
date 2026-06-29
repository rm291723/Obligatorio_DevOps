# ─────────────────────────────────────────────
# SNS Topic para notificaciones de alertas
# ─────────────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts-${var.environment}"

  tags = {
    Name        = "${var.project_name}-alerts-${var.environment}"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────────
# ALERTA 1 — Errores 5XX en el ALB
# Cubre: disponibilidad y rendimiento
# ─────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-alb-5xx-${var.environment}"
  alarm_description   = "Tasa de errores 5XX en el ALB supera el umbral. Posible falla en uno o más microservicios."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-alb-5xx-${var.environment}"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────────
# ALERTA 2 — CPU alta en el cluster ECS
# Cubre: uso de recursos y rendimiento
# ─────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.project_name}-ecs-cpu-high-${var.environment}"
  alarm_description   = "CPU promedio del cluster ECS supera el 80%. Evaluar escalado horizontal."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-ecs-cpu-high-${var.environment}"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────────
# ALERTA 3 (bonus) — Espacio libre en RDS
# Cubre: seguridad operacional de datos
# ─────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "${var.project_name}-rds-storage-low-${var.environment}"
  alarm_description   = "Espacio libre en RDS inferior a 2 GB. Riesgo de pérdida de datos por disco lleno."
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2147483648 # 2 GB en bytes
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-rds-storage-low-${var.environment}"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────────
# DASHBOARD CloudWatch — RetailStore
# ─────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [

      # ── Fila 1: Título ──────────────────────────────────────────────
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# RetailStore — Dashboard Operacional (${upper(var.environment)})\nMétricas de infraestructura y aplicación en tiempo real."
        }
      },

      # ── Fila 2: ALB — Requests y latencia ───────────────────────────
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "ALB — Requests por minuto"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [[
            "AWS/ApplicationELB", "RequestCount",
            "LoadBalancer", var.alb_arn_suffix,
            { stat = "Sum", period = 60, label = "Total Requests" }
          ]]
          yAxis = { left = { min = 0 } }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "ALB — Latencia de respuesta (p95)"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [[
            "AWS/ApplicationELB", "TargetResponseTime",
            "LoadBalancer", var.alb_arn_suffix,
            { stat = "p95", period = 60, label = "Latencia p95 (s)" }
          ]]
          yAxis = { left = { min = 0 } }
        }
      },

      # ── Fila 3: ALB — Errores ───────────────────────────────────────
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "ALB — Errores 5XX (aplicación)"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [[
            "AWS/ApplicationELB", "HTTPCode_Target_5XX_Count",
            "LoadBalancer", var.alb_arn_suffix,
            { stat = "Sum", period = 60, color = "#d62728", label = "5XX Errors" }
          ]]
          yAxis = { left = { min = 0 } }
          annotations = {
            horizontal = [{ value = 10, label = "Umbral alerta", color = "#ff0000" }]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "ALB — Hosts saludables por servicio"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            for svc in var.services : [
              "AWS/ApplicationELB", "HealthyHostCount",
              "TargetGroup", "targetgroup/${var.project_name}-${svc}-tg-${var.environment}",
              "LoadBalancer", var.alb_arn_suffix,
              { stat = "Average", period = 60, label = svc }
            ]
          ]
        }
      },

      # ── Fila 4: ECS — CPU y Memoria ─────────────────────────────────
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 12
        height = 6
        properties = {
          title  = "ECS — CPU por servicio (%)"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            for svc in var.services : [
              "AWS/ECS", "CPUUtilization",
              "ClusterName", var.ecs_cluster_name,
              "ServiceName", "${svc}-${var.environment}",
              { stat = "Average", period = 60, label = svc }
            ]
          ]
          annotations = {
            horizontal = [{ value = 80, label = "Umbral alerta", color = "#ff0000" }]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 14
        width  = 12
        height = 6
        properties = {
          title  = "ECS — Memoria por servicio (%)"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            for svc in var.services : [
              "AWS/ECS", "MemoryUtilization",
              "ClusterName", var.ecs_cluster_name,
              "ServiceName", "${svc}-${var.environment}",
              { stat = "Average", period = 60, label = svc }
            ]
          ]
        }
      },

      # ── Fila 5: RDS ─────────────────────────────────────────────────
      {
        type   = "metric"
        x      = 0
        y      = 20
        width  = 8
        height = 6
        properties = {
          title  = "RDS — CPU (%)"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [[
            "AWS/RDS", "CPUUtilization",
            "DBInstanceIdentifier", var.rds_instance_id,
            { stat = "Average", period = 60 }
          ]]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 20
        width  = 8
        height = 6
        properties = {
          title  = "RDS — Conexiones activas"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [[
            "AWS/RDS", "DatabaseConnections",
            "DBInstanceIdentifier", var.rds_instance_id,
            { stat = "Average", period = 60 }
          ]]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 20
        width  = 8
        height = 6
        properties = {
          title  = "RDS — Almacenamiento libre (GB)"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [[
            "AWS/RDS", "FreeStorageSpace",
            "DBInstanceIdentifier", var.rds_instance_id,
            { stat = "Average", period = 300, label = "Free Storage" }
          ]]
          annotations = {
            horizontal = [{ value = 2147483648, label = "Umbral alerta (2 GB)", color = "#ff0000" }]
          }
        }
      },

      # ── Fila 6: Logs de ECS (widget de logs) ────────────────────────
      {
        type   = "log"
        x      = 0
        y      = 26
        width  = 24
        height = 6
        properties = {
          title  = "Logs ECS — Errores recientes"
          region = var.aws_region
          query  = "SOURCE '/ecs/${var.project_name}-${var.environment}' | fields @timestamp, @message | filter @message like /ERROR|error|Error|FATAL/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      }
    ]
  })
}

