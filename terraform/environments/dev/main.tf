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

module "vpc" {
  source = "../../modules/vpc"

  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  availability_zones  = var.availability_zones
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
  services     = var.services_list
}

module "ecs" {
  source = "../../modules/ecs"

  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.public_subnet_ids
  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region
  ecr_registry   = var.ecr_registry
  services       = var.services
}

module "lambda" {
  source = "../../modules/lambda"

  project_name   = var.project_name
  environment    = var.environment
  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region
}
