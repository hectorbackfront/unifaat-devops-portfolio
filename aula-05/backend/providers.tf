terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Este projeto CRIA o backend remoto (S3 + DynamoDB).
  # Por isso o state dele fica local — não há como um backend
  # referenciar a si mesmo antes de existir.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project    = "TechNova"
      Purpose    = "Terraform Remote State"
      ManagedBy  = "Terraform"
      Owner      = var.owner
      Disciplina = "DevOps"
      Aula       = "05"
    }
  }
}
