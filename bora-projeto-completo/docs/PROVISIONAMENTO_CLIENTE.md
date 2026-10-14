# Provisionamento do 1º Cliente (lojista)

> ## ⚠️ CONFERIDO EM 14/10/2026: ESTE DOCUMENTO QUEBRAVA A PRODUÇÃO
>
> **Não existe plano `PRO`.** O enum `Plano` (`entity/Plano.java`) tem **um único** valor:
> `UNICO(15 usuários, pedidos ilimitados, R$ 199,00)`. Start, Pro e Premium foram descontinuados em
> 07/07/2026.
>
> Seguindo este documento como estava:
> - o `UPDATE loja SET plano = 'PRO'` fazia o **Hibernate estourar ao ler a loja**
>   (`Plano.valueOf("PRO")`), e a loja saía do ar;
> - o `POST /admin-bora/lojas` com `"plano":"PRO"` devolvia **400**.
>
> Os trechos errados estão **corrigidos abaixo**. Também não há mais `docker compose up` em produção
> (ver `bora-landing/deploy/`), e o Swagger está desligado no servidor.
>
> **O caminho que funciona hoje** é a tela de Plataforma do painel (`configuracoes.html`, visível para
> `ADMINISTRADOR_BORA`), que chama o mesmo endpoint sem SQL e sem curl.

## Caminho do piloto (1 loja) — o mais simples
O backend já cria, no 1º start, **uma loja** + **um ADMINISTRADOR_LOJA** (via `BootstrapAdmin`).
1. Defina antes de subir: `ADMIN_EMAIL`, `ADMIN_SENHA`, `BORA_JWT_SECRET`, `DB_PASSWORD`.
2. `docker compose up --build -d` → a loja "Loja Demo" e o admin são criados.
3. Ajuste o **nome** da loja. O plano é único e já nasce certo — **não mexa na coluna `plano`**:
   ```sql
   UPDATE loja SET nome = '<Nome da Loja>' WHERE id = 1;
   ```
   Preço negociado (fundador, por exemplo) é a coluna `preco_mensal`, pela tela de Plataforma — não
   por SQL, porque a mudança precisa ir para o Asaas junto.
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
2. Logue como super-admin e chame o endpoint (pela tela de Plataforma do painel; o Swagger está desligado em produção):
   ```
   POST /admin-bora/lojas
   { "nomeLoja":"<Nome>", "documento":"<CNPJ>",
     "adminNome":"<Nome do dono>", "adminEmail":"admin@<loja>.com", "adminSenha":"<senha>" }
   ```
   Resposta: `{ lojaId, plano, adminEmail }`. A senha já é gravada com BCrypt.
3. `GET /admin-bora/lojas` lista todas as lojas. Entregue as credenciais ao lojista e siga do passo 4 acima.

## Checklist rápido de go-live
- [ ] Segredos definidos por env (JWT, DB) — nada hardcoded
- [ ] Nome e documento da loja corretos (o plano é único, não há o que escolher)
- [ ] White-label configurado (logo/cores/nome)
- [ ] Produtos e clientes cadastrados
- [ ] Equipe criada com papéis corretos
- [ ] HTTPS + CORS restrito ao domínio
- [ ] Budget alert do provedor em R$ 800 (FinOps)
- [ ] Backup do PostgreSQL ativado
