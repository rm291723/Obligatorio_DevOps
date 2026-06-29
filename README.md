# RetailStore — Plataforma de E-Commerce con DevOps

RetailStore es una plataforma de e-commerce basada en microservicios, desarrollada como caso de estudio para el Certificado en DevOps de Universidad ORT Uruguay (Marzo 2026).

El proyecto toma una aplicación funcional sin infraestructura en la nube y la lleva a producción de forma **confiable, segura y observable**, aplicando prácticas DevOps end-to-end: containerización, CI/CD automatizado, infraestructura como código, seguridad integrada y observabilidad.

---

## Índice

1. [Arquitectura de microservicios](#arquitectura-de-microservicios)
2. [Inicio rápido — local](#inicio-rápido--local)
3. [Despliegue en AWS](#despliegue-en-aws)
4. [Pipeline CI/CD](#pipeline-cicd)
5. [Infraestructura como código](#infraestructura-como-código)
6. [Seguridad](#seguridad)
7. [Observabilidad](#observabilidad)
8. [Variables de entorno](#variables-de-entorno)
9. [Estructura del repositorio](#estructura-del-repositorio)
10. [Estrategia de ramas](#estrategia-de-ramas)
11. [Decisiones de diseño](#decisiones-de-diseño)

---

## Arquitectura de microservicios

La aplicación está compuesta por 6 microservicios independientes que se comunican por HTTP:

```
          ┌──────────────────────────────────────────────────┐
          │               Usuario / Navegador                │
          └────────────────────────┬─────────────────────────┘
                                   │ HTTP
          ┌────────────────────────▼─────────────────────────┐
          │                   UI  :8080                      │
          │            Node.js 22 / Express                  │
          └───────┬──────────┬──────────┬────────────┬───────┘
                  │          │          │            │  HTTP (proxy)
        ┌─────────▼────┐ ┌───▼─────┐ ┌──▼────────┐ ┌▼──────────┐
        │   Catalog    │ │  Cart   │ │ Checkout  │ │  Orders   │
        │  Go / Gin    │ │ Python  │ │ NestJS/TS │ │  Go / Gin │
        └──────┬───────┘ └────┬────┘ └─────┬─────┘ └─────┬─────┘
               │              │            │              │
               └──────────────┴────────────┴──────────────┘
                                          │
                              ┌───────────▼───────────┐
                              │     PostgreSQL 16      │
                              │  catalogdb │ cartdb    │
                              │         orders         │
                              └───────────────────────┘

          ┌──────────────────────────────────────────────────┐
          │                  Admin  :8081                    │
          │            Node.js 22 / Express                  │
          └────────────────────────┬─────────────────────────┘
                                   │ SQL directo
                              PostgreSQL 16
```

### Tecnologías por servicio

| Servicio | Lenguaje | Framework | Persistencia | Puerto |
|----------|----------|-----------|--------------|--------|
| **ui** | TypeScript | Express | — | 8080 |
| **catalog** | Go 1.25 | Gin + GORM | PostgreSQL (`catalogdb`) | — |
| **cart** | Python 3.12 | FastAPI | PostgreSQL (`cartdb`) / in-memory | — |
| **checkout** | TypeScript | NestJS | Redis / in-memory | — |
| **orders** | Go 1.25 | Gin + GORM | PostgreSQL (`orders`) | — |
| **admin** | TypeScript | Express | PostgreSQL | 8081 |

---

## Inicio rápido — local

### Prerrequisitos

- [Docker](https://docs.docker.com/get-docker/) 24+
- [Docker Compose](https://docs.docker.com/compose/install/) v2.20+

### Levantar todos los servicios

```bash
docker compose up --build
```

| Servicio | URL |
|----------|-----|
| Tienda | http://localhost:8080 |
| Admin | http://localhost:8081 |

Credenciales del panel admin: `admin` / `admin`

### Comandos útiles

```bash
# Detener servicios
docker compose down

# Detener y borrar volúmenes (resetea la base de datos)
docker compose down -v

# Ver logs de un servicio específico
docker compose logs -f catalog

# Reconstruir un servicio
docker compose up --build catalog
```

---

## Despliegue en AWS

### Prerrequisitos

- Cuenta AWS Academy Learner Lab activa
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [AWS CLI](https://aws.amazon.com/cli/) configurado
- Bucket S3 para estado remoto: `tf-state-rmenendez`

### Configurar credenciales AWS

Cada vez que se inicia una sesión en AWS Academy, las credenciales cambian. Actualizar `~/.aws/credentials`:

```ini
[default]
aws_access_key_id     = <AWS_ACCESS_KEY_ID>
aws_secret_access_key = <AWS_SECRET_ACCESS_KEY>
aws_session_token     = <AWS_SESSION_TOKEN>
```

Y actualizar los GitHub Secrets correspondientes (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`).

### Ambientes disponibles

| Ambiente | Rama que dispara el deploy | VPC CIDR | RDS | ECS desired_count |
|----------|---------------------------|----------|-----|--------------------|
| **dev** | `develop` (push) | 10.0.0.0/16 | db.t3.micro | 1 por servicio |
| **test** | Tags `v*` (ej. `v1.0.0`) | 10.1.0.0/16 | db.t3.micro | 1 por servicio |
| **prod** | `main` (push) | 10.2.0.0/16 | db.t3.micro | 2 por servicio |

### Despliegue manual (si no se usa el pipeline)

```bash
# 1. Posicionarse en el ambiente deseado
cd terraform/environments/dev

# 2. Inicializar Terraform
terraform init

# 3. Importar repositorios ECR si ya existen (workaround AWS Academy)
for service in admin cart catalog checkout orders ui; do
  terraform import "module.ecr.aws_ecr_repository.this[\"$service\"]" retailstore/$service 2>/dev/null || true
done

# 4. Revisar el plan
terraform plan

# 5. Aplicar
terraform apply -auto-approve
```

### Inicializar las bases de datos

Las bases de datos `catalogdb` y `cartdb` deben crearse manualmente la primera vez mediante la Lambda `db-initializer`:

```bash
aws lambda invoke \
  --function-name retailstore-db-initializer-dev \
  --payload '{}' \
  response.json

cat response.json
```

### Destruir infraestructura (para conservar créditos)

```bash
cd terraform/environments/dev
terraform destroy -auto-approve
```

---

## Pipeline CI/CD

El pipeline está definido en `.github/workflows/ci-cd.yml` y se ejecuta en cada push a `main` o `develop`, y en Pull Requests.

### Etapas y quality gates

```
Push / PR
    │
    ├─── [gitleaks]        Detección de secretos en el historial de commits
    ├─── [semgrep]         SAST: análisis estático Go, Python, TypeScript
    ├─── [sonarcloud]      Calidad de código: bugs, smells, duplicación
    ├─── [newman-tests]    Tests de API con Postman/Newman (7 casos)
    └─── [terraform-sast]  Validación y formato del código IaC
              │
              │  (todos deben pasar)
              ▼
    [build-and-push]       Build de 6 imágenes Docker + Trivy (CRITICAL/HIGH)
                           Push a ECR con tag SHA y :latest
              │
              ├── [terraform-plan]   Solo en PRs: plan sin apply
              │
              ├── [deploy-dev]       Solo en push a develop
              ├── [deploy-test]      Solo en tags v*
              └── [deploy-prod]      Solo en push a main
```

### Herramientas de seguridad integradas

| Herramienta | Etapa | Qué analiza | Bloquea si... |
|-------------|-------|-------------|----------------|
| **Gitleaks** | Pre-build | Secretos en commits | Encuentra credenciales |
| **Semgrep** | Pre-build | Código fuente (SAST) | Reglas p/default, golang, python, typescript |
| **SonarCloud** | Pre-build | Calidad y seguridad | Quality gate falla |
| **Trivy** | Post-build | Imagen Docker (SCA) | CVE CRITICAL o HIGH con fix disponible |
| **Newman** | Pre-build | APIs funcionales | Algún test falla |

---

## Infraestructura como código

Toda la infraestructura está definida en Terraform, organizada en módulos reutilizables.

### Módulos

```
terraform/
├── modules/
│   ├── vpc/          # VPC, subnets públicas/privadas, NAT Gateway, IGW
│   ├── ecr/          # Repositorios de imágenes Docker por microservicio
│   ├── alb/          # Application Load Balancer con path-based routing
│   ├── ecs/          # Cluster ECS Fargate, task definitions, servicios
│   ├── rds/          # PostgreSQL 16 en subnet privada
│   └── lambda/       # Lambda security-notifier + db-initializer
└── environments/
    ├── dev/           # terraform.tfvars, main.tf, variables.tf, outputs.tf
    ├── test/
    └── prod/
```

### Estado remoto

El estado de Terraform se almacena en S3:

| Ambiente | S3 Key |
|----------|--------|
| dev | `retailstore/dev/terraform.tfstate` |
| test | `retailstore/test/terraform.tfstate` |
| prod | `retailstore/prod/terraform.tfstate` |

Bucket: `tf-state-rmenendez` (región `us-east-1`)

### Arquitectura en AWS

```
Internet
    │
    ▼
[ALB] ── path-based routing ──► /catalog/*  → ECS catalog
  │                         ──► /carts/*    → ECS cart
  │                         ──► /checkout/* → ECS checkout
  │                         ──► /orders/*   → ECS orders
  │                         ──► /auth/*     → ECS admin
  │                         ──► /api/*      → ECS ui
  │                         ──► /           → ECS ui
  │
  └── Security Group (solo puerto 80)
           │
           ▼
    [ECS Fargate] (subnets privadas, sin IP pública)
    admin | cart | catalog | checkout | orders | ui
           │
           ├── [RDS PostgreSQL 16] (subnet privada)
           │    catalogdb | cartdb | orders
           │
           └── [Lambda]
                ├── security-notifier (logs a CloudWatch)
                └── db-initializer (crea bases de datos)

[ECR] ── imágenes Docker ──► ECS task definitions
[S3]  ── estado Terraform ──► terraform backend
[CloudWatch] ── logs + métricas + dashboard + alarmas
[SNS] ── notificaciones de alarmas
```

### Serverless — Lambda functions

Se implementaron dos funciones Lambda con propósitos distintos:

**`security-notifier`** (seguridad/observabilidad): recibe eventos de CloudWatch Alarms vía SNS y registra alertas de seguridad en CloudWatch Logs con formato estructurado JSON. Permite auditar incidentes de seguridad con trazabilidad.

**`db-initializer`** (automatización): resuelve una limitación del entorno AWS Academy donde RDS no es accesible directamente. La Lambda corre dentro de la VPC y crea las bases de datos `catalogdb` y `cartdb`, y la tabla `cart_items`, que los servicios necesitan al arrancar.

---

## Seguridad

### Secretos y credenciales

- **Ningún secreto está hardcodeado** en el código fuente
- Las credenciales AWS se almacenan como GitHub Secrets
- El token de SonarCloud se almacena como GitHub Secret (`SONAR_TOKEN`)
- `ADMIN_JWT_SECRET` se provee como variable de entorno en el task definition de ECS

> **Nota para producción real:** la contraseña de RDS en `terraform.tfvars` debería gestionarse con AWS Secrets Manager. En el contexto de AWS Academy Learner Lab, este enfoque está justificado por las restricciones de permisos IAM.

### Escaneo de vulnerabilidades

#### CVEs remediados

| CVE | Paquete | Acción tomada |
|-----|---------|---------------|
| CVE-2026-33816 | `pgx/v5` (Go) | Actualizado a v5.9.0 |
| CVE-2026-33186 | `grpc` (Go) | Actualizado a v1.79.3 |
| CVE-2024-47874 | `starlette` (Python) | Actualizado a v0.46.2 |
| CVE-2026-45447 | OpenSSL (Alpine) | `apk upgrade` en Dockerfile |
| CVE-2026-29181 | OpenTelemetry | Actualizado a v1.43.0 |

#### CVEs con excepción justificada

Los CVEs en `.trivyignore` tienen justificación técnica documentada. Ejemplos:

- **CVE-2026-33671** (`picomatch` en npm interno): no afecta al runtime de producción; `npm` no se ejecuta en el contenedor.
- **CVE-2025-62727** (`starlette` DoS): el fix requiere `starlette>=0.49.1` pero `fastapi==0.115.x` limita a `<0.47.0`; actualizar fastapi requeriría refactoring mayor.
- CVEs de `devDependencies` de NestJS/checkout: estos paquetes no están en el bundle de producción.

Ver `.trivyignore` para el detalle completo de cada excepción.

### SAST — Semgrep

Las exclusiones en `.semgrepignore` están justificadas por restricciones del entorno AWS Academy:

- Módulo ECR y Lambda excluidos de reglas KMS (Learner Lab no permite crear KMS keys)
- Alerta de versión TLS en ALB excluida (restricción del laboratorio educativo)

---

## Observabilidad

### Dashboard CloudWatch

El módulo `terraform/modules/observability/` crea un dashboard con las siguientes secciones:

- **ALB**: requests por minuto, latencia p95, errores 5XX, hosts saludables por servicio
- **ECS**: CPU y memoria por servicio
- **RDS**: CPU, conexiones activas, almacenamiento libre
- **Logs**: errores recientes de todos los servicios (CloudWatch Insights)

### Alarmas configuradas

| Alarma | Métrica | Trigger | Cubre |
|--------|---------|---------|-------|
| `alb-5xx-{env}` | HTTPCode_Target_5XX_Count | ≥ 10 errores en 2 min | Disponibilidad |
| `ecs-cpu-high-{env}` | CPUUtilization ECS | ≥ 80% en 3 min | Recursos |
| `rds-storage-low-{env}` | FreeStorageSpace RDS | ≤ 2 GB | Seguridad operacional |

Todas las alarmas notifican vía SNS Topic. Para suscribirse:

```bash
aws sns subscribe \
  --topic-arn $(terraform output -raw sns_alerts_arn) \
  --protocol email \
  --notification-endpoint tu-email@ejemplo.com
```

### Logs

Todos los servicios ECS envían logs a CloudWatch:

- Log group: `/ecs/retailstore-{ambiente}`
- Retención: 7 días (dev/test), 30 días (prod)

---

## Variables de entorno

### UI

| Variable | Descripción | Default |
|----------|-------------|---------|
| `RETAIL_UI_ENDPOINTS_CATALOG` | URL del servicio catalog | `http://catalog:8080` |
| `RETAIL_UI_ENDPOINTS_CARTS` | URL del servicio cart | `http://carts:8080` |
| `RETAIL_UI_ENDPOINTS_CHECKOUT` | URL del servicio checkout | `http://checkout:8080` |
| `RETAIL_UI_ENDPOINTS_ORDERS` | URL del servicio orders | `http://orders:8080` |

> En AWS, estas variables apuntan al DNS del ALB para que el proxy inverso del UI enrute al servicio correcto a través del load balancer.

### Catalog

| Variable | Descripción | Default |
|----------|-------------|---------|
| `RETAIL_CATALOG_PERSISTENCE_PROVIDER` | `postgres` o `in-memory` | `in-memory` |
| `RETAIL_CATALOG_PERSISTENCE_ENDPOINT` | `host:puerto` de PostgreSQL | — |
| `RETAIL_CATALOG_PERSISTENCE_DB_NAME` | Nombre de la base de datos | `catalogdb` |
| `RETAIL_CATALOG_PERSISTENCE_USER` | Usuario PostgreSQL | `catalog_user` |
| `RETAIL_CATALOG_PERSISTENCE_PASSWORD` | Contraseña PostgreSQL | — |

### Cart

| Variable | Descripción | Default |
|----------|-------------|---------|
| `CART_PERSISTENCE_PROVIDER` | `postgres` o `in-memory` | `in-memory` |
| `CART_POSTGRES_HOST` | Host de PostgreSQL | `localhost` |
| `CART_POSTGRES_PORT` | Puerto de PostgreSQL | `5432` |
| `CART_POSTGRES_DB` | Nombre de la base de datos | `cartdb` |
| `CART_POSTGRES_USER` | Usuario PostgreSQL | `retail_user` |
| `CART_POSTGRES_PASSWORD` | Contraseña PostgreSQL | — |

### Checkout

| Variable | Descripción | Default |
|----------|-------------|---------|
| `RETAIL_CHECKOUT_PERSISTENCE_PROVIDER` | `redis` o `in-memory` | `in-memory` |
| `RETAIL_CHECKOUT_PERSISTENCE_REDIS_URL` | URL de Redis | — |
| `RETAIL_CHECKOUT_ENDPOINTS_ORDERS` | URL del servicio orders | — |

> En AWS se usa `in-memory` como workaround ya que el entorno Learner Lab tiene restricciones para crear ElastiCache. En producción real se usaría Redis para persistencia de sesiones de checkout entre instancias.

### Orders

| Variable | Descripción | Default |
|----------|-------------|---------|
| `RETAIL_ORDERS_PERSISTENCE_ENDPOINT` | `host:puerto` de PostgreSQL | `localhost:5432` |
| `RETAIL_ORDERS_PERSISTENCE_NAME` | Nombre de la base de datos | `orders` |
| `RETAIL_ORDERS_PERSISTENCE_USERNAME` | Usuario PostgreSQL | `retail_user` |
| `RETAIL_ORDERS_PERSISTENCE_PASSWORD` | Contraseña PostgreSQL | — |

### Admin

| Variable | Descripción | Default |
|----------|-------------|---------|
| `DB_HOST` | Host de PostgreSQL | `db` |
| `DB_PORT` | Puerto de PostgreSQL | `5432` |
| `DB_USER` | Usuario PostgreSQL | `retail_user` |
| `DB_PASSWORD` | Contraseña PostgreSQL | — |
| `ADMIN_USERNAME` | Usuario del panel admin | `admin` |
| `ADMIN_PASSWORD` | Contraseña del panel admin | `admin` |
| `ADMIN_JWT_SECRET` | Secreto para tokens JWT | `change-me-in-production` |

---

## Estructura del repositorio

```
.
├── .github/
│   └── workflows/
│       └── ci-cd.yml           # Pipeline CI/CD completo
├── src/
│   ├── admin/                  # Panel de administración (Node.js/Express)
│   ├── cart/                   # Servicio de carrito (Python/FastAPI)
│   ├── catalog/                # Catálogo de productos (Go/Gin)
│   ├── checkout/               # Proceso de pago (Node.js/NestJS)
│   ├── orders/                 # Gestión de órdenes (Go/Gin)
│   └── ui/                     # Frontend (Node.js/Express)
├── terraform/
│   ├── modules/
│   │   ├── alb/                # Application Load Balancer
│   │   ├── ecr/                # Elastic Container Registry
│   │   ├── ecs/                # ECS Fargate cluster y servicios
│   │   ├── lambda/             # Funciones Lambda
│   │   ├── observability/      # Dashboard y alarmas CloudWatch
│   │   ├── rds/                # Base de datos PostgreSQL
│   │   └── vpc/                # Red: VPC, subnets, NAT, IGW
│   └── environments/
│       ├── dev/                # Variables y configuración para Dev
│       ├── test/               # Variables y configuración para Test
│       └── prod/               # Variables y configuración para Prod
├── lambda/
│   └── security-notifier/      # Código Python del notificador
├── tests/
│   └── retailstore.collection.json  # Colección Newman/Postman
├── docs/
│   ├── decisions/
│   │   ├── ADR-001-docker-optimization.md
│   │   ├── ADR-002-security-scanning.md
│   │   └── ADR-003-infrastructure-decisions.md
│   └── OBSERVABILIDAD.md
├── .trivyignore                # CVEs con excepción justificada
├── .semgrepignore              # Reglas SAST excluidas con justificación
├── docker-compose.yml          # Orquestación local
└── init-db.sql                 # Script de inicialización de bases de datos
```

---

## Estrategia de ramas

Se adoptó **Git Flow** adaptado al contexto del proyecto:

```
main ────────────────────────────────────────────► producción
  │                                     ▲
  │                              merge PR
  │                                     │
develop ──────────────────────────────────────────► ambiente dev
  │              ▲         ▲
  │        merge PR   merge PR
  │              │         │
feature/xxx ─────┘         │
                           │
feature/yyy ───────────────┘
```

| Rama | Propósito | Deploy automático |
|------|-----------|------------------|
| `main` | Código en producción, siempre estable | Prod |
| `develop` | Integración continua del trabajo del equipo | Dev |
| `feature/*` | Desarrollo de funcionalidades individuales | — |

**Branch protection en `main`:** se requiere al menos 1 revisión aprobada antes de mergear. Las ramas de feature no pueden fusionarse directamente a `main` o `develop` sin Pull Request.

La elección de Git Flow sobre Trunk-Based Development se justifica por la necesidad de mantener ambientes diferenciados (dev → test → prod) con promoción controlada entre ellos, lo que encaja naturalmente con las ramas de larga vida que propone Git Flow.

---

## Decisiones de diseño

Las decisiones técnicas más relevantes están documentadas como Architecture Decision Records (ADRs) en `docs/decisions/`:

- **ADR-001**: Optimización de Dockerfiles (multi-stage, Alpine, non-root)
- **ADR-002**: Herramientas de seguridad en el pipeline (Gitleaks, Semgrep, Trivy, SonarCloud)
- **ADR-003**: Decisiones de infraestructura (módulos Terraform, ECS vs EKS, Lambda para inicialización de DB)

### Limitaciones conocidas del entorno AWS Academy

| Limitación | Workaround aplicado |
|------------|-------------------|
| Credenciales expiran por sesión | Script de actualización + GitHub Secrets manuales |
| No se pueden crear IAM roles | Se usa `LabRole` / `LabInstanceProfile` pre-existentes |
| ElastiCache no disponible | Checkout usa persistencia `in-memory` |
| KMS Keys restringidas | Excluido de reglas Semgrep (`.semgrepignore`) |
| RDS en subnet privada sin acceso directo | Lambda `db-initializer` corre dentro de la VPC |
| Container Insights con restricciones | Deshabilitado en ECS cluster |

---

## Uso de Inteligencia Artificial Generativa

Durante el desarrollo de este proyecto se utilizó **Claude (Anthropic)** como herramienta de apoyo en las siguientes áreas:

- **Generación de código fuente**: scaffolding de módulos Terraform, configuración de providers y recursos AWS
- **Redacción de documentación**: README, ADRs, justificaciones de excepciones en `.trivyignore`
- **Análisis y corrección de errores**: debugging de configuraciones Terraform, errores en pipelines GitHub Actions
- **Revisión de arquitectura**: evaluación de decisiones de diseño y sugerencias de mejora

Todo el contenido generado fue verificado, adaptado y validado por el equipo antes de su incorporación al proyecto. El razonamiento crítico, las decisiones de diseño y la comprensión del dominio son responsabilidad del equipo.