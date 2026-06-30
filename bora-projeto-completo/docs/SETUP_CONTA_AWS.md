# Bora — Setup da conta AWS (passo a passo)

Onboarding da conta AWS **Bora** (`933793947259`) até estar pronta para o deploy na Lightsail.
A **Parte 1** é feita no console (exige o usuário root). A **Parte 2** é a automação do deploy
(ver [`DEPLOY_AWS_LIGHTSAIL.md`](DEPLOY_AWS_LIGHTSAIL.md) e [`../scripts/deploy-lightsail.sh`](../scripts/deploy-lightsail.sh)).

> Por que a Parte 1 é manual: numa conta AWS nova, a única credencial existente é o **root**.
> É preciso logar no console como root para criar a primeira chave de acesso (IAM) que habilita o CLI.

---

## PARTE 1 — Console da conta Bora (≈ 5 min)

### Passo 0 — Entrar como root
1. Acesse **https://console.aws.amazon.com/**
2. Escolha **Root user**, informe o **e-mail** da conta Bora e a senha.

### Passo 1 — 🔐 Ativar MFA no root
1. Canto superior direito → **nome da conta** → **Security credentials**
2. **Multi-factor authentication (MFA)** → **Assign MFA device**
3. **Authenticator app** → dê um nome
4. No **Google Authenticator** / Authy → escaneie o **QR Code**
5. Digite **dois códigos seguidos** → **Add MFA**

> Depois disso, evite usar o root no dia a dia.

### Passo 2 — 💰 Criar o Budget (trava de custo, teto R$ 800)
1. Busca do topo → **Billing** → **Billing and Cost Management**
2. **Budgets** → **Create budget**
3. **Use a template (simplified)** → **Monthly cost budget**
4. **Budgeted amount:** `60` (US$)
5. **Email recipients:** seu e-mail → **Create budget**

### Passo 3 — 👤 Usuário de deploy + chave de acesso
1. Busca do topo → **IAM** → **Users** → **Create user**
2. **User name:** `deployer` → **Next**
   - *(não marque acesso ao console — é só automação)*
3. **Attach policies directly** → marque **`AmazonLightsailFullAccess`** → **Next** → **Create user**
4. Abra **`deployer`** → aba **Security credentials** → **Create access key**
5. Caso de uso: **Command Line Interface (CLI)** → confirme o aviso → **Create access key**
6. **Copie** (ou baixe o `.csv`): **Access key ID** e **Secret access key** *(a secret só aparece uma vez)*

### Passo 4 — 🔑 Configurar o profile (no SEU terminal, não no chat)
```
aws configure --profile bora
```
- **AWS Access Key ID:** `AKIA...`
- **AWS Secret Access Key:** a secret
- **Default region name:** `sa-east-1`
- **Default output format:** `json`

Verificar:
```
aws sts get-caller-identity --profile bora     # deve mostrar Account 933793947259
```

---

## PARTE 2 — Deploy (automação)

Pré-requisitos já instalados nesta máquina: **AWS CLI v2**, **Docker**, **lightsailctl**.
Tenha o **Docker Desktop aberto** (a etapa de build precisa dele).

Sequência (detalhe em `DEPLOY_AWS_LIGHTSAIL.md`), usando `export AWS_PROFILE=bora`:
1. Criar o **Lightsail Managed Database** (PostgreSQL 16, Micro) → anotar endpoint/credenciais.
2. Preencher `scripts/deploy-lightsail.env` (a partir do `.env.example`) com DB, JWT e senha do admin.
3. `./scripts/deploy-lightsail.sh service` — cria o Container Service e espera ACTIVE.
4. `./scripts/deploy-lightsail.sh image` — build + push da imagem da API.
5. `./scripts/deploy-lightsail.sh deploy` — implanta com envs, endpoint :8080 e health `/actuator/health`.
6. `./scripts/deploy-lightsail.sh bucket` — bucket + upload do frontend; depois criar a Distribution (CDN/HTTPS).
7. Ajustar `BORA_API` no `api.js` para a URL da API e reimplantar com `BORA_CORS_ORIGINS` = URL do frontend.
8. Validar: `/actuator/health`, login `admin@bora.app`, `/swagger-ui.html`.

---

## Quem faz o quê

| Etapa | Quem | Onde |
|-------|------|------|
| MFA root, Budget, criar access key | **Dono** | Console (conta Bora) |
| `aws configure --profile bora` | **Dono** | Terminal próprio |
| Banco, build, deploy, bucket, testes | **Automação** | CLI/script na máquina |

---

## Conta

- **Account name:** Bora
- **Account ID:** `933793947259`
- **Região:** `sa-east-1` (São Paulo)
- **Profile CLI:** `bora`
