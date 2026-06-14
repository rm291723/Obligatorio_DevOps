# ADR-002: Herramientas de Seguridad en el Pipeline

## Fecha
2026-06-14

## Estado
Aceptado

## Decisiones tomadas

### Gitleaks — Detección de secretos
Integrado para escanear el historial de commits en busca de credenciales expuestas.

### Semgrep — SAST
Análisis estático de código para Go, Python y TypeScript con reglas del repositorio oficial.

### Trivy — Escaneo de imágenes
Bloquea el pipeline ante vulnerabilidades CRITICAL o HIGH con parche disponible.

### SonarCloud — Calidad de código
Análisis de bugs, code smells y duplicaciones con quality gate integrado.

## CVEs encontrados y remediados
- CVE-2026-33816: pgx/v5 → actualizado a v5.9.0
- CVE-2026-33186: grpc → actualizado a v1.79.3
- CVE-2024-47874: starlette → actualizado a v0.46.2
- CVE-2026-45447: OpenSSL → resuelto con apk upgrade
- CVE-2026-29181: OpenTelemetry → actualizado a v1.43.0