# Tabela de lock do Terraform state.
# O nome do atributo/partition key precisa ser exatamente "LockID" (String)
# porque é esse o nome que o backend "s3" do Terraform usa internamente.
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-terraform-locks"
  }
}
