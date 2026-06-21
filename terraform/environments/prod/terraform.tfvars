project_name   = "retailstore"
environment    = "prod"
aws_region     = "us-east-1"
aws_account_id = "220951639094"
ecr_registry   = "220951639094.dkr.ecr.us-east-1.amazonaws.com"

vpc_cidr             = "10.2.0.0/16"
public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24"]
private_subnet_cidrs = ["10.2.10.0/24", "10.2.11.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

services_list = ["admin", "cart", "catalog", "checkout", "orders", "ui"]

db_username = "retail_user"
db_password = "retailpassword"
