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
- **`bora-projeto-completo/scripts/deploy-lightsail.sh`** — deploy automatizado na AWS Lightsail (CLI).
- **`bora-teste-remoto.sh`** — link de teste remoto via túneis Cloudflare.
- **`bora-fase-1-arquitetura/`** — visão de produto, modelo de dados, planos SaaS, permissões, white-label, custos.
- **`bora-projeto-completo/`** — docs consolidadas:
  - `docs/SETUP_CONTA_AWS.md` — onboarding da conta AWS (MFA, budget, IAM, profile) antes do deploy.
  - `docs/DEPLOY_AWS_LIGHTSAIL.md` — **guia oficial de deploy (AWS Lightsail enxuto)**.
  - `docs/DEPLOY_RENDER.md` — alternativa de deploy (Render), mantida como referência.
  - `docs/INFRA_CLOUD_PLANO.md` — comparação de provedores (Render / Lightsail / AWS / VPS).
  - `docs/PRODUCAO_PRONTIDAO.md` — checklist de go-live e hardening.
  - `docs/DEPLOY.md`, `docs/PROVISIONAMENTO_CLIENTE.md`, `docs/TESTES.md` — operação.
  - `marketing/` — go-to-market, promoções, CX.

## Deploy

Caminho oficial: **AWS Lightsail enxuto** (Container Service + Managed PostgreSQL + Bucket/CDN),
custo ~R$ 150–165/mês. Passo a passo em
[`bora-projeto-completo/docs/DEPLOY_AWS_LIGHTSAIL.md`](bora-projeto-completo/docs/DEPLOY_AWS_LIGHTSAIL.md)
e script em [`bora-projeto-completo/scripts/deploy-lightsail.sh`](bora-projeto-completo/scripts/deploy-lightsail.sh).
Alternativa mais simples/barata (sem AWS): [`docs/DEPLOY_RENDER.md`](bora-projeto-completo/docs/DEPLOY_RENDER.md).

## Desenvolvimento local

```bash
cp .env.example .env   # preencha BORA_JWT_SECRET e DB_PASSWORD
docker compose up --build -d
# API: http://localhost:8080  | Swagger: /swagger-ui.html
```
