# Status do MVP — Bora

**MVP COMPLETO E APTO PARA PILOTO (1 lojista).** Backend compila/empacota (`bora-0.0.1-SNAPSHOT.jar`), 11 telas no ar ligadas à API, multi-tenant validado por QA (zero IDOR), deploy via Docker certificado pelo tech-lead (race API↔Postgres e healthcheck corrigidos). Guias em `docs/DEPLOY.md` e `docs/PROVISIONAMENTO_CLIENTE.md`.

Backlog pós-piloto (não bloqueia): tabela estruturada de itens de pedido; nav mobile (bottom-bar); endpoint de admin-da-plataforma (ADMINISTRADOR_BORA) p/ provisionar lojas; relatório com gráfico/PDF (Pro+); validação @PostConstruct do segredo JWT.

## ✅ Concluído

### Fundação (segurança + multi-tenant)
- Login JWT (`POST /auth/login`, `GET /auth/me`), senha BCrypt, `SecurityConfig` deny-by-default, `JwtAuthFilter`, `AuthContext`.
- Bootstrap do admin no 1º start (`admin@bora.app` / `bora123`, ajustável por env).
- **Isolamento multi-tenant** (`loja_id` do token) em Pedido, Cliente, Produto, Configuração, Usuário e Dashboard. `findByIdAndLojaId` evita IDOR.

### Regras de negócio
- RN05 cancelamento exige motivo · RN06 excluir pedido só GERENTE/ADMIN · RN07 log de mudança de status (`log_status`) · RN08 isolamento por loja · RN09 limite de pedidos/mês e de usuários por plano · RN10 white-label liberado por plano.

### Funcionalidades
- CRUD **Cliente** e **Produto** (escopados por loja).
- **Pedido**: criar (com limite de plano), listar, alterar status (com log), excluir (papel), histórico.
- **Gestão de usuários** (admin): listar/criar/papel/ativar — BCrypt, limite por plano, sem expor hash.
- **White-label** (`/api/configuracao`): campos liberados conforme o plano (Start/Pro/Premium).
- **Planos** (`Plano` + `PlanoService`): limites de usuários e pedidos/mês.
- CORS liberado + Swagger com Bearer.

### Frontend (integração core)
- `assets/js/api.js` (cliente com JWT), `login.html`, `assets/js/whitelabel.js` (marca por loja via API).
- **Dashboard** ligado à API real (KPIs + pedidos) com refresh por polling (8s) — "tempo real" barato.

### Infra
- `docker-compose.yml` com volume de dados, segredo JWT e credenciais por env.

## ⏳ Próximas fatias (ordem sugerida)
1. **Frontend — demais telas**: aplicar o padrão do dashboard (api.js + guard + logout) em `pedidos`, `novo-pedido`, `clientes`, `produtos`, `entregas`, `relatorios`, `configuracoes` (form white-label), `planos` e criar tela de **usuários**.
2. **RN04** — alerta de pedido em preparo acima do tempo limite.
3. **QA** (qa-sdet): testes com 2 lojas (isolamento/IDOR), login, papéis, limites de plano.
4. **Segurança** (infosec): revisão JWT/IDOR/CORS.
5. **Relatórios** Pro+ (exportação PDF/Excel).
6. **Deploy** (devops): revisar Dockerfile, secrets em produção, e **budget alert R$ 800** (finops) quando hospedado.
7. **Tempo real** opcional via WebSocket (se o polling não bastar).

## Como rodar
```
cd bora-fase-3-backend-java
docker compose up --build      # sobe Postgres + API (Flyway cria o schema, bootstrap cria o admin)
# Front: abrir bora-fase-2-frontend/login.html (API em http://localhost:8080)
# Login inicial: admin@bora.app / bora123
```
