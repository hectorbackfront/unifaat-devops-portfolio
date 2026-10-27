# Aula 09 — Docker Registry e IA no CI/CD

Projeto: pipeline da TechNova API que builda, publica no **Amazon ECR** e faz **AI review** em Pull Requests.
Ambiente: AWS Academy Learner Lab, região `us-east-1`. Credenciais do Lab expiram a cada sessão.

## Checklist (do TF da aula 09)

### 1. Build e push no ECR (40%)
- [x] `ecr-push.sh`: garante o repo `technova-api` (idempotente), login no ECR, build multi-stage e push
- [x] Tags: `sha-XXXXXXX`, `latest` e semver (`1.2.3`, `1.2`, `1`) a partir de git tag `v*.*.*`
- [x] Pull por tag funcionando (rollback)
- [ ] (opcional) `.github/workflows/ci.yml` com `aws-actions/configure-aws-credentials@v4` + `amazon-ecr-login@v2` — **criado, ainda não executado** (roda em tag `v*.*.*` ou manualmente; precisa dos 3 secrets do Lab, que expiram a cada sessão)

### 2. AI Review (30%)
- [x] Workflow em `pull_request` (opened, synchronize, reopened) — `.github/workflows/ai-review.yml` (na raiz do repositório, único lugar que o GitHub executa)
- [x] `aula-09/.github/scripts/ai-review.js` detecta: secrets hardcoded, `eval()`, SQL injection, `console.log`, `catch` vazio
- [x] Comentário no PR em tabela, por severidade

### 3. Quality gate (10%)
- [x] CRITICAL => `exit 1` (bloqueia o PR); WARNING/INFO => passa

### 4. Documentação e evidências (20%)
- [x] `ia-cicd-analise.md` (por que ECR, estratégia de tags, padrões, prompt/lógica, quando confiar na IA, limitações)
- [x] `screenshots/ecr-console.png` — repositório com as tags
- [x] `screenshots/ai-review-comment.png` — comentário no PR
- [x] `screenshots/ecr-push-ok.png` — `ecr-push.sh` concluído
- [x] `screenshots/quality-gate-block.png` — PR bloqueado por CRITICAL

### Bônus
- [x] Lifecycle policy no ECR (`lifecycle-policy.json`, aplicada pelo `ecr-push.sh`)
- [ ] Scan on push no ECR com evidência — ligado no repositório, mas o ECR não retornou resultado de scan para a imagem
- [x] Comentário atualizado (não duplicado) — marcador `<!-- technova-ai-review -->`
- [ ] Workflow de segurança separado
- [ ] Badge no README
- [x] Mais de 8 padrões no AI review — 13 regras
- [ ] Dockerfile com score A (Docker Scout ou Trivy)

## Estrutura

```
aula-09/
├── .github/scripts/ai-review.js
├── Dockerfile                 # multi-stage, usuário não-root, HEALTHCHECK
├── .dockerignore
├── ecr-push.sh
├── lifecycle-policy.json
├── server.js, package*.json   # TechNova API (da aula 08)
├── ia-cicd-analise.md
├── entrega.md
└── screenshots/

../.github/workflows/ai-review.yml   # AI review + quality gate (raiz do repositório)
../.github/workflows/ci.yml          # (opcional) push ao ECR em tag v*.*.* ou manual
```

## Como executar

Pré-requisitos: Docker, AWS CLI e credenciais válidas do Learner Lab em `~/.aws/credentials` (Start Lab → AWS Details).

```bash
# 1. (opcional) marcar uma versão para gerar as tags semver
git tag v1.0.0

# 2. build + push para o ECR
./aula-09/ecr-push.sh
```

O script, nesta ordem: identifica a conta, cria o repositório `technova-api` se não existir, aplica a lifecycle policy, faz login no ECR, calcula as tags, builda e publica.

- Tags: `sha-<commit>` e `latest` sempre; `1.2.3`, `1.2` e `1` se o commit tiver a git tag `v1.2.3`.
- Variáveis opcionais: `AWS_REGION` (padrão `us-east-1`) e `REPO_NAME` (padrão `technova-api`).
- O script pode ser executado várias vezes; o que já existe não é recriado.

Rollback (voltar a uma versão publicada):

```bash
docker pull <conta>.dkr.ecr.us-east-1.amazonaws.com/technova-api:1.0.0
```

### Testar o AI review localmente

```bash
git diff --unified=0 master...HEAD > /tmp/pr.diff
node aula-09/.github/scripts/ai-review.js /tmp/pr.diff   # exit 1 se houver CRITICAL
```

## Entrega
No fork da disciplina vai **somente** `entregas/aula-09/RA/entrega.md`. Todo o resto fica aqui no portfólio.
