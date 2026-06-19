import json
import boto3
import os
from datetime import datetime

def handler(event, context):
    """
    Lambda security-notifier: procesa alarmas de CloudWatch
    y las registra como eventos de seguridad.
    """
    print(f"Evento recibido: {json.dumps(event)}")
    
    sns_topic_arn = os.environ.get('SNS_TOPIC_ARN', '')
    environment = os.environ.get('ENVIRONMENT', 'unknown')
    
    message = {
        'timestamp': datetime.utcnow().isoformat(),
        'environment': environment,
        'event': event,
        'source': 'security-notifier-lambda'
    }
    
    if sns_topic_arn:
        sns = boto3.client('sns')
        sns.publish(
            TopicArn=sns_topic_arn,
            Subject=f'[RetailStore-{environment.upper()}] Alerta de Seguridad',
            Message=json.dumps(message, indent=2)
        )
    
    return {
        'statusCode': 200,
        'body': json.dumps('Notificación procesada correctamente')
    }