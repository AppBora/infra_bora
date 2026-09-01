# Plano — Gestão de clientes pela plataforma e empresa multi-loja

> Levantado em 2026-09-01 por cinco frentes (produto, arquitetura, backend, banco e segurança) lendo o
> código em produção. Nada foi implementado ainda: este documento existe para ser aprovado antes.

Dois pedidos do dono deram origem a isto:

1. **"Como adm eu deveria ver todas as lojas e poder cadastrar, desabilitar e excluir."**
2. **"Uma empresa (ex.: Zirá Montreal) pode ter várias lojas, e um GERENTE deve navegar entre elas
   com o login dele."**

---

## 1. O que já existe (e funciona)

| Peça | Onde | Situação |
|---|---|---|
| Listar todas as lojas | `PlataformaController:49` | ✅ (sem paginação nem filtro) |
| Criar loja com CNPJ | `PlataformaController:56` + tela nova em `configuracoes.html` | ✅ |
| Módulo IA, preço e split por loja | `PlataformaController:97/108/121` | ✅ |
| Vínculo usuário ↔ loja (N:N) | `usuario_loja`, `V17__rede_multi_loja.sql` | ✅ tabela pronta |
| Trocar de loja no login | `RedeService.trocarLoja:68` | ✅ **valida o vínculo** e reemite o token |
| Rede: minhas lojas, balancete, análises | `RedeService`, `AnaliseRedeService` | ✅ já liberado para GERENTE |
| Todos os `/admin-bora/*` com checagem de papel | `PlataformaController` (7 endpoints) | ✅ |

**A mecânica de "um login em várias lojas" já está construída e é segura.** O que falta é o vínculo
poder ser criado para alguém além do dono: hoje ele só nasce quando a pessoa refaz o cadastro público
com o mesmo e-mail e senha (`SignupController:65`), e apenas para `ADMINISTRADOR_LOJA`.

## 2. O que está quebrado ou ausente

1. **"Desabilitar" quase não desabilita.** `loja.ativo` só derruba o cardápio público
   (`PublicController:356`). O login da equipe (`AuthController:36`) e o filtro de cada request
   (`JwtAuthFilter:37`) **não olham a loja** — o lojista de uma loja desativada continua operando o painel.
2. **O webhook do Asaas desfaz a ação do adm.** Qualquer `PAYMENT_CONFIRMED` chama
   `ativarLoja(id, true)` (`AssinaturaService:88`). Desabilitou na mão? A próxima mensalidade reativa.
3. **Não existe cancelar assinatura no Asaas.** O `AsaasClient` só cria cliente, cria e atualiza
   assinatura. Excluir cliente hoje = ele **continua sendo cobrado**.
4. **Excluir de verdade corrompe o banco.** 6 tabelas têm FK para `loja` e travariam o delete;
   **16 não têm FK nenhuma** (`pedido`, `cliente`, `produto`, `assinatura`, `acerto_entregador`…) e
   ficariam órfãs em silêncio.
5. **Não existe empresa.** `loja.documento` é texto livre, sem unicidade e sem validação — não há como
   dizer "estas 3 lojas são da Zirá".
6. **Não existe endpoint para vincular um usuário a outra loja**, nem para desvincular.
7. **O papel é global, não por loja** (`Usuario.papel`): quem é GERENTE numa loja é GERENTE em todas
   as que estiver vinculado.
8. **Sem auditoria** de ações administrativas sobre lojas, e sem `criado_em` na loja (o `MODELO_DADOS.md`
   promete o campo, o schema não tem).

## 3. Decisões tomadas no levantamento

- **Excluir = arquivar.** Soft delete (`excluida_em`, `excluida_por`, `motivo_exclusao`), nunca
  `DELETE`. Motivo técnico: as FKs acima. Motivo legal: a Privacidade publicada promete reter dados
  "pelo tempo necessário às obrigações legais", e `assinatura`/`acerto_entregador` são registros
  financeiros. Expurgo físico, se um dia for preciso, vira script manual por loja.
- **Suspensão administrativa em campo próprio**, separado do `loja.ativo` que o Asaas controla — senão
  o webhook desfaz a decisão do adm.
- **Criar a entidade `Empresa`** (razão social + CNPJ único) com `loja.empresa_id`, mantendo o
  `usuario_loja` como está. São coisas diferentes: empresa é fato societário, vínculo é controle de
  acesso. Sem empresa não há como validar "só vincule a lojas da mesma dona" — e essa validação é o
  que impede um admin de loja vincular um usuário seu à loja de outro cliente.
- **O `empresa_id` não entra no token nem nas queries.** O isolamento continua por `loja_id`, como hoje,
  em ~22 pontos do código. Empresa é só camada de autorização.

## 4. Decisões que dependem do dono

1. **Desabilitar deve cortar o acesso da equipe ao painel?** (recomendado: sim; hoje não corta)
2. **Papel por loja ou papel global?** Manter global é barato e serve para a Zirá; papel por vínculo
   (gerente numa loja, operador em outra) muda o schema e o token.
3. **Qual prazo de retenção** antes de um eventual expurgo físico? Nada foi prometido ao lojista, então
   é decisão livre — alinhar com contador.

## 5. Fases (cada uma deployável sozinha)

### Fase 1 — Desabilitar que desabilita *(backend, V30)*
- `V30`: `loja.suspensa_pela_plataforma`, `loja.excluida_em`, `excluida_por`, `motivo_exclusao`,
  índice parcial `WHERE excluida_em IS NULL`.
- `AsaasClient.cancelarAssinatura()` — hoje inexistente.
- `PUT /admin-bora/lojas/{id}/ativo` e `PUT /admin-bora/lojas/{id}/arquivar`, ambos com
  `requireAdminBora()` e registro de auditoria.
- `AuthController.login` e `JwtAuthFilter` passam a recusar loja suspensa/arquivada.
- Pedido em andamento continua podendo ser concluído; o corte vale para login novo e cardápio.
- **Testes:** token emitido antes da suspensão morre no request seguinte; login em loja suspensa dá 401;
  webhook de pagamento **não** reativa loja suspensa administrativamente; assinatura cancelada no Asaas.

### Fase 2 — Painel de clientes *(frontend)*
Lista com nome, documento, status da assinatura, preço efetivo, Módulo IA, taxa PIX, usuários (x/15),
toggle ativo e ações arquivar/restaurar; aba "arquivadas". Sem inventar métrica que o sistema não tem —
"criado em" e "último pedido" ficam para depois dos campos existirem.

### Fase 3 — Empresa *(V31, puramente aditiva)*
Tabela `empresa` (CNPJ único) + `loja.empresa_id` + backfill agrupando por `documento`.
⚠️ O backfill é heurístico: CNPJ digitado errado funde lojas indevidamente. Com o número atual de
lojas, conferir à mão antes de rodar.

### Fase 4 — Gerente multi-loja *(backend + frontend)*
- `POST /api/rede/usuarios/{id}/lojas` e `DELETE .../{lojaId}`, validando **mesma empresa**.
- Revalidação do vínculo a cada request (ou TTL curto) — **na mesma fase**, senão um gerente
  desvinculado segue entrando por até 24h com o token velho.
- `trocarLoja` passa a recusar loja inativa/arquivada.
- Seletor de loja no menu para o GERENTE, reaproveitando `GET /api/rede/lojas`.
- **Testes:** admin da loja A não consegue vincular ninguém a uma loja de outra empresa (403);
  desvinculado perde acesso no request seguinte; gerente só enxerga as lojas vinculadas.

## 6. Riscos

| Risco | Mitigação |
|---|---|
| Webhook do Asaas reativa loja suspensa | Campo de suspensão separado (Fase 1) |
| Delete físico corrompe 16 tabelas sem FK | Nunca deletar; só arquivar |
| Cliente arquivado continua sendo cobrado | Cancelar assinatura antes de arquivar (Fase 1) |
| Token velho após desvínculo (janela de 24h) | Revalidação por request na Fase 4 |
| Vínculo cross-tenant por endpoint novo | Validar `empresa_id` — por isso a Fase 3 vem antes da 4 |
| Bloquear login por loja inativa derruba loja legítima | Fase 1 só depois do campo separado; testar com loja real |
