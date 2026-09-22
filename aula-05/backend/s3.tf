# Sufixo aleatório para o nome do bucket ser globalmente único
resource "random_id" "state_bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${random_id.state_bucket_suffix.hex}"

  # Lab: prevent_destroy = false para permitir "terraform destroy" ao final.
  # Em produção, o recomendado é true.
  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = "${var.project_name}-terraform-state"
  }
}

# Versionamento: permite recuperar/rollback de versões anteriores do state
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encriptação server-side (SSE-S3/AES256).
# Optamos por AES256 em vez de SSE-KMS para não depender de permissões de
# kms:CreateKey, normalmente bloqueadas no AWS Academy Learner Lab.
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block Public Access — as 4 configurações ativadas
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
