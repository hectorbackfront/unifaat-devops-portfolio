variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
}

variable "db_username" {
  description = "Usuario master do banco"
  type        = string
}

variable "db_password" {
  description = "Senha master do banco (definir via terraform.tfvars, nunca versionar)"
  type        = string
  sensitive   = true
}

variable "subnet_ids" {
  description = "Subnets privadas para o DB Subnet Group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security Group IDs aplicados ao RDS"
  type        = list(string)
}

variable "instance_class" {
  description = "Classe da instancia RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Armazenamento alocado (GB)"
  type        = number
  default     = 20
}

variable "engine_version" {
  description = "Versao do PostgreSQL"
  type        = string
  default     = "15"
}

variable "project_name" {
  description = "Nome do projeto (usado em nomes e tags)"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}
