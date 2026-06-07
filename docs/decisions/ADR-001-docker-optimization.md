# ADR-001: Optimización de Dockerfiles

## Fecha
2026-06-07

## Estado
Aceptado

## Contexto
El equipo de desarrollo original entregó Dockerfiles básicos sin buenas
prácticas aplicadas. Las imágenes resultantes eran pesadas, corrían como
root y no separaban dependencias de desarrollo de producción.

## Decisiones tomadas

### 1. Imágenes base mínimas (Alpine)
- **Decisión:** Usar imágenes alpine en lugar de las imágenes base completas
- **Razón:** Reducir el tamaño de la imagen y la superficie de ataque
- **Impacto:** Imágenes ~20x más pequeñas, menos vulnerabilidades

### 2. Multi-stage builds
- **Decisión:** Separar etapa de build de etapa de producción
- **Razón:** La imagen final no necesita compiladores ni devDependencies
- **Impacto:** Solo el artefacto compilado llega a producción

### 3. Usuario non-root
- **Decisión:** Crear usuario sin privilegios para ejecutar la aplicación
- **Razón:** Reducir el impacto de una posible vulnerabilidad explotada
- **Impacto:** El proceso dentro del contenedor no tiene permisos de root

### 4. .dockerignore
- **Decisión:** Agregar .dockerignore en cada microservicio
- **Razón:** Evitar copiar archivos innecesarios o sensibles a la imagen
- **Impacto:** Builds más rápidos y sin riesgo de exponer archivos .env

## Consecuencias
- Las imágenes son más pequeñas, seguras y rápidas de desplegar
- Trivy reportará menos vulnerabilidades en el escaneo
- El proceso de build tarda un poco más por el multi-stage