output "s3_bucket_name" {
  description = "Nome do bucket S3 usado como backend remoto do state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "ARN do bucket S3 do backend remoto"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB usada para lock do state"
  value       = aws_dynamodb_table.terraform_locks.name
}
