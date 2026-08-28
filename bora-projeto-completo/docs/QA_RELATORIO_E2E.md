# Relatório de QA — Teste End-to-End das Novas Funcionalidades

**Data:** julho/2026 · **Método:** auditoria estática por um time de 4 agentes de QA (o backend Java não pôde ser compilado nem o Asaas acessado neste ambiente; a verificação rastreou cada fluxo endpoint → service → repositório → banco e front → api → endpoint). Um **script de smoke-test** (`scripts/smoke-test.sh`) acompanha este relatório para o teste dinâmico quando a stack subir.

**Escopo testado:** Rede & Análise (4 telas), representatividade no balancete, provisionamento de loja (defaults), onboarding (prontidão), recebimento PIX via subconta Asaas + split, e toda a integração frontend.

---

## Veredito geral

**APROVADO** após correção de 1 bug de segurança. 3 dos 4 fluxos passaram sem ressalva crítica; o 4º apontou um vazamento de credencial que **já foi corrigido** nesta rodada.

| Frente | Veredito | Bugs |
|---|---|---|
| Auth, multi-tenant e Rede/Análise | Aprovado com ressalvas | 0 críticos |
| Provisionamento + Onboarding | Aprovado (tudo PASS) | 0 |
| Recebimento Asaas (subconta/PIX/split) | Aprovado após correção | **1 corrigido** |
| Frontend + prontidão de build | Aprovado (tudo PASS) | 0 |

---

## Bug encontrado e corrigido

**[SEGURANÇA] Vazamento da `asaasApiKey` na serialização da entidade `Loja`.**
`GET /admin-bora/lojas` (`PlataformaController.listarLojas`) devolvia `List<Loja>` serializada crua. Como `Loja` expõe campos públicos, a resposta incluía a `asaasApiKey` — a credencial viva de pagamento da subconta do lojista. Mesmo restrito ao `ADMINISTRADOR_BORA`, uma chave de API não deve trafegar em JSON.

**Correção aplicada:** anotado `@JsonIgnore` sobre `Loja.asaasApiKey`, o que remove o campo de qualquer serialização (não só desse endpoint). Os fluxos que precisam do dado (`AsaasSubcontaService.view()` e a cobrança PIX) montam o próprio JSON e devolvem apenas `status/walletId/onboardingUrl/paymentId` — nenhum segredo. O smoke-test tem um check específico para garantir que a chave não reaparece.

---

## Resultados por frente

### 1. Autenticação, multi-tenant e Rede & Análise — aprovado com ressalvas
- **Sem IDOR:** todos os endpoints `/api/analise/*` e `/api/rede/*` escopam pelas lojas vinculadas ao usuário (`usuario_loja`), nunca por id vindo do cliente. `trocarLoja` valida o vínculo antes de emitir novo token.
- **Deny-by-default:** `SecurityConfig` só libera `/auth`, `/public`, `/webhooks`, health e swagger; `/api/**` exige JWT. `requirePapel("ADMINISTRADOR_LOJA")` aplicado nos painéis.
- **Tipos e queries:** sem casts `Object→primitivo` inseguros (usa `((Number) …).longValue()`); todas as derived queries (ex.: `findByLojaIdAndDataHoraGreaterThanEqualOrderByPedidoIdAscDataHoraAsc`) são válidas; divisões por zero protegidas.
- **Ressalva (não crítica):** os painéis de análise filtram `criadoEm >` (estritamente maior) enquanto o balancete usa `>=`. Diverge só para um pedido criado exatamente à meia-noite do dia inicial — praticamente impossível (timestamps têm precisão de sub-segundo). Documentado; sem correção por ora.
- **Ressalva (performance):** algumas consultas fazem `findById` por loja (N+1). Aceitável para redes pequenas; otimizável com `findAllById`.

### 2. Provisionamento + Onboarding — aprovado (tudo PASS)
- `ProvisionamentoService.semear` é **idempotente** (só cria o que falta) e é chamado nos dois pontos de criação: `SignupController` (ambos os ramos — usuário novo e dono de rede que vincula outra loja) e `PlataformaController`.
- Todos os campos semeados existem e são acessíveis; `@Transactional` correto (bean separado, sem self-invocation).
- `OnboardingService` calcula a prontidão % corretamente (obrigatórios concluídos / total), lê cada passo do repositório certo e é resiliente a nulos (loja sem `ConfiguracaoLoja`/assinatura não gera NPE).

### 3. Recebimento Asaas (subconta + PIX + split) — aprovado após correção
- **Entity ↔ migration em sincronia:** as 5 colunas novas da `Loja` batem 1:1 com a `V26` — o app sobe com `ddl-auto: validate`.
- **PixService:** seleção correta de apiKey (subconta do lojista → senão chave legada), corpo mutável, split só quando via subconta + wallet da plataforma + taxa > 0. `@Value` batem com o `application.yml`.
- **PublicController:** PIX funciona com subconta ativa mesmo sem integração PIX legada; sem NPE.
- **AsaasSubcontaService:** idempotente, trata Asaas não configurado (503), captura erro (status ERRO), exige papel de admin.
- **Correção:** o vazamento da apiKey (acima).

### 4. Frontend + prontidão de build — aprovado (tudo PASS)
- **9/9 helpers do `api.js`** apontam para endpoints existentes (método + caminho conferidos).
- IDs e pontos de montagem conferidos: `rede.html` (27 IDs), `#onboardingMount` na dashboard e `#recebimentoMount` nas integrações, com os `<script>` incluídos.
- Sintaxe JS validada (`node --check`) nos arquivos novos. Os "erros" em `api.js`/`app.js` foram confirmados como **falso-positivo de cache do OneDrive** no mount — a fonte autoritativa está íntegra.
- Varredura de compilação nos arquivos Java novos/alterados: imports, chaves, assinaturas de repositório e ausência de colisão de `@RequestMapping` — tudo OK.

---

## Como rodar o teste dinâmico (E2E real)

```bash
# 1) suba a stack
cd bora-fase-3-backend-java && docker compose up --build -d

# 2) rode o smoke-test (precisa de curl e jq)
cd ../bora-projeto-completo/scripts
BASE=http://localhost:8080 ./smoke-test.sh
```

O script exercita: health, login, onboarding/prontidão, defaults semeados, os 5 endpoints de rede/análise, representatividade no balancete, status de recebimento, o cadastro self-service com defaults automáticos, o check anti-vazamento da apiKey e o bloqueio sem token. Sai com código 0 se tudo passar.

### Testes que exigem ambiente externo (fora do smoke)
- **Subconta Asaas real:** criar `POST /api/recebimento/ativar` com CNPJ no **sandbox do Asaas** (precisa de `ASAAS_API_KEY` da conta-mãe e da funcionalidade de subcontas liberada pelo gerente). Validar retorno de `apiKey/walletId` e o link de KYC.
- **Split:** definir `ASAAS_PLATFORM_WALLET_ID` + `ASAAS_TAXA_PERCENTUAL` e conferir, num pagamento de teste, que a taxa cai na carteira da plataforma e o restante na subconta do lojista.
- **Isolamento com 2 lojas:** criar duas lojas, logar em cada e confirmar que uma não lê dados da outra (inclusive por id direto) — o QA validou isso estaticamente; vale confirmar em runtime.

---

## Pendências recomendadas (não bloqueantes)
1. Padronizar a borda da janela de tempo (`>=`) entre balancete e análise.
2. Reduzir N+1 nas agregações de rede (`findAllById`).
3. Testes automatizados de regressão (JUnit + MockMvc com Testcontainers) para os fluxos acima — próximo passo natural de QA.
