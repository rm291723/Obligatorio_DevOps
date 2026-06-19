project_name   = "retailstore"
environment    = "prod"
aws_region     = "us-east-1"
aws_account_id = "220951639094"
ecr_registry   = "220951639094.dkr.ecr.us-east-1.amazonaws.com"

vpc_cidr             = "10.2.0.0/16"
public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24"]
private_subnet_cidrs = ["10.2.10.0/24", "10.2.11.0/24"]

services_list      = ["admin", "cart", "catalog", "checkout", "orders", "ui"]
availability_zones = ["us-east-1a", "us-east-1b"]

services = {
  admin = {
    cpu           = 512
    memory        = 1024
    desired_count = 2
    environment_vars = [
      { name = "PORT", value = "8080" },
      { name = "DB_HOST", value = "localhost" },
      { name = "DB_PORT", value = "5432" }
    ]
  }
  cart = {
    cpu           = 512
    memory        = 1024
    desired_count = 2
    environment_vars = [
      { name = "PORT", value = "8080" },
      { name = "CART_PERSISTENCE_PROVIDER", value = "in-memory" }
    ]
  }
  catalog = {
    cpu           = 512
    memory        = 1024
    desired_count = 2
    environment_vars = [
      { name = "GIN_MODE", value = "release" }
    ]
  }
  checkout = {
    cpu           = 512
    memory        = 1024
    desired_count = 2
    environment_vars = [
      { name = "PORT", value = "8080" }
    ]
  }
  orders = {
    cpu           = 512
    memory        = 1024
    desired_count = 2
    environment_vars = [
      { name = "GIN_MODE", value = "release" }
    ]
  }
  ui = {
    cpu           = 512
    memory        = 1024
    desired_count = 2
    environment_vars = [
      { name = "PORT", value = "8080" }
    ]
  }
}
