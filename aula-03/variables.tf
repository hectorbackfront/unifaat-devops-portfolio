variable "aws_region" {
  description = "Região AWS onde os recursos IAM serão criados"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto ao qual os recursos pertencem"
  type        = string
  default     = "TechNova"
}

variable "environment" {
  description = "Ambiente de execução (lab, dev, prod)"
  type        = string
  default     = "lab"
}

variable "aluno" {
  description = "Nome do aluno responsável pelos recursos"
  type        = string
  default     = "Hector Marcelo Pedroso dos Santos"
}

variable "ra" {
  description = "RA do aluno - prefixo dos recursos para evitar colisão na conta compartilhada"
  type        = string
  default     = "6125136"
}

variable "disciplina" {
  description = "Disciplina da entrega"
  type        = string
  default     = "DevOps - UniFAAT 2026-2"
}

variable "aula" {
  description = "Número da aula"
  type        = string
  default     = "03"
}

locals {
  prefix = "${var.ra}-technova"

  common_tags = {
    Project    = var.project_name
    ManagedBy  = "Terraform"
    Aluno      = var.aluno
    RA         = var.ra
    Disciplina = var.disciplina
    Aula       = var.aula
  }
}
