# GitOps e CD — Analise

## 1. Fluxo GitOps: por que plan no PR e apply no merge

O Git e a fonte da verdade da infraestrutura. Mudar infra = abrir PR.

- **Plan no PR:** o revisor ve exatamente o que vai mudar (`+`, `~`, `-`) como comentario, antes de aprovar. Um plan que falha (`validate`, `fmt`, erro de provider) reprova o check e o PR nao deve ser mergeado.
- **Apply no merge:** so o codigo revisado e aprovado chega na `main`, entao so ele e aplicado. Ninguem roda `terraform apply` na maquina local, o que elimina "funciona no meu terminal" e deixa auditoria (quem, quando, qual commit).
- **State remoto (S3 + DynamoDB lock):** o runner e efemero; sem state remoto o apply nao saberia o que o plan viu. O lock evita dois applies simultaneos; o `concurrency` dos workflows reforca isso.

Limite conhecido: o plan do PR pode ficar desatualizado se outro PR for mergeado antes. O ideal e aplicar um plan salvo (`-out`) ou reexecutar o plan na `main`.

## 2. Autenticacao no Learner Lab

O Lab entrega 3 credenciais temporarias (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`). Elas ficam como GitHub Secrets e vao para a `aws-actions/configure-aws-credentials@v4`.

**Em producao seria OIDC + role IAM:** o GitHub emite um token por execucao, a AWS o troca por credenciais de minutos via `sts:AssumeRoleWithWebIdentity`, e a *trust policy* restringe repositorio/branch. Nao existe segredo de longa duracao para vazar nem para rotacionar.

**Por que o Lab nao permite:** o Learner Lab bloqueia `iam:CreateOpenIDConnectProvider` e `iam:CreateRole`; so existem as roles pre-criadas (`LabRole`, `LabInstanceProfile`). Por isso nao ha `oidc.tf` neste projeto. Custo pratico: a cada sessao do Lab e preciso atualizar os 3 secrets, senao o pipeline falha com `ExpiredToken`.

## 3. Estrategia Recreate

Para o container antigo, remove, baixa a imagem nova e sobe: `stop -> rm -> pull -> run`.

| Pros | Contras |
|---|---|
| Simples, sem balanceador nem 2o ambiente | **Downtime** entre o stop e o novo container passar a responder |
| Sem custo extra de infra | Rollback tambem tem downtime |
| Nunca ha duas versoes ao mesmo tempo (bom com schema de banco incompativel) | Se a nova versao quebrar, o servico fica fora ate o rollback |

Quando usar: ambientes de dev/homologacao, apps internas, janelas de manutencao, ou quando duas versoes simultaneas seriam um problema. Para zero downtime, Blue-Green (aula 11) e Canary (aula 12).

## 4. Continuous Delivery vs Continuous Deployment

- **Delivery:** todo commit gera um artefato pronto para producao, mas o release final exige uma aprovacao humana.
- **Deployment:** se passou em todos os testes, vai para producao sozinho, sem aprovacao.

Este pipeline e *Continuous Deployment* (push na `main` -> producao, sem portao). Para virar *Delivery* bastaria um GitHub Environment com *required reviewers* no job `deploy` (nao implementado). Deployment exige testes e health check confiaveis, que aqui sao basicos.

## 5. Rollback

Ver [docs/runbook-rollback.md](docs/runbook-rollback.md): como as imagens tem tag `sha-<commit>`, o rollback e subir uma tag anterior (com `docker login` no ECR antes do `pull`) ou `git revert` na `main`.

## 6. Limitacoes e melhorias

- Credenciais de sessao expiram: pipeline depende de atualizar secrets manualmente (producao: OIDC).
- SSH aberto para `0.0.0.0/0` porque o runner nao tem IP fixo (producao: SSM Session Manager, sem porta 22, ou runner self-hosted).
- Recreate com downtime; o health check detecta a falha mas nao faz rollback automatico.
- Chave privada em secret e SSH sem verificacao de *host key* pelo `appleboy/ssh-action`.
- Sem HTTPS nem load balancer; a porta 3000 e publica.
- Plan do PR nao e reaproveitado no apply; destroy so gera aviso, nao exige aprovacao extra (melhoria: Environment com reviewers).
- Sem scan de imagem bloqueante nem Infracost.

## Evidencias

Todas obtidas em 2026-11-14 no Learner Lab (`us-east-1`):

| Evidencia | Arquivo |
|---|---|
| Plan como comentario no PR #3 (3 a criar, 0 a destruir) | `screenshots/plan-pr-comment.png` (+ `-inicio`, `-meio`) |
| Apply apos o merge (`Apply complete! Resources: 3 added`) | `screenshots/apply-success.png` (+ `apply-log-*.png`) |
| Pipeline CD verde: lint + test -> build/push ECR -> deploy | `screenshots/cd-pipeline-green.png` |
| Health check no log (falhou na tentativa 1, OK na 2) | `screenshots/health-check-pass.png` |

O rollback foi testado manualmente na EC2: `sha-01aee39` -> `sha-8a0d4fd` -> `sha-01aee39`, com login no ECR antes do pull e `/health` respondendo `ok` nas duas versoes.

## Problemas encontrados durante a execucao

- O bucket de state da aula 05 tinha sido apagado pelo reset do Lab (`NoSuchBucket` no `terraform init`). Foi criado um bucket novo (`technova-tfstate-6125136`) e a tabela de lock, uma vez, na mao.
- O comentario do plan nao saia quando o `init` falhava; o step de comentar passou a rodar com `if: always()`.
- `script_stop` deixou de ser input valido do `appleboy/ssh-action`; trocado por `set -e` no script.
- O primeiro deploy (logo apos o merge) falhou com `missing server host`, pois o secret `EC2_HOST` so pode ser criado depois que o apply cria a EC2.
