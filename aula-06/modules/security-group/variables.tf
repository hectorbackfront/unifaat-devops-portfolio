variable "name" {
  description = "Nome do Security Group"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC onde o Security Group sera criado"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto (usado em tags)"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "ingress_rules" {
  description = "Lista de regras de entrada. Use cidr_blocks OU security_groups como origem."
  type = list(object({
    description     = string
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string), [])
    security_groups = optional(list(string), [])
  }))
  default = []
}
