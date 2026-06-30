# Plano de Execução — Fase de Fundação (Auth + Multi-tenant)

> Objetivo: entregar a **base de segurança e isolamento por loja** que destrava todo o resto (CRUDs, limites de plano, white-label, deploy). Nada de funcionalidade nova deve ser construído antes desta fase.

## Resultado esperado (Definition of Done)
- Login por e-mail/senha (BCrypt) emitindo **JWT**; rotas protegidas por padrão (deny-by-default).
- Todo dado pertence a uma **loja** (`loja_id`) e **toda** query/endpoint filtra pelo `loja_id` do token. Uma loja **nunca** vê dados de outra (RN08).
- Papéis aplicados **no backend**: OPERADOR, GERENTE, ADMINISTRADOR_LOJA, ADMINISTRADOR_BORA (global).
- Pedido refatorado para tenant-scoped + regras: só GERENTE/ADMIN exclui (RN06), cancelamento exige motivo (RN05), mudança de status gera log (RN07).
- SpringDoc com esquema Bearer JWT; build verde; testes de isolamento passando.

## Sequência e responsáveis

### 1. arquiteto-software — desenho (antes de codar)
- Definir o modelo de tenant (`loja_id` em todas as entidades de dado), o contrato de auth (`POST /auth/login`, `GET /auth/me`), o formato do JWT (claims: `sub`, `loja_id`, `papel`, `exp`), e como o `loja_id` é propagado (filtro → contexto → repositórios).
- Decidir abordagem de tempo real (WebSocket/SSE) para a próxima fase — só registrar a decisão, sem implementar agora.
- Entregar: nota de arquitetura curta + checklist de pontos onde o tenant não pode se perder.

### 2. dba — schema e migrations
- `V4__create_users_and_auth.sql`: tabela `usuario` (`id, loja_id, nome, email único, senha_hash, papel, ativo, created_at`), índices `(loja_id)` e `unique(email)`.
- Garantir `loja_id NOT NULL` + índices `(loja_id, ...)` nas tabelas de pedido/cliente/produto (criar `V5__tenant_indexes.sql` se faltar).
- Seed de 1 loja + 1 ADMINISTRADOR_LOJA para testes (`V6__seed_auth.sql`), senha BCrypt.
- Nunca editar migration já aplicada — sempre nova versão.

### 3. dev-backend — implementação
- **Entidade/Repo** `Usuario` + `Papel` (enum). `UsuarioRepository.findByEmail`.
- **Security**: `SecurityConfig` (Spring Security 6, stateless), `PasswordEncoder` BCrypt, `JwtService` (gerar/validar), `JwtAuthFilter`, deny-by-default (só `/auth/**`, `/actuator/health`, swagger liberados).
- **AuthController**: `POST /auth/login` (valida senha, retorna JWT), `GET /auth/me`.
- **TenantContext/AuthContext**: extrai `loja_id` e `papel` do token; helper `requireRole(...)`.
- **Isolamento**: refatorar `PedidoService`/repositórios para filtrar por `loja_id` do token em **todas** as leituras/escritas. Aplicar o mesmo padrão como referência para os próximos CRUDs.
- **Regras no Pedido**: RN06 (excluir só GERENTE/ADMIN), RN05 (cancelar exige `motivo`), RN07 (gravar log de mudança de status — tabela `pedido_status_log` se necessário, via `V7__`).
- **SpringDoc**: registrar o esquema de segurança Bearer.
- Rodar `mvn -q -DskipTests package` e garantir build limpo.

### 4. infosec-pentester — revisão de segurança (checkpoint)
- Caçar IDOR: endpoint que recebe id e busca sem checar `loja_id`. Validar JWT (assinatura/expiração), segredo fora do código, CORS, deny-by-default, BCrypt.
- Veredito: bloqueio entre lojas é **inquebrável**? Liberar ou apontar correções.

### 5. qa-sdet — testes end-to-end
- Criar **2 lojas** + usuários de papéis diferentes. Provar: login OK; loja A não lê/edita dado da loja B (inclusive por id direto); papel sem permissão recebe 403; cancelar sem motivo bloqueia; excluir pedido só por GERENTE/ADMIN; log de status gravado.
- Massa de teste + relatório PASS/FAIL + veredito.

### 6. arquiteto-finops — guarda de custo
- Confirmar que a fase não muda o custo (auth/JWT/Postgres são baratos) — projeção segue **dentro do teto R$ 800/mês**. Sem alerta esperado.

### 7. tech-lead — fechamento
- Build de tudo, consistência de camadas, `loja_id` propagado ponta a ponta. Só declarar concluído com isolamento multi-tenant consistente.

## Dependências
1 → 2 → 3 → (4 e 5 em paralelo) → 7. FinOps (6) e Marketing rodam em paralelo sem bloquear.

## Fora do escopo desta fase (próximas)
CRUDs completos de Cliente/Produto/Config, limites por plano, white-label servido por config, tempo real (WebSocket), conexão do frontend, deploy Docker + budget alert.
