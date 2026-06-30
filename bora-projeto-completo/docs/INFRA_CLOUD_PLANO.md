# Bora — Plano de Infra Cloud (enxuta, teto R$ 800/mês)

> Plano **escrito** (sem código). Decisão pendente do dono: provedor final.
> Continua valendo o **[STOP — Terraform/infra]** do `PRODUCAO_PRONTIDAO.md`: o IaC só é
> escrito/aplicado quando o ambiente e as credenciais forem liberados.

A aplicação já está **container-ready**: `Dockerfile` multi-stage non-root, `docker-compose.yml`
(api + postgres), Flyway V1–V13 e healthcheck. Falta apenas **onde hospedar** e o **IaC**.

---

## 1. Comparação de opções (foco: enxuta / mais barata)

Câmbio de referência ~ R$ 5,4/US$. Tráfego de MVP (1 a poucas lojas).

| Opção | Componentes | Custo/mês estimado | Complexidade IaC | Trava em AWS? |
|-------|-------------|--------------------|------------------|---------------|
| **A. AWS Lightsail** ⭐ | Container service (micro) + Managed DB Postgres + bucket/CDN | **~R$ 150–230** | Baixa | Sim (família AWS) |
| **B. AWS App Runner + RDS** | App Runner (1vCPU/2GB) + RDS t4g.micro single-AZ + S3/CloudFront | ~R$ 280–410 | Média | Sim |
| **C. AWS ECS Fargate (HA)** | Fargate + RDS multi-AZ + ALB + S3/CloudFront | ~R$ 600–900 ⚠️ | Alta | Sim |
| **D. VPS + Postgres** | VPS pequena (Hetzner/DO) + Postgres (gerenciado ou no compose) + Cloudflare Pages | **~R$ 60–200** | Muito baixa | Não |

⚠️ A opção C (HA) **encosta/estoura** o teto FinOps de R$ 800 — descartada para o MVP enxuto.

### Leitura
- **Mais barato absoluto:** D (VPS). É praticamente o `docker compose up` que já temos, num servidor.
  Contra: backups e TLS por sua conta; não é AWS.
- **Mais barato dentro da AWS + simples:** **A (Lightsail)**. Preço fixo previsível, banco gerenciado
  com backup automático, sobe container direto da imagem. Melhor custo/benefício se "tem que ser AWS".
- **A "AWS de verdade" (mais elástica):** B (App Runner + RDS). Mais cara e mais peças, mas escala melhor
  e integra com o ecossistema (Secrets Manager, CloudWatch). Vale quando houver várias lojas.

### Recomendação
1. **Se AWS for obrigatório → Opção A (Lightsail)** para o MVP; migrar para B quando o volume justificar.
2. **Se AWS não for obrigatório → Opção D (VPS)** é a mais barata e a mais próxima do que já roda hoje.

---

## 2. Desenho da infra (alvo Opção A — Lightsail)

```
Internet ──HTTPS──> CDN/Distribuição (frontend estático: bora-fase-2-frontend)
                          │
                          └──/api──> Lightsail Container Service (imagem da API :8080)
                                           │
                                           └──> Lightsail Managed Database (PostgreSQL 16)
Segredos: BORA_JWT_SECRET, DB_PASSWORD  → variáveis do container (não commitar)
DNS + TLS: domínio do Bora → certificado gerenciado
```

Mapeamento equivalente se for Opção B (AWS cheio):
- Container → **ECR** (registry) + **App Runner** (serviço)
- Banco → **RDS PostgreSQL 16** single-AZ, gp3 20GB, backup 7 dias
- Frontend → **S3** (origem) + **CloudFront** (HTTPS/CDN)
- DNS/TLS → **Route 53** + **ACM**
- Segredos → **SSM Parameter Store** (grátis) ou **Secrets Manager**
- Custo/alarme → **CloudWatch** + **AWS Budget alert em R$ 800** (exigência FinOps)

---

## 3. Sequência de provisionamento (quando liberar)

1. **Registry + imagem**: build do `Dockerfile` (já pronto) → push para o registry (ECR/Lightsail).
2. **Banco gerenciado**: criar Postgres 16, guardar host/usuário/senha como segredo. Flyway cria o schema no 1º boot.
3. **Serviço da API**: subir o container apontando `SPRING_DATASOURCE_URL` para o banco; injetar `BORA_JWT_SECRET` e `DB_PASSWORD`. Healthcheck em `/actuator/health`.
4. **Frontend estático**: publicar `bora-fase-2-frontend/` no bucket/CDN; ajustar `BORA_API` (ou `localStorage.boraApiUrl`) para o domínio da API sob HTTPS.
5. **DNS + TLS**: apontar domínio, emitir certificado, ligar HTTPS/HSTS.
6. **Guarda-custo**: criar **budget alert em R$ 800/mês** antes de qualquer outra coisa ficar de pé.

---

## 4. Hardening obrigatório antes do go-live (independe do provedor)

Espelha o checklist do `PRODUCAO_PRONTIDAO.md` — não é trabalho de Terraform, é de aplicação:
- [ ] **CORS** restrito ao domínio real (`config/WebConfig.java`, via env).
- [ ] **Webhook marketplaces**: token em header/assinatura **HMAC** + idempotência por `id_externo`.
- [ ] **Segredos por env** (JWT/DB) rotacionados; nunca commitar `.env`.
- [ ] **HTTPS + HSTS** no domínio.
- [ ] **Backups** do PostgreSQL + retenção definida.
- [ ] **Observabilidade**: `actuator` métrico, logs estruturados, alarme de erro.
- [ ] **LGPD**: política e expurgo de dados de cliente (telefone/endereço).

---

## 5. O que falta, em uma frase

A infra cloud **não tem Terraform escrito** e **nenhum provedor fixado**. Falta: (1) o dono escolher
provedor/robustez, (2) liberar ambiente+credenciais, (3) escrever o IaC do desenho acima, e (4) fechar o
checklist de hardening. A engenharia de aplicação está pronta para hospedar.
