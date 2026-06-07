# Etapa 1: build
FROM golang:1.25-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o orders .

# Etapa 2: producción
FROM alpine:3.21
WORKDIR /app
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=builder /app/orders ./orders
EXPOSE 8080
USER appuser
CMD ["./orders"]
