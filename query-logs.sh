#!/bin/bash
# Script de consulta de logs — RetailStore
# Uso: ./query-logs.sh [ambiente] [filtro]
# Ejemplos:
#   ./query-logs.sh dev
#   ./query-logs.sh dev error
#   ./query-logs.sh dev catalog

AMBIENTE=${1:-dev}
FILTRO=${2:-""}
LOG_GROUP="/ecs/retailstore-${AMBIENTE}"

if [ -z "$FILTRO" ]; then
  QUERY='fields @timestamp, @message | sort @timestamp desc | limit 50'
else
  QUERY="fields @timestamp, @message | filter @message like /${FILTRO}/ | sort @timestamp desc | limit 50"
fi

echo "Consultando logs de ${LOG_GROUP}..."
echo "Filtro: ${FILTRO:-ninguno}"
echo "---"

QUERY_ID=$(aws logs start-query \
  --log-group-name "$LOG_GROUP" \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string "$QUERY" \
  --region us-east-1 \
  --output text \
  --query 'queryId')

echo "Query ID: $QUERY_ID"

sleep 3

aws logs get-query-results \
  --query-id "$QUERY_ID" \
  --region us-east-1 \
  --output table