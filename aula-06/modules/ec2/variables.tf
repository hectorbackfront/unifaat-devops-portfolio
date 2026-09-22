variable "instance_name" {
  description = "Nome da instancia (tag Name)"
  type        = string
}

variable "instance_type" {
  description = "Tipo da instancia EC2"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID a ser utilizada"
  type        = string
}

variable "subnet_id" {
  description = "ID da subnet onde a instancia sera criada"
  type        = string
}

variable "security_group_ids" {
  description = "Lista de Security Group IDs associados a instancia"
  type        = list(string)
}

variable "key_name" {
  description = "Nome do Key Pair para acesso SSH"
  type        = string
}

variable "user_data" {
  description = "Script de inicializacao da instancia (opcional)"
  type        = string
  default     = null
}

variable "associate_public_ip" {
  description = "Se a instancia recebe IP publico"
  type        = bool
  default     = true
}

variable "project_name" {
  description = "Nome do projeto (usado em tags)"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}
