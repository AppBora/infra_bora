# Bora — Prontidão para Produção

Documento vivo do estado do produto e do que falta para o go-live. **Regra do projeto: a engenharia vai até aqui; o deploy real (Terraform/infra) só com o ambiente provisionado pelo dono.**

## 1. O que já está pronto (funcional, testado local)

### Operação
- **Pedidos (kanban tempo real)** — colunas Cozinha→Aguardando→Saiu→Entregue, busca, filtros por canal, selo do marketplace, alerta de atraso por **SLA do canal**, aceite/recusa, impressão de comanda, som + toast de pedido novo.
- **KDS Cozinha** (tela cheia) — fila por antiguidade, cronômetro vivo, SLA por canal, toque avança status, alerta sonoro.
- **Frente de Caixa (PDV)** — venda rápida, carrinho, pagamento, resgate de cashback, fechamento de caixa.
- **Entregas & Roteirização** — agrupamento por bairro, despacho em lote, atribuição de entregador.
- **Fechamento de Caixa** — totais do dia por pagamento e por canal, impressão.

### Comercial / dados
- **Canais de venda** — iFood, 99Food, Rappi, Uber Eats, aiqfome, Goomer, WhatsApp, Instagram, Telefone, Site, Balcão. Ranking por faturamento/ticket/share.
- **Integrações (marketplaces)** — conexão por loja+canal com credenciais, **webhook de entrada** (normalizador por marketplace), **push de status de volta** (no-op sem credencial), simulador de pedido. *Falta só inserir credenciais reais de parceiro.*
- **CRM & Fidelidade** — cashback 5% por pedido, resgate no checkout, segmentação (novos/recorrentes/sumidos), reativação por WhatsApp.
- **Estoque + ficha técnica** — custo, estoque, mínimo; **baixa automática** na venda; alertas de ruptura.
- **Relatórios gerenciais** — faturamento, ticket, **CMV e margem**, vendas por dia, por canal, por produto e por entregador; export CSV.
- **Cardápio digital** público + QR Code.
- **Multi-tenant** por `loja_id` no JWT; planos START/PRO/PREMIUM com limites e white-label.

### Plataforma
- Backend Spring Boot 3 / Java 21, PostgreSQL, Flyway (**V1–V11**), Spring Security + JWT.
- Frontend estático (HTML/CSS/JS), tema white-label, navegação centralizada.
- Docker Compose (api + postgres com healthcheck). API e banco sobem `healthy`.

## 2. Hardening antes do go-live (checklist)
- [ ] **CORS**: trocar `allowedOriginPatterns("*")` pelo domínio da loja (via env) — `config/WebConfig.java`.
- [ ] **Webhook marketplaces**: mover o `token` da query string para header/assinatura; validar **HMAC** por parceiro (ex.: iFood) e adicionar rate-limit/idempotência por `id_externo` (evitar pedido duplicado em reentrega de webhook).
- [ ] **Segredos por env** (JWT, DB) — já suportado; rotacionar e nunca commitar `.env`.
- [ ] **HTTPS obrigatório** + HSTS no domínio.
- [ ] **Backups** do PostgreSQL + retenção.
- [ ] **Observabilidade**: expor `actuator` métrico, logs estruturados, alarme de erro.
- [ ] **Idempotência de status**: registrar push de status com retry/fila quando as credenciais reais entrarem.
- [ ] **LGPD**: política de dados de clientes (telefone/endereço) e expurgo.
- [ ] **Provisionamento**: usar `SUPERADMIN_*` + `POST /admin-bora/lojas` para criar cada lojista (ver PROVISIONAMENTO_CLIENTE.md).
- [ ] **FinOps**: manter o teto de **R$ 800/mês** — infra enxuta (1 container API + Postgres gerenciado pequeno + CDN/estático).

## 3. Caminho de deploy (PARA no Terraform)
1. Build da imagem da API (Dockerfile multi-stage já pronto) → push para um registry.
2. Frontend estático → hospedagem de estáticos/CDN (HTTPS nativo).
3. **[STOP — Terraform/infra]**: provisionar banco gerenciado, serviço de container, DNS e TLS. **Aguarda o dono fornecer o ambiente/credenciais.**

## 4. Integração real com marketplaces (decisão de negócio do dono)
Para os pedidos caírem sozinhos, cada marketplace exige **conta de parceiro + credenciais + homologação**:
- **iFood**: Portal do Desenvolvedor → app → `clientId/clientSecret` + merchant; webhook/polling de `orders`. Adaptador pronto (`MarketplaceNormalizer.ifood`).
- **99Food / Rappi / Uber Eats / aiqfome / Goomer**: cadastro de parceiro equivalente; adaptadores já existem, só ajustar caminhos de campo quando vier o payload real.
- Na tela **Integrações**: colar credenciais, ativar e copiar a URL de webhook para o painel do parceiro.
