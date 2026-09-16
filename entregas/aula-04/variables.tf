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

variable "availability_zones" {
  description = "Duas Availability Zones utilizadas na arquitetura Multi-AZ"
  type        = list(string)

  default = [
    "us-east-1a",
    "us-east-1b"
  ]

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

variable "api_repository" {
  description = "Repositorio Git da API TechNova"
  type        = string
  default     = "https://github.com/AleTavares/devops_20262.git"
}

variable "iam_instance_profile_name" {
  description = "Instance Profile pre-criado pelo AWS Academy"
  type        = string
  default     = "LabInstanceProfile"
}
