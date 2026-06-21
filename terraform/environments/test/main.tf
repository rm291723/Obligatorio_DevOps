terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "tf-state-rmenendez"
    key    = "retailstore/test/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source               = "../../modules/vpc"
  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "ecr" {
  source       = "../../modules/ecr"
  project_name = var.project_name
  environment  = var.environment
  services     = var.services_list
}

module "alb" {
  source            = "../../modules/alb"
  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  service_names     = var.services_list
}

module "rds" {
  source               = "../../modules/rds"
  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  private_subnet_cidrs = var.private_subnet_cidrs
  db_username          = var.db_username
  db_password          = var.db_password
}

locals {
  db_endpoint = module.rds.endpoint

  services_with_db = {
    admin = {
      cpu           = 256
      memory        = 512
      desired_count = 1
      environment_vars = [
        { name = "PORT", value = "8080" },
        { name = "DB_HOST", value = split(":", local.db_endpoint)[0] },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_NAME", value = "orders" },
        { name = "DB_USER", value = var.db_username },
        { name = "DB_PASSWORD", value = var.db_password }
      ]
    }
    cart = {
      cpu           = 256
      memory        = 512
      desired_count = 1
      environment_vars = [
        { name = "PORT", value = "8080" },
        { name = "CART_PERSISTENCE_PROVIDER", value = "in-memory" }
      ]
    }
    catalog = {
      cpu           = 256
      memory        = 512
      desired_count = 1
      environment_vars = [
        { name = "GIN_MODE", value = "release" },
        { name = "RETAIL_CATALOG_PERSISTENCE_ENDPOINT", value = local.db_endpoint },
        { name = "RETAIL_CATALOG_PERSISTENCE_DB_NAME", value = "catalogdb" },
        { name = "RETAIL_CATALOG_PERSISTENCE_USER", value = var.db_username },
        { name = "RETAIL_CATALOG_PERSISTENCE_PASSWORD", value = var.db_password }
      ]
    }
    checkout = {
      cpu           = 256
      memory        = 512
      desired_count = 1
      environment_vars = [
        { name = "PORT", value = "8080" },
        { name = "RETAIL_CHECKOUT_PERSISTENCE_PROVIDER", value = "redis" },
        { name = "RETAIL_CHECKOUT_PERSISTENCE_REDIS_URL", value = "redis://redis:6379" },
        { name = "RETAIL_CHECKOUT_ENDPOINTS_ORDERS", value = "http://orders:8080" }
      ]
    }
    orders = {
      cpu           = 256
      memory        = 512
      desired_count = 1
      environment_vars = [
        { name = "GIN_MODE", value = "release" },
        { name = "RETAIL_ORDERS_PERSISTENCE_ENDPOINT", value = local.db_endpoint },
        { name = "RETAIL_ORDERS_PERSISTENCE_NAME", value = "orders" },
        { name = "RETAIL_ORDERS_PERSISTENCE_USERNAME", value = var.db_username },
        { name = "RETAIL_ORDERS_PERSISTENCE_PASSWORD", value = var.db_password }
      ]
    }
    ui = {
      cpu           = 256
      memory        = 512
      desired_count = 1
      environment_vars = [
        { name = "PORT", value = "8080" }
      ]
    }
  }
}

module "ecs" {
  source                = "../../modules/ecs"
  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  aws_account_id        = var.aws_account_id
  aws_region            = var.aws_region
  ecr_registry          = var.ecr_registry
  services              = local.services_with_db
  subnet_ids            = module.vpc.private_subnet_ids
  alb_security_group_id = module.alb.alb_security_group_id
  target_group_arns     = module.alb.target_group_arns
}

module "lambda" {
  source         = "../../modules/lambda"
  project_name   = var.project_name
  environment    = var.environment
  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region
}

