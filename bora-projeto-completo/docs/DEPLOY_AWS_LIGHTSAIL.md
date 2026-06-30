# Bora — Deploy na AWS Lightsail (guia completo)

Opção **AWS enxuta** para o MVP: preço fixo e previsível, família AWS, sem montar VPC/ECS na mão.
Componentes: **Container Service** (API Docker) + **Managed Database** (PostgreSQL) + **Bucket/CDN** (frontend).
Custo estimado ~R$ 150–230/mês (confirme na página de preços do Lightsail). Cabe no teto de R$ 800.

> Diferença vs. Render: o Lightsail **não builda do GitHub**. Você builda a imagem Docker localmente
> e envia (`push-container-image`). Em troca, o preço é fixo e você fica no ecossistema AWS.

---

## 0. Pré-requisitos

| Item | Ação |
|------|------|
| Conta AWS segura | root com MFA, usuário IAM admin, **Budget de alerta** já criado |
| Região | **`sa-east-1` (São Paulo)** — melhor latência BR |
| **Docker** local | já usado no projeto (build da imagem da API) |
| **AWS CLI v2** | instalar e `aws configure` com a chave do usuário IAM |
| **Plugin lightsailctl** | necessário para `push-container-image` (instalar conforme docs AWS) |

Confirme o acesso:
```bash
aws sts get-caller-identity        # mostra sua conta/usuário
aws lightsail get-regions --query "regions[?name=='sa-east-1']"
```

---

## 1. Banco — Lightsail Managed Database (PostgreSQL)

Console Lightsail → **Databases → Create database**.
- Engine: **PostgreSQL 16**
- Plano: **Micro** (~US$ 15/mês: 1 GB RAM, 40 GB SSD) — *Standard, sem HA (enxuto)*.
- Nome: `bora-db`. Anote **endpoint, porta (5432), usuário, senha, nome do banco**.
- Em **Networking**, mantenha o banco **privado** (acessível pelos recursos Lightsail da conta).

> Flyway (V1–V13) cria o schema no 1º boot da API. `BootstrapAdmin` cria o admin inicial.

---

## 2. Imagem da API — build e push

Na pasta do backend (repo **back_bora**):
```bash
# 1) build da imagem local (usa o Dockerfile multi-stage existente)
docker build -t bora-api .

# 2) cria o serviço de container (faça uma vez; ver passo 3) e envia a imagem
aws lightsail push-container-image \
  --region sa-east-1 \
  --service-name bora-api \
  --label app \
  --image bora-api:latest
```
O comando devolve um nome interno tipo `:bora-api.app.X` — guarde para o passo 3.

---

## 3. Serviço da API — Lightsail Container Service

Console → **Containers → Create container service** (ou via CLI).
- Região: `sa-east-1`. Capacidade: **Micro (1 GB)** — suba para **Small (2 GB)** se a JVM faltar memória.
- Escala: **1 nó** (enxuto).
- **Deployment** (container `app`):
  - Image: a imagem enviada no passo 2 (`:bora-api.app.X`)
  - **Open ports:** `8080` / HTTP
  - **Public endpoint:** container `app`, porta `8080`
  - **Health check path:** `/actuator/health` (já público no `SecurityConfig`)
  - **Environment variables:**

| Variável | Valor |
|----------|-------|
| `SPRING_DATASOURCE_URL` | `jdbc:postgresql://<ENDPOINT_DB>:5432/<DB>?sslmode=require` |
| `SPRING_DATASOURCE_USERNAME` | usuário do banco |
| `SPRING_DATASOURCE_PASSWORD` | senha do banco |
| `BORA_JWT_SECRET` | segredo forte ≥ 32 bytes (`openssl rand -base64 48`) |
| `BORA_BOOTSTRAP_ADMIN_EMAIL` | `admin@bora.app` |
| `BORA_BOOTSTRAP_ADMIN_SENHA` | senha forte do admin |
| `BORA_CORS_ORIGINS` | URL do frontend (preencher após passo 4) |

Após o deploy, o serviço ganha uma URL HTTPS tipo
`https://bora-api.<random>.sa-east-1.cs.amazonlightsail.com`. Teste:
```bash
curl https://<url-do-servico>/actuator/health   # {"status":"UP"}
```

---

## 4. Frontend — Lightsail Bucket + Distribution (CDN/HTTPS)

1. **Storage → Create bucket** (`bora-front`), plano menor (~US$ 1–3/mês).
2. Subir o conteúdo de **`bora-fase-2-frontend/`** (repo front_bora) para o bucket.
3. **Networking → Create distribution** apontando para o bucket → dá **HTTPS** e domínio
   `https://<dist>.cloudfront.net` (ou ligue domínio próprio + certificado Lightsail).
4. Ajustar o frontend para apontar para a API:
   - `bora-fase-2-frontend/assets/js/api.js` → `const BORA_API = ... || 'https://<url-do-servico-api>';`
   - Reenviar o `api.js` ao bucket.
5. Voltar ao serviço da API e preencher **`BORA_CORS_ORIGINS`** com a URL do frontend → novo deploy.

> Alternativa (menos peças): servir o frontend como **2º container nginx** no mesmo Container Service,
> evitando bucket+distribution. Custa menos serviços, mas exige um pequeno Dockerfile de nginx no front.

---

## 5. Validação

1. Abra `https://<frontend>/login.html`
2. Login: `admin@bora.app` / senha do `BORA_BOOTSTRAP_ADMIN_SENHA`
3. Checagens:
   - `GET https://<api>/actuator/health` → `{"status":"UP"}`
   - `GET https://<api>/api/health` → `{"status":"Bora API online"}`
   - Swagger: `https://<api>/swagger-ui.html`

---

## 6. Custo e teto FinOps (R$ 800)

| Item | Plano | ~US$/mês | ~R$/mês |
|------|-------|----------|---------|
| Container Service (API) | Micro | 10 | ~55 |
| Managed Database | Micro | 15 | ~82 |
| Bucket + Distribution (front) | menor | 3–5 | ~16–27 |
| **Total** | | **~28–30** | **~150–165** |

- **AWS Budgets**: alerta mensal bem abaixo de R$ 800 (ex.: US$ 60) — faça antes de tudo.
- Backups: o Managed Database do Lightsail faz **snapshot automático** (retenção configurável).

---

## 7. Hardening antes de divulgar (checklist)

- [x] **CORS** restrito por env (`BORA_CORS_ORIGINS`).
- [ ] **Webhook marketplaces**: `token` em header/assinatura **HMAC** + idempotência por `id_externo`.
- [x] **HTTPS** — endpoint do Container Service e distribution já são HTTPS.
- [x] **Backups** — snapshot automático do Managed Database.
- [ ] **Segredos**: JWT/DB fortes; nunca commitar `.env`.
- [ ] **LGPD**: política e expurgo de dados de cliente.
- [ ] **Observabilidade**: logs do Container Service; avaliar alarme de erro (CloudWatch).

---

## 8. Atualizações (deploy contínuo)

A cada mudança no backend:
```bash
docker build -t bora-api .
aws lightsail push-container-image --region sa-east-1 --service-name bora-api --label app --image bora-api:latest
# criar nova deployment apontando para a nova imagem (console ou CLI create-container-service-deployment)
```
Frontend: reenviar os arquivos alterados ao bucket.

> Para automatizar (CI/CD do GitHub → Lightsail) e/ou versionar a infra como código, o próximo passo
> é **Terraform** — quando o volume justificar a evolução para App Runner + RDS.
