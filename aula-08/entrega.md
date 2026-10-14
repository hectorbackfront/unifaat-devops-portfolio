# Entrega — Aula 08: GitHub Actions e CI Pipelines

**Aluno:** Hector Marcelo Pedroso Dos Santos
**RA:** 6125136
**Data:** 2026-10-14

## Repositório

- URL: https://github.com/hectorbackfront/unifaat-devops-portfolio

## Evidências

- [x] Workflow CI multi-stage funcional (lint → test → build) — `.github/workflows/ci-aula08.yml`
- [x] ESLint configurado e passando — `aula-08/technova-api/.eslintrc.json`
- [x] Mínimo 3 testes Jest passando com coverage (9 testes, endpoints /health e /api/orders)
- [x] Docker build no CI sem erros (tag `technova-api:${{ github.sha }}`)
- [x] Secret referenciado no workflow (`AWS_REGION`)
- [x] Badge de status no README
- [ ] Screenshots do pipeline verde

Bônus: matrix Node 18/20, cache npm, comentário no PR, concurrency, smoke test Docker.

## Evidência do Pipeline Rodando

[Colar link da execução na aba Actions]
