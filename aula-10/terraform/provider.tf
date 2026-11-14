terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # State remoto (bucket + tabela de lock criados uma vez na mao, pois o Terraform nao cria o proprio backend).
  # Em GitOps o state PRECISA ser remoto: o runner do GitHub Actions e efemero,
  # entao o state local seria perdido entre o plan (PR) e o apply (merge).
  backend "s3" {
    bucket         = "technova-tfstate-6125136"
    key            = "aula-10/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "technova-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project    = "TechNova"
      ManagedBy  = "Terraform-GitOps"
      Owner      = var.owner
      Disciplina = "DevOps"
      Aula       = "10"
    }
  }
}
