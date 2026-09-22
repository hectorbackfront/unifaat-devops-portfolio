locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Security Group generico - funciona para API, RDS, bastion, etc.
# As regras de entrada vem de var.ingress_rules; a saida e sempre liberada.
resource "aws_security_group" "this" {
  name        = var.name
  description = "Security group - ${var.name}"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description     = ingress.value.description
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      cidr_blocks     = length(ingress.value.cidr_blocks) > 0 ? ingress.value.cidr_blocks : null
      security_groups = length(ingress.value.security_groups) > 0 ? ingress.value.security_groups : null
    }
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = var.name
  })
}
