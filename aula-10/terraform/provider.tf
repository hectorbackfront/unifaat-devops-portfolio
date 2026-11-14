terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # State remoto (reaproveita o bucket + tabela de lock criados na Aula 05).
  # Em GitOps o state PRECISA ser remoto: o runner do GitHub Actions e efemero,
  # entao o state local seria perdido entre o plan (PR) e o apply (merge).
  backend "s3" {
    bucket         = "technova-terraform-state-16d6db44"
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
