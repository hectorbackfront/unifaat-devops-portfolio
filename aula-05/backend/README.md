# Backend Remoto — S3 + DynamoDB (Aula 05)

Infraestrutura que armazena o Terraform state da TechNova de forma segura e
compartilhada: bucket S3 (versionado, encriptado, sem acesso público) e
tabela DynamoDB para lock de escrita concorrente.

Este projeto é independente do projeto principal (`../`) e **precisa ser
aplicado primeiro** — o state dele fica local, pois um backend não pode
referenciar a si mesmo antes de existir.

## Recursos criados

| Recurso | Configuração |
| --- | --- |
| `aws_s3_bucket` | Nome único via `random_id`, versionamento habilitado |
| `aws_s3_bucket_server_side_encryption_configuration` | SSE-S3 (AES256) |
| `aws_s3_bucket_public_access_block` | Todas as 4 flags = `true` |
| `aws_dynamodb_table` | Partition key `LockID` (String), `PAY_PER_REQUEST` |

> **Nota sobre encriptação:** o enunciado sugere SSE-KMS. Optamos por
> SSE-S3 (AES256) porque o AWS Academy Learner Lab normalmente bloqueia
> `kms:CreateKey` para o `LabRole`. AES256 já satisfaz o requisito de
> "encriptação server-side habilitada" sem depender de permissões extras.

## Como usar

```bash
cd aula-05/backend
terraform init
terraform plan
terraform apply
```

Anote os outputs — serão usados no `providers.tf` do projeto principal:

```bash
terraform output
# s3_bucket_name      = "technova-terraform-state-xxxxxxxx"
# s3_bucket_arn       = "arn:aws:s3:::technova-terraform-state-xxxxxxxx"
# dynamodb_table_name = "technova-terraform-locks"
```

## Cleanup (ao final do lab)

O bucket versionado não pode ser destruído com objetos dentro. Antes do
`terraform destroy`, esvazie todas as versões:

```bash
BUCKET=$(terraform output -raw s3_bucket_name)

aws s3api list-object-versions --bucket "$BUCKET" \
  --query 'Versions[].{Key:Key,VersionId:VersionId}' --output text | \
  while read -r key version; do
    aws s3api delete-object --bucket "$BUCKET" --key "$key" --version-id "$version"
  done

aws s3api list-object-versions --bucket "$BUCKET" \
  --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output text | \
  while read -r key version; do
    aws s3api delete-object --bucket "$BUCKET" --key "$key" --version-id "$version"
  done

terraform destroy
```
