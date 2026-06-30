# Bora — Deploy no Render (guia completo)

Hospedagem enxuta e gerenciada para o MVP: **API (Docker) + PostgreSQL gerenciado + frontend estático**.
Sem Terraform, sem servidor para administrar. Custo ~R$ 70–140/mês (folga grande no teto de R$ 800).

---

## 0. Pré-requisitos

| Item | Status hoje | Ação |
|------|-------------|------|
| Conta no Render | — | criar em render.com (login GitHub) |
| **Repositório Git no GitHub** | ❌ projeto **não** é repo git | **obrigatório** — Render publica a partir de um repo (passo 1) |
| Dockerfile da API | ✅ pronto (multi-stage) | nenhuma |
| Domínio próprio | opcional | dá pra começar com `*.onrender.com` (HTTPS automático) |

---

## 1. Subir o código pro GitHub

O Render conecta num repositório. Como o projeto ainda não tem git:

```bash
cd "C:/Users/user/OneDrive/Desktop/Bora"
git init
printf "target/\n.env\n*.log\nnode_modules/\n" > .gitignore
git add .
git commit -m "Bora: app pronta para deploy"
# crie um repo vazio no GitHub (privado) e:
git remote add origin https://github.com/<voce>/bora.git
git branch -M main
git push -u origin main
```

> O `.gitignore` evita subir `target/` (build) e `.env` (segredos).

---

## 2. Ajustes obrigatórios no código (3 mudanças)

São pequenas e necessárias para o Render. Posso aplicá-las pra você.

### 2.1 — Porta dinâmica (CRÍTICO) — `bora-fase-3-backend-java/src/main/resources/application.yml`
O Render injeta a porta na env `PORT` e roteia para ela. Hoje está fixo em `8080`.
```yaml
server:
  port: ${PORT:8080}      # antes: 8080
```
Sem isso o container sobe na 8080, o Render aponta para outra porta → "no open ports detected" → deploy falha.

### 2.2 — CORS por env (hardening) — `config/WebConfig.java`
Trocar o `"*"` pela origem real do frontend, lida de uma env:
```java
String origins = System.getenv().getOrDefault("BORA_CORS_ORIGINS", "*");
cfg.setAllowedOriginPatterns(List.of(origins.split(",")));
```
Em produção define-se `BORA_CORS_ORIGINS=https://bora-frontend.onrender.com`.

### 2.3 — URL da API no frontend — `bora-fase-2-frontend/assets/js/api.js`
O fallback hoje é `http://localhost:8080`. Apontar para a API publicada:
```js
const BORA_API = localStorage.getItem('boraApiUrl') || 'https://bora-api.onrender.com';
```
(O mecanismo `?api=` continua funcionando para testes/túneis.)

---

## 3. Criar o PostgreSQL gerenciado

Render → **New → PostgreSQL**.
- **Name:** `bora-db`
- **Region:** escolha uma (ex.: Ohio/Oregon) — **use a mesma região no serviço da API**.
- **Plan:** **Basic** (~US$ 6/mês). *Evite o free: expira e some com os dados.*
- Criar e abrir a aba **Connections**. Anote do bloco **Internal**:
  - Hostname, Port (5432), Database, Username, Password.

> Flyway (V1–V13) cria o schema sozinho no 1º boot da API; `BootstrapAdmin` cria o admin inicial.

---

## 4. Criar o serviço da API (Docker)

Render → **New → Web Service** → conectar o repo do GitHub.
- **Root Directory:** `bora-fase-3-backend-java`
- **Runtime/Environment:** **Docker** (usa o `Dockerfile` existente)
- **Region:** a mesma do banco
- **Instance Type:** **Starter** (~US$ 7/mês). *Não use free: hiberna após inatividade — ruim para API.*
- **Health Check Path:** `/actuator/health` (já é público no `SecurityConfig`)

### Variáveis de ambiente (aba Environment)
| Variável | Valor |
|----------|-------|
| `SPRING_DATASOURCE_URL` | `jdbc:postgresql://<HOST_INTERNO>:5432/<DATABASE>` |
| `SPRING_DATASOURCE_USERNAME` | `<USERNAME do banco>` |
| `SPRING_DATASOURCE_PASSWORD` | `<PASSWORD do banco>` |
| `BORA_JWT_SECRET` | segredo forte **≥ 32 bytes** (ex.: `openssl rand -base64 48`) |
| `BORA_BOOTSTRAP_ADMIN_EMAIL` | `admin@bora.app` |
| `BORA_BOOTSTRAP_ADMIN_SENHA` | senha forte do admin |
| `BORA_CORS_ORIGINS` | `https://bora-frontend.onrender.com` (preencher após o passo 5) |
| `PORT` | *(não criar — o Render injeta sozinho)* |

> O `SPRING_DATASOURCE_URL` precisa do prefixo **`jdbc:`** — a "Internal Database URL" do Render vem como
> `postgresql://...`; reconstrua no formato `jdbc:postgresql://host:5432/db` e use usuário/senha separados.

Salvar → o Render faz build da imagem e sobe. Acompanhe os **Logs** até "Started BoraApplication".
A URL pública fica tipo `https://bora-api.onrender.com`.

---

## 5. Publicar o frontend estático (grátis)

Render → **New → Static Site** → mesmo repo.
- **Root Directory:** `bora-fase-2-frontend`
- **Build Command:** *(vazio — é estático)*
- **Publish Directory:** `.`
- URL final tipo `https://bora-frontend.onrender.com` (HTTPS automático).

Depois de criado, **volte ao serviço da API** e preencha `BORA_CORS_ORIGINS` com essa URL → o Render
reinicia a API. Confirme também que o `BORA_API` no `api.js` (passo 2.3) aponta para a URL da API.

---

## 6. Primeiro acesso e validação

1. Abra `https://bora-frontend.onrender.com/login.html`
2. Login: `admin@bora.app` / a senha definida em `BORA_BOOTSTRAP_ADMIN_SENHA`
3. Checagens rápidas:
   - `GET https://bora-api.onrender.com/actuator/health` → `{"status":"UP"}`
   - `GET https://bora-api.onrender.com/api/health` → `{"status":"Bora API online"}`
   - Swagger: `https://bora-api.onrender.com/swagger-ui.html`

---

## 7. Custo e guarda do teto FinOps (R$ 800)

| Item | Plano | US$/mês | ~R$/mês |
|------|-------|---------|---------|
| Web Service (API) | Starter | 7 | ~38 |
| PostgreSQL | Basic | 6–19 | ~32–100 |
| Static Site (front) | Free | 0 | 0 |
| **Total** | | **13–26** | **~70–140** |

- Em **Account → Billing**, configure um **Spend Limit / alerta** bem abaixo de R$ 800 (ex.: US$ 50).
- Backups: o Postgres Basic do Render já faz **backup diário automático**.

---

## 8. Hardening antes de divulgar o link (checklist)

Itens que dependem da app, não do Render (espelha o `PRODUCAO_PRONTIDAO.md`):
- [x] **CORS** restrito por env (passo 2.2) — preencher `BORA_CORS_ORIGINS` com o domínio real.
- [ ] **Webhook marketplaces**: mover `token` da query para header/assinatura **HMAC** + idempotência por `id_externo`.
- [ ] **JWT/DB** com segredos fortes e rotacionáveis (já via env). Nunca commitar `.env`.
- [x] **HTTPS** — automático no Render (API e front).
- [x] **Backups do Postgres** — automáticos no plano Basic.
- [ ] **LGPD**: política e expurgo de dados de cliente (telefone/endereço).
- [ ] **Observabilidade**: logs no painel do Render; avaliar alarme de erro.

---

## 9. Quando crescer (saída sem retrabalho)

Como tudo é **imagem Docker + Postgres**, migrar para AWS depois é direto:
Render → **AWS Lightsail** (mesma simplicidade) → **App Runner + RDS** (mais elástico, aí entra o Terraform).
Nenhum código é jogado fora.
