# Conectar um cliente em tudo que o BoraHapp oferece

> Levantado do código em produção em 2026-09-04. Cada item diz **quem fornece**, **onde entra**,
> **como testar** e **o que deixa de funcionar sem ele** — é isso que evita prometer o que não entrega.

---

## 1. Mapa dos serviços

### Nasce pronto no cadastro (não precisa configurar)
O `ProvisionamentoService` semeia toda loja nova: **4 formas de pagamento** (dinheiro com troco, PIX,
crédito, débito), **5 motivos de cancelamento**, **7 horários** (dom–sáb, 18h–23h) e **cashback de 5%**
no cardápio. O cardápio público, o app instalável (PWA), o QR e o link de acompanhamento do pedido
funcionam desde o primeiro minuto.

> ⚠️ O horário semeado quase sempre está errado, e o cashback de 5% é uma decisão comercial que ninguém
> tomou. Confira os dois **antes** de entregar a loja.

### O lojista configura (sem depender de terceiros)
Marca (logo e cores), cardápio (produtos, fotos, complementos), taxas por bairro, horário real, equipe,
entregadores, promoções e cupons, insumos e ficha técnica.

### Depende de terceiro
Assinatura (Asaas), PIX online (subconta Asaas + KYC), marketplaces (iFood, 99Food), robô de WhatsApp
(Meta) e o Módulo IA (chave da Anthropic).

---

## 2. Pré-requisitos da plataforma — uma vez, valem para todos os clientes

| Serviço | Variável no `api.env` | Sem isso |
|---|---|---|
| Cobrança da mensalidade | `ASAAS_API_KEY`, `ASAAS_WEBHOOK_TOKEN` | Nenhum cliente assina |
| Split do PIX | `ASAAS_PLATFORM_WALLET_ID`, `ASAAS_TAXA_PERCENTUAL` | Sem retenção (hoje = 0, decisão do dono) |
| Módulo IA | `BORA_CLAUDE_API_KEY` | Cardápio por foto, Gerente Virtual e recuperador respondem 409 |
| iFood | `BORA_IFOOD_CLIENT_ID/SECRET` | Canal inerte; exige homologação como integradora |
| 99Food / Open Delivery | `BORA_OPENDELIVERY_CLIENT_ID/SECRET` | Canal inerte — **ou** use a credencial da própria loja |
| Acesso do super-admin | `BORA_BOOTSTRAP_SUPERADMIN_EMAIL/SENHA` | Sem card Plataforma (e não há tela para recriar) |

**Estado em 2026-09-04:** Asaas ✅ · split 0% ✅ · super-admin ✅ · Claude ❌ · iFood ❌ (em fila) ·
99Food ❌ (qualificação da ADF em análise) · Meta ❌ (bloqueio do número de teste).

---

## 3. Roteiro por cliente

### Passo 1 — Criar a loja (2 minutos)
Configurações → card 🔧 **Plataforma** → **➕ Nova loja**: nome, CNPJ, responsável, e-mail, senha
provisória, preço (vazio = R$ 199 de tabela). O CNPJ cria a **Empresa** — lojas com o mesmo CNPJ caem
na mesma empresa, e aí um gerente atende todas com um login só.

**Depois:** libere o Módulo IA (se contratado) e ajuste o cashback na linha do cliente.

### Passo 2 — Entrar na loja
Botão **Entrar na loja**, na linha do cliente. Você opera dentro dela sem a senha do lojista, com
registro de auditoria. É assim que a plataforma faz o cadastro pelo cliente.

### Passo 3 — Conteúdo (o que torna a loja vendável)
1. **Marca** — logo e cor em Configurações
2. **Cardápio** — Produtos: um a um, colando a lista (`Categoria ; Nome ; Preço`), ou por foto (Módulo IA)
3. **Complementos** — botão 🧩 na linha do produto. Em açaí e pizza, isso é metade do pedido
4. **Entrega** — Ajustes › Taxas: bairro, valor e tempo. **Sem ao menos um bairro o cliente não fecha pedido**
5. **Horário real** — Ajustes › Horário
6. **Equipe e entregadores**, se houver

### Passo 4 — Dinheiro
- **Assinatura**: o lojista ativa em Planos com CPF/CNPJ. 7 dias de cortesia antes da 1ª cobrança.
  Só o `ADMINISTRADOR_LOJA` consegue. **Defina preço negociado antes disso.**
- **PIX online**: Integrações › Recebimento por PIX › Ativar. Cria subconta Asaas em nome do lojista
  (CPF/CNPJ, celular, endereço, CEP, faturamento) e devolve link de **KYC** (documentos + selfie).
  Vira ATIVO quando o Asaas aprova. **Sem isso o cardápio só fecha pedido para pagar na entrega.**

> Abrir conta financeira em nome do cliente é ação do dono da plataforma, não de terceiros.

### Passo 5 — Canais externos (opcional, depende de terceiros)

**99Food** — precisa de `Client ID` + `Client Secret` e do `merchantId` da loja. As credenciais podem
ser da plataforma (após aprovação da ADF) **ou do próprio lojista** (autoatendimento em
`developer-food.99app.com`); o sistema prefere a da loja quando existe. O merchantId sai do painel do
lojista — no cache de sessão aparece como `shopId`.

**iFood** — mesmo modelo, mas só com a homologação de integradora aprovada.

**Rappi, Uber Eats, aiqfome, Goomer** — estão no catálogo mas não são integrações oficiais: o vínculo é
manual, por credencial obtida em cada portal.

**WhatsApp** — por loja, na tela de Integrações: `clientId` = **Phone Number ID** e `clientSecret` =
**token de acesso** da API oficial da Meta (Graph v20). Hoje bloqueado na plataforma inteira porque a
Meta recusa envio do número de teste para o Brasil; destrava com chip BR novo ou verificação da empresa.

### Passo 6 — Add-ons pagos
**Módulo IA** (+R$ 99/mês por loja, liberado só pelo super-admin): cardápio por foto, Gerente Virtual
(resumo diário às 8h no WhatsApp do dono) e recuperador de clientes sumidos. Os dois últimos dependem
do canal de WhatsApp.

### Passo 7 — Aceitação antes de entregar
Pedido de ponta a ponta pelo celular: produto com complemento → cupom, se houver → fechar → avançar
status até ENTREGUE → conferir o link público de acompanhamento, a Dashboard e o Relatório.

---

## 4. O que quebra se cada peça faltar

| Falta | O cliente sente assim |
|---|---|
| Bairro com taxa | Não consegue fechar pedido com entrega |
| Horário real | Cardápio abre e fecha na hora errada |
| Logo e cor | Cardápio com a cara do BoraHapp, não da loja |
| Assinatura | Loja suspensa quando o webhook de inadimplência rodar |
| PIX online | Só paga na entrega — sem pagamento no ato |
| Credencial de marketplace | Pedidos do canal não entram no painel |
| WhatsApp | Sem robô e sem resumo diário |
| Chave da Claude | Cardápio por foto e recursos de IA respondem 409 |

---

## 5. Ordem recomendada

1. **Loja + conteúdo** — é o que ela contratou e não depende de ninguém
2. **Assinatura** — sem isso não há receita
3. **PIX online** — maior impacto entre os que dependem só de você e do lojista
4. **WhatsApp** — chip novo resolve em horas
5. **Marketplaces** — dependem de aprovação de terceiro; comece cedo, entregue por último
