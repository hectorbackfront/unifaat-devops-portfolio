# TechNova API

![CI Pipeline — Aula 08](https://github.com/hectorbackfront/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml/badge.svg)

API de gestão de pedidos da TechNova, com pipeline CI no GitHub Actions.

## Quick Start

```bash
npm install
npm start
```

## Scripts

| Comando | Descrição |
|---------|-----------|
| `npm start` | Inicia o servidor |
| `npm test` | Jest com coverage |
| `npm run lint` | ESLint |
| `npm run lint:fix` | Corrige erros de lint |

## CI Pipeline (`.github/workflows/ci-aula08.yml`)

`lint` → `test` (Node 18 e 20) → `build` (Docker + smoke test)

- Cache de dependências npm (`setup-node`)
- `concurrency` cancela runs obsoletos
- Secret `AWS_REGION` referenciado no workflow
- Comentário automático em Pull Requests
