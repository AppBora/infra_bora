# Deploy do Bora

> ## ⚠️ DOCUMENTO HISTÓRICO — NÃO SIGA ESTE AQUI (conferido em 14/10/2026)
>
> Este texto descreve uma arquitetura que **nunca existiu em produção**: fala de `docker compose up` com o Postgres num container, que é o ambiente de DESENVOLVIMENTO.
>
> **A produção de verdade é:** uma instância Ubuntu no Lightsail (`bora-app`, 18.230.57.33) com dois
> containers Docker — `api` (a imagem `bora-api`) e `caddy` (HTTPS automático + serve o frontend de
> `/home/ubuntu/bora/frontend` + proxy para `api:8080`) — e o PostgreSQL gerenciado do Lightsail.
>
> **Onde está o que vale:**
> - `bora-landing/deploy/LEIAME.md` — o Caddyfile e por que cada linha dele existe
> - `bora-landing/deploy/deploy-api.sh` — o deploy real, em 9 passos, com backup e rollback
> - `bora-landing/deploy/servidor/` — os scripts que rodam no servidor e o `docker run` do Caddy
>
> Guardado por registrar as decisões da época; não serve de roteiro.

Stack: Spring Boot 3 (Java 21) + PostgreSQL, via Docker. Frontend estático (HTML/CSS/JS).

## Pré-requisitos
- Docker + Docker Compose
- (Produção) um proxy HTTPS na frente (Nginx, Caddy ou Cloudflare)

## Variáveis de ambiente (NÃO comitar segredos)
| Variável | Para quê | Obrigatória em produção |
|----------|----------|--------------------------|
| `BORA_JWT_SECRET` | Assinatura do JWT (mín. 32 bytes) | **Sim** |
| `DB_PASSWORD` | Senha do PostgreSQL | **Sim** |
| `ADMIN_EMAIL` / `ADMIN_SENHA` | Admin criado no 1º start | Recomendado |

## Subir (backend + banco)
```
cd bora-fase-3-backend-java
export BORA_JWT_SECRET="<segredo-forte-de-32+-bytes>"
export DB_PASSWORD="<senha-forte>"
docker compose up --build -d
```
- Flyway cria o schema (V1..V6); o `BootstrapAdmin` cria o admin inicial se não houver usuários.
- Healthcheck do container: porta 8080 (e `GET /actuator/health`).
- Swagger: `http://<host>:8080/swagger-ui.html`.

## Frontend
`bora-fase-2-frontend/` é estático. Sirva por Nginx/Caddy/qualquer host. Aponte a API:
- No navegador, a API padrão é `http://localhost:8080`. Para produção, ajuste `localStorage.boraApiUrl` ou a constante `BORA_API` em `assets/js/api.js`.
- Sirva front e API sob HTTPS (mesmo domínio ou ajuste o CORS em `WebConfig`).

## HTTPS / produção
- Proxy (Caddy/Nginx/Cloudflare) terminando TLS na frente da API e do front.
- Restrinja as origens de CORS em `WebConfig.corsConfigurationSource()` ao domínio real.
- Troque `BORA_JWT_SECRET` e a senha do banco por valores fortes (secrets do provedor).

## Custos (FinOps — teto R$ 800/mês)
- VPS pequena (Spring Boot) + Postgres ≈ R$ 140–260/mês → folga grande.
- Configurar **budget alert do provedor em R$ 800** assim que hospedar.
- Termômetro/promoções automáticas: só job + SQL = R$ 0 extra.
