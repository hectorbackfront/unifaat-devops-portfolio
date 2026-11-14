variable "aws_region" {
  description = "Regiao AWS do Learner Lab"
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "RA do aluno"
  type        = string
  default     = "6125136"
}

variable "project_name" {
  description = "Prefixo usado nos nomes dos recursos"
  type        = string
  default     = "technova-cd"
}

variable "instance_type" {
  description = "Tipo da instancia que roda o container"
  type        = string
  default     = "t2.micro"
}

variable "app_port" {
  description = "Porta publica da API"
  type        = number
  default     = 3000
}

variable "ssh_allowed_cidr" {
  description = "CIDR com acesso SSH. O runner do GitHub Actions nao tem IP fixo, por isso 0.0.0.0/0 (aceitavel so no Lab)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_public_key" {
  description = "Chave publica SSH da EC2 (par da chave privada guardada no secret EC2_SSH_KEY). Vem do secret TF_VAR_ssh_public_key"
  type        = string
}
