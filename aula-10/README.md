# Aula 10 — Terraform GitOps + CD Pipeline

Infra via PR (plan no PR, apply no merge) e deploy continuo da API TechNova numa EC2, tudo no AWS Academy Learner Lab (`us-east-1`).

## Estrutura

```
aula-10/
├── technova-api/          # app Node + Dockerfile multi-stage (contexto do build)
├── terraform/             # SG + key pair + EC2 com Docker (backend S3 proprio)
├── docs/runbook-rollback.md
├── gitops-cd-analise.md
└── screenshots/
.github/workflows/         # na RAIZ do repo (o GitHub so le workflows daqui)
├── terraform-plan.yml     # PR -> fmt, init, validate, plan, comentario no PR
├── terraform-apply.yml    # merge na main/master -> apply -auto-approve
└── cd.yml                 # lint + test -> build/push ECR -> deploy SSH -> health check
```

> Os workflows ficam em `.github/workflows/` da raiz do repositorio, nao em `aula-10/.github/`, porque o GitHub Actions ignora workflows em subpastas.

## Secrets necessarios (Settings > Secrets and variables > Actions)

| Secret | Origem |
|---|---|
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | Learner Lab > AWS Details. **Expiram a cada sessao: atualize antes de rodar.** |
| `TF_VAR_SSH_PUBLIC_KEY` | conteudo de `chave.pub` (vira a variavel `ssh_public_key`) |
| `EC2_SSH_KEY` | conteudo da chave privada `chave` (par da publica acima) |
| `EC2_HOST` | IP publico da EC2 (output `public_ip` do apply) |

Pre-requisito (criado uma vez na mao, o Terraform nao cria o proprio backend): bucket `technova-tfstate-6125136` e tabela DynamoDB `technova-terraform-locks`. Se o Lab for resetado eles somem: recrie com `aws s3api create-bucket` e `aws dynamodb create-table` (ver `terraform/provider.tf`).

## Como reproduzir

1. `ssh-keygen -t ed25519 -f chave -N ""` e cadastre os secrets acima (menos `EC2_HOST`).
2. Abra um PR alterando algo em `aula-10/terraform/*.tf`: o bot comenta o plan.
3. Faca merge: o `terraform-apply.yml` cria a infra. Copie o `public_ip` do final do log para o secret `EC2_HOST`.
4. Qualquer push em `aula-10/technova-api/**` na `main` (ou *Run workflow* manual) dispara o `cd.yml`.
5. Valide: `curl http://<EC2_HOST>:3000/health`.

## Bonus implementados

`terraform fmt -check`; comentario do plan atualizado (nao duplicado); aviso quando o plan contem destroy; imagem rastreavel por SHA e `GIT_SHA` no container.
