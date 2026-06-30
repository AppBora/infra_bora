# Bora — Infra & Documentação (infra_bora)

Repositório de **infraestrutura e documentação** do Bora (SaaS de delivery white-label).
O código da aplicação vive em repositórios separados:

| Repo | Conteúdo |
|------|----------|
| [back_bora](https://github.com/AppBora/back_bora) | Backend Spring Boot 3 / Java 21 (API, migrations Flyway, Dockerfile) |
| [front_bora](https://github.com/AppBora/front_bora) | Frontend HTML/CSS/JS (painel white-label, ~28 telas) |
| **infra_bora** (este) | Deploy, orquestração e toda a documentação do projeto |

## Conteúdo deste repo

- **`docker-compose.yml`** + **`.env.example`** — sobe API + PostgreSQL local para desenvolvimento.
- **`bora-teste-remoto.sh`** — link de teste remoto via túneis Cloudflare.
- **`bora-fase-1-arquitetura/`** — visão de produto, modelo de dados, planos SaaS, permissões, white-label, custos.
- **`bora-projeto-completo/`** — docs consolidadas:
  - `docs/DEPLOY_RENDER.md` — guia de deploy no Render (recomendado para o MVP).
  - `docs/INFRA_CLOUD_PLANO.md` — comparação de provedores (Render / Lightsail / AWS / VPS).
  - `docs/PRODUCAO_PRONTIDAO.md` — checklist de go-live e hardening.
  - `docs/DEPLOY.md`, `docs/PROVISIONAMENTO_CLIENTE.md`, `docs/TESTES.md` — operação.
  - `marketing/` — go-to-market, promoções, CX.

## Deploy

A recomendação atual é **Render** (API Docker + PostgreSQL gerenciado + frontend estático),
custo ~R$ 70–140/mês. Passo a passo completo em
[`bora-projeto-completo/docs/DEPLOY_RENDER.md`](bora-projeto-completo/docs/DEPLOY_RENDER.md).

## Desenvolvimento local

```bash
cp .env.example .env   # preencha BORA_JWT_SECRET e DB_PASSWORD
docker compose up --build -d
# API: http://localhost:8080  | Swagger: /swagger-ui.html
```
