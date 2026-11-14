data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# No Learner Lab nao da para criar roles IAM, mas o instance profile
# LabInstanceProfile ja existe (LabRole, com acesso ao ECR).
data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}

resource "aws_security_group" "api" {
  name        = "${var.project_name}-sg"
  description = "SSH (deploy) e porta da API"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH do pipeline de deploy"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "API TechNova (health check)"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "deploy" {
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "api" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.api.id]
  key_name                    = aws_key_pair.deploy.key_name
  iam_instance_profile        = data.aws_iam_instance_profile.lab.name
  associate_public_ip_address = true

  # Deixa a maquina pronta para o deploy: so precisa do Docker.
  # O container em si e responsabilidade do pipeline cd.yml, nao do Terraform.
  user_data = <<-EOF
    #!/bin/bash
    set -e
    dnf install -y docker
    systemctl enable --now docker
    usermod -aG docker ec2-user
  EOF

  # A AMI "most_recent" muda com o tempo; sem isso todo plan proporia
  # destruir e recriar a instancia.
  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "${var.project_name}-api"
  }
}
