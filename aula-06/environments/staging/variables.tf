variable "aws_region" {
  description = "Regiao AWS utilizada no laboratorio"
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "RA do aluno"
  type        = string
  default     = "6125136"
}

variable "project_name" {
  description = "Nome do projeto (usado em nomes e tags)"
  type        = string
  default     = "technova"
}

variable "environment" {
  description = "Nome deste ambiente"
  type        = string
  default     = "staging"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC deste ambiente"
  type        = string
  default     = "10.1.0.0/16"
}

variable "key_name" {
  description = "Nome do Key Pair da EC2"
  type        = string
  default     = "technova-key"
}

variable "db_password" {
  description = "Senha do banco de dados RDS (definir em terraform.tfvars, nunca versionar)"
  type        = string
  sensitive   = true
}
