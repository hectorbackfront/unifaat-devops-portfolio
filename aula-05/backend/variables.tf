variable "aws_region" {
  description = "Região AWS utilizada para o backend remoto"
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
