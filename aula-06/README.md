# Biblioteca de Módulos Terraform — Aula 06 (TechNova)

Biblioteca de módulos Terraform reutilizáveis para a TechNova, capaz de
provisionar ambientes completos (VPC, Security Groups, EC2 e RDS) a partir
de uma única composição de módulos. Dois ambientes — `dev` e `staging` —
são criados a partir dos mesmos módulos, apenas com variáveis diferentes.

## Visão geral

Em vez de duplicar código Terraform por ambiente, cada peça de infraestrutura
(rede, segurança, servidor, banco) vira um módulo isolado, testável e
documentado. Os ambientes (`environments/dev`, `environments/staging`) são
"root modules" finos que apenas chamam os módulos com os parâmetros certos —
toda a lógica de criação de recursos vive uma única vez em `modules/`.

## Arquitetura

```text
                        modules/vpc
                    (VPC, subnets dinamicas via
                     for_each, IGW, route table)
                              |
                 vpc_id  |         |  public_subnet_ids / private_subnet_ids
                          v         v
              modules/security-group           modules/ec2
              (SG generico, regras                  |
               por lista de objetos)                |
                    |         |                      |
             sg_id  |         | sg_id (RDS SG        |
                     v         v  aceita o SG da API) |
                 modules/ec2               modules/rds
              (instancia API)         (DB Subnet Group + RDS)
```

Composição efetiva usada em `environments/*/main.tf`:

- `module.vpc.vpc_id` → input de `module.api_sg` e `module.rds_sg`
- `module.vpc.public_subnet_ids[0]` → input de `module.api_server`
- `module.vpc.private_subnet_ids` → input de `module.database`
- `module.api_sg.sg_id` → input de `module.api_server` **e** de `module.rds_sg`
  (o SG do RDS só libera a porta 5432 para quem tiver o SG da API — mesmo
  princípio de menor privilégio usado na Aula 05)
- `module.rds_sg.sg_id` → input de `module.database`

## Módulos disponíveis

### Módulo VPC (`modules/vpc/`)

**Descrição:** Cria VPC completa com subnets dinâmicas (`for_each`), Internet
Gateway e Route Table pública. As subnets privadas não recebem rota para a
internet.

**Inputs:**
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| vpc_cidr | string | Sim | CIDR block da VPC |
| project_name | string | Sim | Nome do projeto (usado em nomes e tags) |
| environment | string | Sim | Ambiente (dev, staging, prod) |
| subnets | map(object({cidr, az, type})) | Sim | Mapa de subnets a criar |

**Outputs:**
| Nome | Descrição |
|------|-----------|
| vpc_id | ID da VPC criada |
| public_subnet_ids | Lista de IDs das subnets públicas |
| private_subnet_ids | Lista de IDs das subnets privadas |

**Exemplo de uso:**
```hcl
module "vpc" {
  source       = "../../modules/vpc"
  vpc_cidr     = "10.0.0.0/16"
  project_name = "technova"
  environment  = "dev"
  subnets = {
    "public-1"  = { cidr = "10.0.1.0/24", az = "us-east-1a", type = "public" }
    "private-1" = { cidr = "10.0.3.0/24", az = "us-east-1a", type = "private" }
  }
}
```

### Módulo Security Group (`modules/security-group/`)

**Descrição:** Security Group genérico — funciona para API, RDS, bastion ou
qualquer outro caso. As regras de entrada são uma lista de objetos; cada
regra pode ter origem por `cidr_blocks` **ou** por `security_groups`. A saída
(egress) é sempre liberada para todo o tráfego.

**Inputs:**
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| name | string | Sim | Nome do Security Group |
| vpc_id | string | Sim | ID da VPC |
| project_name | string | Sim | Nome do projeto (usado em tags) |
| environment | string | Sim | Ambiente |
| ingress_rules | list(object) | Não (default `[]`) | Regras de entrada |

**Outputs:**
| Nome | Descrição |
|------|-----------|
| sg_id | ID do Security Group criado |

**Exemplo de uso:**
```hcl
module "rds_sg" {
  source       = "../../modules/security-group"
  name         = "technova-dev-rds-sg"
  vpc_id       = module.vpc.vpc_id
  project_name = "technova"
  environment  = "dev"
  ingress_rules = [
    {
      description     = "PostgreSQL apenas da API"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [module.api_sg.sg_id]
    }
  ]
}
```

### Módulo EC2 (`modules/ec2/`)

**Descrição:** Cria uma instância EC2 reutilizável, com AMI, tipo, subnet,
Security Groups e `user_data` configuráveis.

**Inputs:**
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| instance_name | string | Sim | Nome da instância (tag Name) |
| instance_type | string | Não (default `t2.micro`) | Tipo da instância |
| ami_id | string | Sim | AMI ID |
| subnet_id | string | Sim | Subnet onde a instância é criada |
| security_group_ids | list(string) | Sim | Security Group IDs |
| key_name | string | Sim | Nome do Key Pair |
| user_data | string | Não (default `null`) | Script de inicialização |
| associate_public_ip | bool | Não (default `true`) | Se recebe IP público |
| project_name | string | Sim | Nome do projeto (tags) |
| environment | string | Sim | Ambiente |

**Outputs:**
| Nome | Descrição |
|------|-----------|
| instance_id | ID da instância criada |
| public_ip | IP público da instância |
| private_ip | IP privado da instância |

**Exemplo de uso:**
```hcl
module "api_server" {
  source              = "../../modules/ec2"
  instance_name       = "technova-dev-api"
  ami_id              = data.aws_ami.amazon_linux.id
  subnet_id           = module.vpc.public_subnet_ids[0]
  security_group_ids  = [module.api_sg.sg_id]
  key_name            = "technova-key"
  project_name        = "technova"
  environment         = "dev"
}
```

### Módulo RDS (`modules/rds/`)

**Descrição:** Cria um DB Subnet Group a partir de subnets privadas e uma
instância RDS PostgreSQL com configurações adequadas para laboratório
(`skip_final_snapshot`, sem backups, storage encriptado).

**Inputs:**
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| db_name | string | Sim | Nome do banco de dados |
| db_username | string | Sim | Usuário master |
| db_password | string (sensitive) | Sim | Senha master |
| subnet_ids | list(string) | Sim | Subnets privadas para o DB Subnet Group |
| security_group_ids | list(string) | Sim | Security Group IDs do RDS |
| instance_class | string | Não (default `db.t3.micro`) | Classe da instância |
| allocated_storage | number | Não (default `20`) | Armazenamento em GB |
| engine_version | string | Não (default `15`) | Versão do PostgreSQL |
| project_name | string | Sim | Nome do projeto (tags) |
| environment | string | Sim | Ambiente |

**Outputs:**
| Nome | Descrição |
|------|-----------|
| db_endpoint | Endpoint de conexão (host:porta) |
| db_name | Nome do banco de dados |
| db_port | Porta do RDS |

**Exemplo de uso:**
```hcl
module "database" {
  source              = "../../modules/rds"
  db_name             = "technova_dev"
  db_username         = "technova_admin"
  db_password         = var.db_password
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [module.rds_sg.sg_id]
  project_name        = "technova"
  environment         = "dev"
}
```

## Ambientes

| Aspecto | Dev | Staging |
| --- | --- | --- |
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 |
| Subnets públicas | 10.0.1.0/24, 10.0.2.0/24 | 10.1.1.0/24, 10.1.2.0/24 |
| Subnets privadas | 10.0.3.0/24, 10.0.4.0/24 | 10.1.3.0/24, 10.1.4.0/24 |
| EC2 | t2.micro | t2.micro |
| RDS | db.t3.micro | db.t3.micro |
| DB Name | technova_dev | technova_staging |
| Naming pattern | technova-dev-* | technova-staging-* |

Os dois ambientes chamam exatamente os mesmos 4 módulos (`vpc`,
`security-group` x2, `ec2`, `rds`); a única diferença entre
`environments/dev/main.tf` e `environments/staging/main.tf` são os valores
de CIDR e o `environment` usado nos nomes/tags.

## Como usar (criar um novo ambiente)

1. Copie a pasta de um ambiente existente (`cp -r environments/dev environments/novo-ambiente`)
2. Ajuste `vpc_cidr`, os CIDRs das subnets em `main.tf` e o `environment` em `variables.tf`
3. `cp terraform.tfvars.example terraform.tfvars` e preencha `db_password`
   (sem os caracteres `@`, `/`, `"` ou espaço — não são aceitos pelo RDS)
4. `terraform init && terraform validate && terraform plan`

## Pré-requisitos

- Terraform 1.5 ou superior
- AWS CLI configurada para o AWS Academy Learner Lab
  (`aws sts get-caller-identity` funcionando)
- Key Pair `technova-key` (só necessário para `terraform apply`; `plan` e
  `validate` não exigem que a chave já exista na AWS)

## Validação local

> Não é obrigatório rodar `terraform apply` — o requisito é `terraform
> validate` e `terraform plan` sem erros nos dois ambientes.

```bash
# Ambiente dev
cd environments/dev
terraform init
terraform validate
terraform plan

# Ambiente staging
cd ../staging
terraform init
terraform validate
terraform plan
```

## Evidência do terraform plan

### Ambiente dev

```text
Plan: 14 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + api_public_ip      = (known after apply)
  + db_endpoint        = (known after apply)
  + db_name            = "technova_dev"
  + private_subnet_ids = [ (known after apply), (known after apply) ]
  + public_subnet_ids  = [ (known after apply), (known after apply) ]
  + vpc_id             = (known after apply)
```

### Ambiente staging

```text
Plan: 14 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + api_public_ip      = (known after apply)
  + db_endpoint        = (known after apply)
  + db_name            = "technova_staging"
  + private_subnet_ids = [ (known after apply), (known after apply) ]
  + public_subnet_ids  = [ (known after apply), (known after apply) ]
  + vpc_id             = (known after apply)
```

## Decisões técnicas

- **SG do RDS por referência ao SG da API**, não por CIDR — mesmo princípio
  de menor privilégio da Aula 05, agora generalizado no módulo
  `security-group` via `security_groups` na regra de ingress.
- **`optional()` nos atributos de `ingress_rules`** (`cidr_blocks` e
  `security_groups` com default `[]`) para permitir que uma regra use
  qualquer uma das duas origens sem obrigar a outra a ser declarada.
- **AMI resolvida no root module (`environments/*/main.tf`)**, não dentro do
  módulo EC2 — mantém o módulo genérico e deixa a escolha de imagem a cargo
  de quem consome o módulo.
- **Sem `apply` neste TF**: só `validate`/`plan`, para não consumir os
  recursos limitados do Learner Lab com dois ambientes simultâneos.

## Cleanup (caso tenha feito apply para testar)

```bash
cd environments/dev
terraform destroy

cd ../staging
terraform destroy
```
