# Observabilidad — RetailStore

## Arquitectura de observabilidad

Las señales de observabilidad fluyen de la siguiente manera:

```
Microservicios ECS Fargate
        │
        ├── Logs stdout  ──► CloudWatch Log Group /ecs/retailstore-{env}
        │                             │
        │                             └── Log Insights queries (dashboard)
        │
        ├── Métricas ECS ──► CloudWatch Metrics (AWS/ECS)
        │
ALB ────┼── Métricas ALB ──► CloudWatch Metrics (AWS/ApplicationELB)
        │
RDS ────┴── Métricas RDS ──► CloudWatch Metrics (AWS/RDS)
                                      │
                              CloudWatch Alarms
                                      │
                                 SNS Topic
                                      │
                          [Email / Webhook / PagerDuty]
```

## Dashboard

**Nombre:** `retailstore-{env}`  
**URL:** disponible como output de Terraform (`dashboard_url`)

### Widgets incluidos

| Sección | Métrica | Utilidad |
|---------|---------|---------|
| ALB | RequestCount | Throughput general de la aplicación |
| ALB | TargetResponseTime (p95) | Latencia percibida por el usuario |
| ALB | HTTPCode_Target_5XX_Count | Errores de aplicación |
| ALB | HealthyHostCount por servicio | Disponibilidad de cada microservicio |
| ECS | CPUUtilization por servicio | Consumo de CPU por contenedor |
| ECS | MemoryUtilization por servicio | Consumo de memoria por contenedor |
| RDS | CPUUtilization | Carga del motor de base de datos |
| RDS | DatabaseConnections | Conexiones activas (pool exhaustion) |
| RDS | FreeStorageSpace | Espacio disponible en disco |
| Logs | Errores recientes | Últimos 50 errores en todos los servicios |

---

## Alertas configuradas

### Alerta 1 — Errores 5XX en el ALB

| Campo | Valor |
|-------|-------|
| **Nombre** | `retailstore-alb-5xx-{env}` |
| **Métrica** | `AWS/ApplicationELB :: HTTPCode_Target_5XX_Count` |
| **Condición de disparo (trigger)** | Sum ≥ 10 errores en 2 períodos consecutivos de 60 segundos |
| **Cubre** | Disponibilidad, rendimiento |
| **Canal** | SNS Topic → email/webhook |

**Procedimiento de respuesta:**

1. Ingresar a CloudWatch → Log Insights → Log Group `/ecs/retailstore-{env}`
2. Ejecutar: `fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 100`
3. Identificar el microservicio que genera los errores (campo `logStreamNamePrefix`)
4. Revisar el estado del ECS Service afectado: `aws ecs describe-services --cluster retailstore-cluster-{env} --services {servicio}-{env}`
5. Si hay tareas fallando: revisar la task definition y reiniciar el servicio
6. Si el error persiste: escalar al equipo de desarrollo con el log completo

---

### Alerta 2 — CPU alta en el cluster ECS

| Campo | Valor |
|-------|-------|
| **Nombre** | `retailstore-ecs-cpu-high-{env}` |
| **Métrica** | `AWS/ECS :: CPUUtilization` (ClusterName) |
| **Condición de disparo (trigger)** | Average ≥ 80% en 3 períodos consecutivos de 60 segundos |
| **Cubre** | Uso de recursos, rendimiento |
| **Canal** | SNS Topic → email/webhook |

**Procedimiento de respuesta:**

1. Revisar en el dashboard qué servicio específico tiene CPU alta (widget "CPU por servicio")
2. Verificar si hay un pico de tráfico legítimo en el widget "Requests por minuto"
3. Si el tráfico es legítimo: aumentar el `desired_count` del servicio afectado en el `.tfvars` correspondiente y aplicar `terraform apply`
4. Si el tráfico es anómalo (posible ataque): revisar las IPs origen en los logs del ALB y considerar agregar reglas en el Security Group
5. Si la CPU persiste alta sin tráfico: puede ser un loop o memory leak → reiniciar el servicio y crear issue en el repositorio

---

### Alerta 3 (bonus) — Almacenamiento bajo en RDS

| Campo | Valor |
|-------|-------|
| **Nombre** | `retailstore-rds-storage-low-{env}` |
| **Métrica** | `AWS/RDS :: FreeStorageSpace` |
| **Condición de disparo (trigger)** | Average ≤ 2 GB (2.147.483.648 bytes) en 1 período de 300 segundos |
| **Cubre** | Seguridad operacional de datos |
| **Canal** | SNS Topic → email/webhook |

**Procedimiento de respuesta:**

1. Conectarse a la consola RDS y verificar el espacio real disponible
2. Identificar qué base de datos está creciendo: conectarse a PostgreSQL y ejecutar `SELECT pg_size_pretty(pg_database_size(datname)), datname FROM pg_database ORDER BY 1 DESC;`
3. Si hay datos de testing/basura: purgar con el equipo de desarrollo
4. Si el crecimiento es legítimo: modificar el parámetro `allocated_storage` en el módulo RDS y aplicar `terraform apply`
5. Como medida preventiva inmediata: activar el autoscaling de almacenamiento en la consola RDS

---

## Suscripción a alertas

Para recibir las alertas por email, suscribirse al SNS Topic:

```bash
# Obtener el ARN del SNS Topic
terraform output sns_alerts_arn

# Suscribirse
aws sns subscribe \
  --topic-arn <ARN_DEL_OUTPUT> \
  --protocol email \
  --notification-endpoint tu-email@ejemplo.com
```

La suscripción requiere confirmación por email antes de activarse.