variable "aws_region" {
  description = "Região AWS utilizada no laboratório"
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

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Duas Availability Zones utilizadas pelas subnets privadas (DB Subnet Group)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Informe exatamente duas Availability Zones."
  }
}

variable "key_name" {
  description = "Nome do Key Pair da EC2"
  type        = string
  default     = "technova-key"
}

variable "ssh_public_key_path" {
  description = "Caminho da chave pública SSH"
  type        = string
  default     = "~/.ssh/technova-key.pub"
}

variable "iam_instance_profile_name" {
  description = "Instance Profile pré-criado pelo AWS Academy"
  type        = string
  default     = "LabInstanceProfile"
}

# --- Banco de dados (RDS) ---

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "technova"
}

variable "db_username" {
  description = "Username do banco de dados RDS"
  type        = string
  default     = "technova_admin"
}

variable "db_password" {
  description = "Password do banco de dados RDS (definir em terraform.tfvars, nunca versionar)"
  type        = string
  sensitive   = true
}
