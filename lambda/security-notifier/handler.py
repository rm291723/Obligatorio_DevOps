import json
import boto3
import os
from datetime import datetime

def lambda_handler(event, context):
    """
    Lambda que recibe notificaciones de vulnerabilidades de Trivy
    y las registra en CloudWatch Logs con formato estructurado.
    """
    
    cloudwatch = boto3.client('logs', region_name='us-east-1')
    
    log_group = os.environ.get('LOG_GROUP', '/retailstore/security/vulnerabilities')
    log_stream = f"trivy-{datetime.utcnow().strftime('%Y/%m/%d')}"
    
    # Parsear el evento recibido
    service = event.get('service', 'unknown')
    severity = event.get('severity', 'UNKNOWN')
    cve_count = event.get('cve_count', 0)
    cves = event.get('cves', [])
    pipeline_run = event.get('pipeline_run', 'unknown')
    
    # Construir el mensaje de log estructurado
    log_message = {
        'timestamp': datetime.utcnow().isoformat(),
        'event_type': 'SECURITY_SCAN_RESULT',
        'service': service,
        'severity': severity,
        'cve_count': cve_count,
        'cves': cves,
        'pipeline_run': pipeline_run,
        'status': 'BLOCKED' if cve_count > 0 else 'PASSED'
    }
    
    # Crear log group si no existe
    try:
        cloudwatch.create_log_group(logGroupName=log_group)
    except cloudwatch.exceptions.ResourceAlreadyExistsException:
        pass
    
    # Crear log stream si no existe
    try:
        cloudwatch.create_log_stream(
            logGroupName=log_group,
            logStreamName=log_stream
        )
    except cloudwatch.exceptions.ResourceAlreadyExistsException:
        pass
    
    # Escribir el evento en CloudWatch
    cloudwatch.put_log_events(
        logGroupName=log_group,
        logStreamName=log_stream,
        logEvents=[{
            'timestamp': int(datetime.utcnow().timestamp() * 1000),
            'message': json.dumps(log_message)
        }]
    )
    
    print(f"Security scan result logged: {json.dumps(log_message)}")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Security event logged successfully',
            'service': service,
            'status': log_message['status']
        })
    }