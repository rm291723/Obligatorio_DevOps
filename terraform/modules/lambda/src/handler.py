def lambda_handler(event, context):
    print("Notificador de seguridad de RetailStore activado con éxito.")
    return {
        'statusCode': 200,
        'body': 'Alerta procesada correctamente'
    }
