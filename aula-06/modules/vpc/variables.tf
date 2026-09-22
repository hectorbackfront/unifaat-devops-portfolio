variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto (usado em nomes e tags)"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "subnets" {
  description = "Mapa de subnets a criar. Chave = nome logico da subnet."
  type = map(object({
    cidr = string
    az   = string
    type = string # "public" ou "private"
  }))
}
