terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote State — backend S3 + DynamoDB (criado em ./backend).
  # Os valores de bucket/dynamodb_table são os outputs de `terraform apply`
  # rodado dentro da pasta backend/. Depois de preencher, rode:
  #   terraform init -migrate-state
  backend "s3" {
    bucket         = "technova-terraform-state-16d6db44"
    key            = "aula-05/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "technova-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "TechNova"
      Environment = "development"
      ManagedBy   = "Terraform"
      Owner       = var.owner
      Disciplina  = "DevOps"
      Aula        = "05"
    }
  }
}
