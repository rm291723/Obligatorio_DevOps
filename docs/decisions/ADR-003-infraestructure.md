# ADR-003: Decisiones de infraestructura en AWS

**Estado:** Aceptado  
**Fecha:** 2026-06-29  
**Autores:** Ricardo Menéndez

---

## Contexto

RetailStore es una plataforma e-commerce basada en microservicios que requiere una infraestructura cloud capaz de soportar despliegues automatizados, aislamiento entre ambientes y operación dentro de las restricciones del AWS Academy Learner Lab.

Las decisiones de infraestructura debían equilibrar tres factores: requisitos del obligatorio (IaC, múltiples ambientes, serverless), restricciones técnicas del laboratorio (sin IAM propio, sin ElastiCache, créditos limitados) y mantenibilidad del código Terraform.

---

## Decisiones

### 1. AWS ECS Fargate como plataforma de contenedores

**Decisión:** Desplegar los seis microservicios en ECS Fargate sin servidores EC2.

**Alternativas consideradas:**
- EC2 con Docker Compose — mayor control pero gestión manual de instancias
- EKS (Kubernetes) — más potente pero excesivamente complejo para el alcance del proyecto y no disponible en Learner Lab sin restricciones
- ECS con EC2 launch type — requiere gestión del cluster subyacente

**Justificación:** Fargate elimina la gestión de infraestructura de cómputo. Cada microservicio corre en su propia task definition con recursos aislados (256 CPU / 512 MB por defecto). El modelo serverless de Fargate se alinea con las restricciones del Learner Lab, que no permite crear roles IAM propios — se usa `LabRole` para todas las tasks.

---

### 2. Application Load Balancer con enrutamiento por path

**Decisión:** Un único ALB con reglas de enrutamiento basadas en path para dirigir tráfico a cada microservicio.

**Alternativas consideradas:**
- Un ALB por microservicio — costo elevado, innecesario para el alcance
- API Gateway — mayor funcionalidad pero agrega complejidad y costo
- Nginx como reverse proxy en ECS — añade un servicio más a gestionar

**Justificación:** Un ALB único con listener rules por path (`/catalog/*`, `/cart/*`, `/orders/*`, etc.) cubre todos los requisitos de enrutamiento con un costo mínimo. Los target groups individuales por servicio permiten health checks independientes. Esta arquitectura es estándar para microservicios en AWS y comprensible para la defensa.

---

### 3. RDS PostgreSQL 16 en subred privada

**Decisión:** Base de datos gestionada en subredes privadas, sin acceso público, con parameter group que deshabilita SSL forzado.

**Alternativas consideradas:**
- PostgreSQL en contenedor ECS — sin persistencia garantizada entre deployments
- Aurora Serverless — no disponible en Learner Lab
- RDS en subred pública — riesgo de seguridad innecesario

**Justificación:** RDS en subred privada garantiza que la base de datos solo es accesible desde dentro de la VPC (ECS tasks y Lambda). La inicialización de bases de datos (`catalogdb`, `cartdb`) se delega a una Lambda dentro de la misma VPC para evitar acceso directo desde el exterior.

El parámetro `rds.force_ssl=0` fue necesario porque los drivers de Go (pgx) y Python (psycopg2) en los contenedores ECS no están configurados con certificados RDS. En producción real este parámetro se eliminaría y se configurarían los certificados apropiadamente.

---

### 4. Módulos Terraform reutilizables con tres ambientes

**Decisión:** Estructura modular con módulos independientes (`vpc`, `ecr`, `ecs`, `alb`, `rds`, `lambda`, `observability`) instanciados desde tres directorios de ambiente (`dev`, `test`, `prod`).

**Alternativas consideradas:**
- Workspaces de Terraform — estado compartido entre ambientes, mayor riesgo de error
- Un único archivo `main.tf` monolítico — no reutilizable, difícil de mantener
- Terragrunt — agrega una capa de abstracción innecesaria para tres ambientes

**Justificación:** Los módulos permiten reutilizar la misma lógica de infraestructura con configuraciones diferenciadas por `.tfvars`. El estado de cada ambiente se almacena de forma independiente en S3 (`tf-state-rmenendez`) bajo prefijos distintos, evitando interferencia entre ambientes.

---

### 5. Lambda para inicialización de bases de datos y notificaciones de seguridad

**Decisión:** Dos funciones Lambda: `db-initializer` para crear las bases de datos en RDS al momento del despliegue, y `security-notifier` para procesar alertas de CloudWatch.

**Alternativas consideradas:**
- Migrations en el arranque del contenedor — genera race conditions si múltiples tasks arrancan simultáneamente
- Conexión directa desde el pipeline CI/CD a RDS — imposible desde GitHub Actions sin exponer RDS públicamente
- Init containers en ECS — no soportados nativamente en Fargate

**Justificación:** La Lambda `db-initializer` corre dentro de la VPC con acceso a RDS y se invoca desde el pipeline después de `terraform apply`. Esto garantiza que las bases existen antes de que los servicios intenten conectarse. La Lambda `security-notifier` recibe eventos de CloudWatch Alarms vía SNS y los registra en un log group estructurado.

---

### 6. Módulo de observabilidad con CloudWatch

**Decisión:** Módulo Terraform dedicado que crea SNS topic, tres alarmas CloudWatch y un dashboard operacional.

**Alternativas consideradas:**
- Datadog / New Relic — no disponibles en Learner Lab, costo adicional
- Prometheus + Grafana en ECS — complejidad operacional elevada para el alcance
- Sin observabilidad formal — no cumple los requisitos del obligatorio

**Justificación:** CloudWatch está integrado nativamente con ECS, ALB y RDS sin configuración adicional en los servicios. Las tres alarmas cubren los escenarios de mayor riesgo operacional: errores de aplicación (5XX), saturación de cómputo (CPU ECS) y riesgo de datos (storage RDS). El dashboard consolida todas las métricas en una vista única accesible sin herramientas externas.

---

## Restricciones del AWS Academy Learner Lab

Las siguientes limitaciones condicionaron varias decisiones de diseño:

| Restricción | Impacto | Workaround aplicado |
|-------------|---------|---------------------|
| No se pueden crear roles IAM | Todos los recursos usan `LabRole` / `LabInstanceProfile` | Hardcodeado en módulos ECS y Lambda |
| ElastiCache no disponible | Checkout usa persistencia in-memory | Variable `CHECKOUT_PERSISTENCE=in-memory` |
| Créditos limitados (~$50 totales) | Ambientes destruidos entre sesiones | `terraform destroy` al finalizar cada sesión |
| Credenciales expiran cada 4 horas | Pipeline puede fallar por credenciales vencidas | Secrets actualizados manualmente en GitHub antes de cada ejecución |
| Container Insights deshabilitado | Métricas de ECS a nivel de tarea no disponibles | Se usan métricas a nivel de cluster (disponibles sin Container Insights) |

---

## Consecuencias

**Positivas:**
- Infraestructura completamente reproducible desde cero con `terraform apply`
- Tres ambientes aislados con configuración diferenciada
- Observabilidad operacional sin dependencias externas
- Pipeline capaz de detectar y recuperarse del drift de estado ECR

**Negativas / Deuda técnica:**
- `db_password` en texto plano en `.tfvars` (workaround de laboratorio — en producción se usaría AWS Secrets Manager)
- Deploy a producción sin aprobación manual (en producción se usarían GitHub Environments con `required_reviewers`)
- `sleep 3` en el script de consulta de logs es frágil — en producción se haría polling hasta que el query status sea `Complete`