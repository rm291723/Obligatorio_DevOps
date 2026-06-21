import boto3
import json
import os
import psycopg2

def handler(event, context):
    """
    Lambda db-initializer: crea las bases de datos catalogdb y cartdb
    y ejecuta el script de inicialización.
    """
    host = os.environ.get('DB_HOST')
    port = os.environ.get('DB_PORT', '5432')
    username = os.environ.get('DB_USERNAME')
    password = os.environ.get('DB_PASSWORD')

    try:
        # Conectarse a la DB orders (default)
        conn = psycopg2.connect(
            host=host,
            port=port,
            user=username,
            password=password,
            dbname='orders'
        )
        conn.autocommit = True
        cur = conn.cursor()

        # Crear bases de datos
        for db in ['catalogdb', 'cartdb']:
            cur.execute(f"SELECT 1 FROM pg_database WHERE datname='{db}'")
            if not cur.fetchone():
                cur.execute(f"CREATE DATABASE {db}")
                print(f"Created database {db}")
            else:
                print(f"Database {db} already exists")

        cur.close()
        conn.close()

        # Conectarse a cada DB y crear permisos
        for db in ['orders', 'catalogdb', 'cartdb']:
            conn = psycopg2.connect(
                host=host,
                port=port,
                user=username,
                password=password,
                dbname=db
            )
            conn.autocommit = True
            cur = conn.cursor()
            cur.execute(f"GRANT ALL ON SCHEMA public TO {username}")
            cur.execute(f"ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO {username}")
            cur.execute(f"ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO {username}")
            
            if db == 'cartdb':
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS cart_items (
                        customer_id VARCHAR(255) NOT NULL,
                        item_id     VARCHAR(255) NOT NULL,
                        quantity    INTEGER      NOT NULL,
                        unit_price  INTEGER      NOT NULL,
                        PRIMARY KEY (customer_id, item_id)
                    )
                """)
                print("Created cart_items table")
            
            cur.close()
            conn.close()

        return {
            'statusCode': 200,
            'body': json.dumps('Database initialization complete')
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        raise e