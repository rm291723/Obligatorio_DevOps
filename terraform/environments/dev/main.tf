terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "tf-state-rmenendez"
    key    = "retailstore/dev/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# 1. Módulo de Redes (Ahora incluye privadas)
module "vpc" {
  source               = "../../modules/vpc"
  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs # NUEVO
  availability_zones   = var.availability_zones
}

# 2. Módulo de Registros de Imagen
module "ecr" {
  source       = "../../modules/ecr"
  project_name = var.project_name
  environment  = var.environment
  services     = var.services_list
}

# 3. NUEVO: Módulo ALB para balancear el tráfico externo
module "alb" {
  source            = "../../modules/alb"
  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  service_names     = var.services_list
}

# 4. Módulo ECS conectado de forma segura al ALB y a las subnets privadas
module "ecs" {
  source         = "../../modules/ecs"
  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region
  ecr_registry   = var.ecr_registry
  services       = var.services

  # CORRECCIONES DE CONEXIÓN CRÍTICAS:
  subnet_ids            = module.vpc.private_subnet_ids    # Contenedores seguros en redes privadas
  alb_security_group_id = module.alb.alb_security_group_id # Restringe el SG de ECS
  target_group_arns     = module.alb.target_group_arns     # Vincula ECS con el ALB
}

# 5. Módulo Lambda Serverless
module "lambda" {
  source         = "../../modules/lambda"
  project_name   = var.project_name
  environment    = var.environment
  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region
}

