# Runbook — Rollback da API TechNova

Cada deploy publica a imagem com a tag `sha-<7 primeiros chars do commit>` (alem de `latest`).
Fazer rollback = subir de novo uma tag SHA anterior, que continua no ECR.

## 1. Descobrir a tag anterior

```bash
aws ecr describe-images --repository-name technova-api --region us-east-1 \
  --query 'sort_by(imageDetails,&imagePushedAt)[].{tags:imageTags,pushed:imagePushedAt}' --output table
```

## 2. Opcao A — pelo GitHub (preferida, deixa rastro)

`git revert <sha-ruim>` e push na `main`: o `cd.yml` roda de novo e faz o deploy do codigo anterior.

## 3. Opcao B — manual na EC2 (emergencia)

Credenciais do Lab ativas (`aws sts get-caller-identity` funciona), depois:

```bash
ssh -i chave.pem ec2-user@<EC2_HOST>

TAG=sha-abc1234                       # tag boa, do passo 1
REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# 1) login no ECR ANTES do pull
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REGISTRY

# 2) Recreate com a versao antiga
docker stop technova-api || true
docker rm technova-api || true
docker pull $REGISTRY/technova-api:$TAG
docker run -d --name technova-api --restart unless-stopped -p 3000:3000 $REGISTRY/technova-api:$TAG
```

## 4. Validar

```bash
curl -fsS http://<EC2_HOST>:3000/health     # deve devolver {"status":"ok",...}
docker ps --filter name=technova-api        # imagem com a tag esperada
```

## Problemas comuns

| Sintoma | Causa | Solucao |
|---|---|---|
| `no basic auth credentials` no pull | esqueceu o login no ECR | refaca o passo 1 do bloco B |
| `token has expired` / `ExpiredToken` | sessao do Lab expirou | reabra o Learner Lab; atualize os 3 secrets |
| `manifest unknown` | tag nao existe (lifecycle policy removeu) | escolha outra tag do passo 1 |
| health check sem resposta | Security Group sem porta 3000 | confira `aws_security_group.api` |

> Testado em 2026-11-14: `sha-01aee39` -> `sha-8a0d4fd` -> `sha-01aee39`, `/health` ok nas duas.

> Obs: o rollback manual cria divergencia entre o que roda e o que esta na `main`. Depois, faca o `git revert` (opcao A) para o repositorio voltar a refletir a producao.
