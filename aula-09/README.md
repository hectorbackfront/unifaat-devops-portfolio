# Aula 09 — Docker Registry e IA no CI/CD

Projeto: pipeline da TechNova API que builda, publica no **Amazon ECR** e faz **AI review** em Pull Requests.
Ambiente: AWS Academy Learner Lab, região `us-east-1`. Credenciais do Lab expiram a cada sessão.

## Checklist (do TF da aula 09)

### 1. Build e push no ECR (40%)
- [ ] `ecr-push.sh`: garante o repo `technova-api` (idempotente), login no ECR, build multi-stage e push
- [ ] Tags: `sha-XXXXXXX`, `latest` e semver (`1.2.3`, `1.2`, `1`) a partir de git tag `v*.*.*`
- [ ] Pull por tag funcionando (rollback)
- [ ] (opcional) `.github/workflows/ci.yml` com `aws-actions/configure-aws-credentials@v4` + `amazon-ecr-login@v2`

### 2. AI Review (30%)
- [ ] `.github/workflows/ai-review.yml` em `pull_request` (opened, synchronize, reopened)
- [ ] `.github/scripts/ai-review.js` detecta: secrets hardcoded, `eval()`, SQL injection, `console.log`, `catch` vazio
- [ ] Comentário no PR em tabela, por severidade

### 3. Quality gate (10%)
- [ ] CRITICAL => `exit 1` (bloqueia o PR); WARNING/INFO => passa

### 4. Documentação e evidências (20%)
- [ ] `ia-cicd-analise.md` (por que ECR, estratégia de tags, padrões, prompt/lógica, quando confiar na IA, limitações)
- [ ] `screenshots/ecr-console.png` — repositório com as tags
- [ ] `screenshots/ai-review-comment.png` — comentário no PR
- [ ] `screenshots/ecr-push-ok.png` — `ecr-push.sh` concluído (ou CI verde)
- [ ] `screenshots/quality-gate-block.png` — PR bloqueado por CRITICAL

### Bônus
- [ ] Lifecycle policy no ECR
- [ ] Scan on push no ECR com evidência
- [ ] Comentário atualizado (não duplicado)
- [ ] Workflow de segurança separado
- [ ] Badge no README
- [ ] Mais de 8 padrões no AI review
- [ ] Dockerfile com score A (Docker Scout ou Trivy)

## Estrutura

```
aula-09/
├── .github/
│   ├── workflows/{ci.yml, ai-review.yml}
│   └── scripts/ai-review.js
├── ecr-push.sh
├── Dockerfile
├── .dockerignore
├── ia-cicd-analise.md
├── screenshots/
└── README.md
```

## Como executar
_(preencher quando o `ecr-push.sh` estiver pronto)_

## Entrega
No fork da disciplina vai **somente** `entregas/aula-09/RA/entrega.md`. Todo o resto fica aqui no portfólio.
