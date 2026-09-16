# Infraestrutura TechNova — Aula 04

Terraform para uma VPC Multi-AZ com duas subnets públicas, duas privadas e uma
instância EC2 pública executando a API Node.js da Aula 01.

## Arquitetura

```text
								 Internet
									  |
						  Internet Gateway
									  |
						  Route Table pública
							  /               \
				  us-east-2a             us-east-2b
			  public-a 10.0.1.0/24    public-b 10.0.3.0/24
					 |                       |
				 EC2/API                 (futura EC2)
                             
			  private-a 10.0.2.0/24  private-b 10.0.4.0/24
				 Route Table padrão, sem rota para a internet
```

## Pré-requisitos

- Terraform 1.5 ou superior
- AWS CLI configurada para o AWS Academy Learner Lab
- Chave pública em `~/.ssh/technova-key.pub`

## Como usar

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Depois do `apply`, teste a API:

```bash
curl "$(terraform output -raw api_url)"
curl "$(terraform output -raw api_url)/health"
terraform output -raw ssh_command
ssh -i ~/.ssh/technova-key ec2-user@$(terraform output -raw ec2_public_ip) \
	"node --version && aws sts get-caller-identity"
```

### Evidências de funcionamento

Comandos executados e saídas verificadas no ambiente real do laboratório:

```bash
terraform output
curl -sS "$(terraform output -raw api_url)"
curl -sS "$(terraform output -raw api_url)/health"
```

Saída de `terraform output`:

```text
api_security_group_id = "sg-090a0369dad90c564"
api_url = "http://18.212.226.95:3000"
db_security_group_id = "sg-03aa7a7a8f3ad4916"
ec2_public_ip = "18.212.226.95"
private_subnet_ids = [
  "subnet-0c15a9a0e9f24f404",
  "subnet-07b159412ffd80eb5",
]
public_subnet_ids = [
  "subnet-0caf1d0369d06dd08",
  "subnet-08fd72fb3ff078fda",
]
ssh_command = "ssh -i /home/hector/.ssh/technova-key ec2-user@18.212.226.95"
vpc_id = "vpc-02e54112cec8998e2"
```

Resposta do endpoint principal:

```json
{"servico":"DevOps Portfolio API","aluno":"SEU NOME AQUI","ra":"SEU RA AQUI","aula":"01 - Fundamentos de Git e Docker","status":"online","timestamp":"2026-09-16T23:47:16.663Z"}
```

Resposta do health check:

```json
{"status":"healthy","uptime":185.624119763,"version":"1.0.0"}
```

O User Data clona `https://github.com/AleTavares/devops_20262.git` e inicia a
aplicação em `entregas/aula-01/aula-01/app` com `npm start`.

## Recursos criados

| Recurso | Função |
| --- | --- |
| VPC | Rede `10.0.0.0/16` com DNS habilitado |
| 4 subnets | Duas públicas e duas privadas em duas AZs |
| Internet Gateway | Saída das subnets públicas |
| Route Table pública | Rota `0.0.0.0/0` para o IGW |
| Security Groups | Regras da API e do banco futuro |
| EC2 `t2.micro` | Execução da API Node.js |
| IAM Instance Profile | Perfil `LabInstanceProfile` pre-criado pelo AWS Academy |

As tags comuns são aplicadas pelo `default_tags` do provider. As subnets
privadas permanecem sem rota para a internet, prontas para uma camada de banco
ou NAT Gateway em uma evolução futura.

## Decisões técnicas

- As duas Availability Zones reduzem o impacto de uma falha isolada e deixam a
	rede pronta para um Load Balancer futuro.
- As subnets públicas hospedam a API e têm acesso pelo Internet Gateway; as
	privadas ficam separadas para componentes internos, sem rota direta para a
	internet.
- O Security Group do banco aceita PostgreSQL somente dentro do CIDR da VPC.
- A EC2 usa o perfil `LabRole` do Academy, sem credenciais estáticas no User
	Data. O perfil `LabInstanceProfile` é reutilizado porque o Learner Lab não permite criar Roles
	IAM pelo Terraform.

## Evidências e limpeza

```bash
terraform plan > terraform-plan-output.txt
curl "$(terraform output -raw api_url)" > evidencia-api.json
curl "$(terraform output -raw api_url)/health" >> evidencia-api.json
terraform destroy
```
