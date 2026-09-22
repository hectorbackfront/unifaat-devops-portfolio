# Infraestrutura TechNova — Aula 05 (RDS e Remote State)

Terraform que adiciona a camada de dados persistentes à infraestrutura da
TechNova: VPC com subnets públicas e privadas em 2 AZs, RDS PostgreSQL
gerenciado nas subnets privadas, EC2 na subnet pública conectando ao banco,
e state protegido em backend remoto (S3 + DynamoDB).

## Arquitetura

```text
                                Internet
                                    |
                          Internet Gateway
                                    |
                          Route Table pública
                                    |
                              us-east-1a
                        public 10.0.1.0/24
                                 |
                             EC2 (API)
                                 |  psql:5432 (SG -> SG)
                 -------------------------------------
                 |                                   |
           us-east-1a                          us-east-1b
     private-1 10.0.2.0/24                private-2 10.0.4.0/24
                 \_________________  _________________/
                                   \/
                          DB Subnet Group
                                   |
                        RDS PostgreSQL 15
                         (db.t3.micro, sem
                        rota para a internet)
```

State do Terraform:

```text
terraform apply/plan  --->  Backend S3 (versionado, AES256, sem acesso
                              público) + lock via DynamoDB (LockID)
```

## Pré-requisitos

- Terraform 1.5 ou superior
- AWS CLI configurada para o AWS Academy Learner Lab
  (`aws sts get-caller-identity` funcionando)
- Chave pública em `~/.ssh/technova-key.pub`
- Cliente `psql` instalado localmente é opcional — a EC2 já instala o dela

## Ordem de execução

### 1. Backend remoto (S3 + DynamoDB)

```bash
cd backend
terraform init
terraform apply
terraform output
```

Copie `s3_bucket_name` e `dynamodb_table_name` da saída acima.

### 2. Projeto principal

Edite `providers.tf` (bloco `backend "s3"`) substituindo `bucket` pelo
`s3_bucket_name` obtido no passo anterior (o `dynamodb_table` já usa o nome
padrão `technova-terraform-locks`).

```bash
cd ..
cp terraform.tfvars.example terraform.tfvars
# edite terraform.tfvars e defina uma senha forte em db_password

terraform init
terraform plan
terraform apply
```

> O `apply` do RDS leva 5-10 minutos — é normal.

### 3. Testar a conexão EC2 → RDS

```bash
ssh -i ~/.ssh/technova-key ec2-user@$(terraform output -raw ec2_public_ip)

# dentro da EC2
psql -h <rds_address> -U technova_admin -d technova -p 5432 -c "SELECT version();"
```

O `user_data` da EC2 já testa essa conexão automaticamente no boot e grava o
resultado em `/var/log/technova-db-test.log` (ver seção Decisões técnicas).

### 4. Criar tabela e provar persistência

```sql
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    product VARCHAR(100) NOT NULL,
    quantity INTEGER NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO orders (customer_name, product, quantity, total) VALUES
    ('Maria Silva', 'Laptop TechNova Pro', 1, 4599.90),
    ('João Santos', 'Monitor 27"', 2, 2398.00),
    ('Ana Costa', 'Teclado Mecânico', 3, 897.00);

SELECT * FROM orders;
```

Reinicie a EC2 (`aws ec2 reboot-instances --instance-ids <id>`) e reconecte —
os dados continuam no RDS, que é independente do ciclo de vida da EC2.

### 5. Evidência do state no S3

```bash
aws s3 ls s3://<bucket>/aula-05/
```

## Recursos criados

| Recurso | Função |
| --- | --- |
| VPC `10.0.0.0/16` | Rede isolada da TechNova |
| 1 subnet pública + 2 privadas | Pública hospeda a EC2; privadas (AZs diferentes) hospedam o RDS |
| Internet Gateway + Route Table pública | Saída da subnet pública |
| Security Group EC2 | SSH (22) e API (3000) abertos |
| Security Group RDS | PostgreSQL (5432) liberado só para o SG da EC2 |
| DB Subnet Group | Agrupa as 2 subnets privadas |
| RDS PostgreSQL 15 `db.t3.micro` | Banco gerenciado, criptografado, não público |
| EC2 `t2.micro` | Cliente psql instalado via user_data, testa conexão no boot |
| IAM Instance Profile | `LabInstanceProfile` pré-criado pelo AWS Academy |

## Decisões técnicas

- **Security Group do RDS por referência, não por CIDR** (bônus do
  enunciado): o ingress de 5432 aponta para o Security Group da EC2
  (`security_groups = [aws_security_group.ec2.id]`) em vez do CIDR da VPC
  inteira — só instâncias com esse SG alcançam o banco.
- **AES256 em vez de SSE-KMS no bucket de state**: o Academy Learner Lab
  normalmente bloqueia `kms:CreateKey` para o `LabRole`; AES256 (SSE-S3)
  cumpre "encriptação server-side habilitada" sem essa dependência.
- **Sem IAM Role customizada**: o Learner Lab não permite criar Roles/Instance
  Profiles pelo Terraform, então a EC2 reutiliza o `LabInstanceProfile`
  (mesma abordagem da Aula 04).
- **`backup_retention_period = 0`**: desliga backups automáticos do RDS para
  simplificar e agilizar um recurso que será destruído ao final do lab.
- **User data testa a conexão automaticamente** (bônus do enunciado): a EC2
  instala `postgresql15`, espera o RDS ficar acessível e roda um `SELECT
  version()` em loop (até 20 tentativas de 30s), gravando o log em
  `/var/log/technova-db-test.log`. A senha só existe na memória/log dessa
  instância efêmera, destruída ao final do lab.
- **Duas fases de Terraform** (`backend/` e raiz): um backend remoto não pode
  guardar o próprio state antes de existir, por isso o backend é criado com
  state local e só depois referenciado pelo projeto principal.

## Evidências

### 1. State remoto funcional

```text
$ aws s3 ls s3://technova-terraform-state-16d6db44/aula-05/
2026-09-22 20:06:35      37844 terraform.tfstate
```

### 2. Conexão EC2 → RDS

Log gravado automaticamente pelo `user_data` em `/var/log/technova-db-test.log`:

```text
=== Teste automatico de conexao EC2 -> RDS ===
Tue Sep 22 23:07:00 UTC 2026
                                              version
---------------------------------------------------------------------------------------------------
 PostgreSQL 15.17 on x86_64-pc-linux-gnu, compiled by x86_64-pc-linux-gnu-gcc (GCC) 12.4.0, 64-bit
(1 row)

Conexao OK na tentativa 1
```

### 3. Dados persistentes

```text
$ psql -h technova-db.ccohlsah3nwe.us-east-1.rds.amazonaws.com -U technova_admin -d technova -p 5432 -c "SELECT * FROM orders;"

 id | customer_name |       product       | quantity |  total  |        created_at
----+---------------+---------------------+----------+---------+----------------------------
  1 | Maria Silva   | Laptop TechNova Pro |        1 | 4599.90 | 2026-09-22 23:07:29.28899
  2 | Joao Santos   | Monitor 27          |        2 | 2398.00 | 2026-09-22 23:07:29.28899
  3 | Ana Costa     | Teclado Mecanico    |        3 |  897.00 | 2026-09-22 23:07:29.28899
(3 rows)
```

### 4. Terraform plan limpo

```text
$ terraform plan

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
```

## Cleanup

```bash
# 1. Infraestrutura principal
terraform destroy

# 2. Esvaziar e destruir o backend
cd backend
BUCKET=$(terraform output -raw s3_bucket_name)
aws s3api list-object-versions --bucket "$BUCKET" \
  --query 'Versions[].{Key:Key,VersionId:VersionId}' --output text | \
  while read -r key version; do
    aws s3api delete-object --bucket "$BUCKET" --key "$key" --version-id "$version"
  done
terraform destroy
```
