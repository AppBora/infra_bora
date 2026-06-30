# Provisionamento do 1º Cliente (lojista)

## Caminho do piloto (1 loja) — o mais simples
O backend já cria, no 1º start, **uma loja** + **um ADMINISTRADOR_LOJA** (via `BootstrapAdmin`).
1. Defina antes de subir: `ADMIN_EMAIL`, `ADMIN_SENHA`, `BORA_JWT_SECRET`, `DB_PASSWORD`.
2. `docker compose up --build -d` → a loja "Loja Demo" e o admin são criados.
3. Ajuste o **plano** da loja conforme o contrato (Start/Pro/Premium):
   ```sql
   UPDATE loja SET nome = '<Nome da Loja>', plano = 'PRO' WHERE id = 1;
   ```
4. Login no front (`login.html`) com o admin → **Configurações**: nome, cores, logo (white-label conforme o plano).
5. Cadastrar **produtos** e **clientes**; treinar a operação (novo pedido → kanban → entrega).
6. (Opcional) Criar a equipe em **Usuários** (operador/gerente) — respeita o limite do plano.

## Cliente adicional (multi-tenant) — via endpoint da plataforma (sem SQL)
Existe um administrador da plataforma (**ADMINISTRADOR_BORA**) que provisiona lojas + o admin de cada uma, sem SQL nem hash à mão.

1. Habilite o super-admin no 1º start, definindo no ambiente:
   ```
   SUPERADMIN_EMAIL=voce@bora.app
   SUPERADMIN_SENHA=<senha-forte>
   ```
   (O `BootstrapAdmin` cria o ADMINISTRADOR_BORA se ainda não existir.)
2. Logue como super-admin e chame o endpoint (via Swagger `/swagger-ui.html` ou curl):
   ```
   POST /admin-bora/lojas
   { "nomeLoja":"<Nome>", "documento":"<CNPJ>", "plano":"PRO",
     "adminNome":"<Nome do dono>", "adminEmail":"admin@<loja>.com", "adminSenha":"<senha>" }
   ```
   Resposta: `{ lojaId, plano, adminEmail }`. A senha já é gravada com BCrypt.
3. `GET /admin-bora/lojas` lista todas as lojas. Entregue as credenciais ao lojista e siga do passo 4 acima.

## Checklist rápido de go-live
- [ ] Segredos definidos por env (JWT, DB) — nada hardcoded
- [ ] Plano da loja correto
- [ ] White-label configurado (logo/cores/nome)
- [ ] Produtos e clientes cadastrados
- [ ] Equipe criada com papéis corretos
- [ ] HTTPS + CORS restrito ao domínio
- [ ] Budget alert do provedor em R$ 800 (FinOps)
- [ ] Backup do PostgreSQL ativado
