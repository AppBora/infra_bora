# Os 4 itens de dados: levantados, não tocados

Levantamento de **27/10/2026**, feito com o banco de produção em **somente leitura**
(`PGOPTIONS='-c default_transaction_read_only=on'`). **Nenhuma linha foi alterada.**

São os 4 últimos achados abertos do bloco 🟡 do `PENTE-FINO-2026-10-26.md` — os outros 29 estão
fechados e no ar. Os quatro estão **inteiramente na loja 1**, que é a loja de QA
(`BoraQATest` / "Sorveteria da Rosa").

**Para nenhum deles eu escreveria `DELETE` em produção.** Três têm caminho auditado ou de tela, e o
quarto precisa de uma decisão que eu não tenho como tomar. O detalhe de cada um está abaixo.

---

## 1. Sete itens de pedido órfãos — não mexe em dinheiro

`pedido_item` apontando para pedido que não existe mais.

| id do item | aponta para o pedido | descrição | qtd | preço | custo |
|---|---|---|---|---|---|
| 3 | 4 | Açaí 500ml | 2 | 24,90 | — |
| 11 | 12 | Acai 500ml Atualizado | 1 | 26,90 | 7,50 |
| 26 | 26 | Acai 500ml Atualizado | 1 | 26,90 | 7,50 |
| 27 | 27 | Acai 500ml Atualizado | 1 | 26,90 | 7,50 |
| 33 | 33 | Acai 500ml Atualizado | 1 | 26,90 | 7,50 |
| 64 | 70 | Acai 500ml Atualizado (700ml, Granola, Nutella) | 2 | 40,40 | 7,50 |
| 65 | 72 | Acai 500ml Atualizado (700ml, Morango) | 1 | 42,90 | — |

**O que eles afetam:** nada de dinheiro. Conferi no código: nenhuma consulta soma `pedido_item` por
loja. Os relatórios juntam por id de pedido existente (`findByLojaIdAndPedidoIdIn`), então item órfão
nunca casa — não entra em faturamento, CMV nem margem.

O único lugar que os conta é a **prévia** da limpeza de movimentação de teste (`countByLojaId`), que
por causa deles diz 7 itens a mais do que existem.

**Caminho:** o botão **"limpar movimentação de teste"** (`itens.deleteByLojaId`) leva os sete, com
auditoria, backup antes, trava do nome digitado — e, desde 27/10, devolvendo o estoque dos pedidos.

---

## 2. Cinco pedidos apontando para cliente apagado — o risco não dispara

| pedido | código | status | criado | valor | cliente (apagado) | cashback usado | aguardando pgto |
|---|---|---|---|---|---|---|---|
| 1 | #1001 | ENTREGUE | 01/07 | 42,90 | 1 | — | não |
| 9 | — | CANCELADO | 01/07 | 26,90 | 8 | — | não |
| 25 | TST-TAXA-001 | ENTREGUE | 01/07 | 58,80 | 14 | — | não |
| 28 | — | ENTREGUE | 01/07 | 53,80 | 13 | — | não |
| 36 | TST-NOTFONE | ENTREGUE | 01/07 | 31,90 | 16 | — | não |

Dois já se anunciam como teste no próprio código (`TST-TAXA-001`, `TST-NOTFONE`).

**Por que o risco não dispara:** o caminho perigoso da v131 é *PIX pago depois do cancelamento, num
pedido que usou cashback, de um cliente apagado* → 409 em laço no webhook do Asaas, e o pagamento
nunca registrado. Medido: **`cashback_usado` é nulo nos cinco**, nenhum está aguardando pagamento e
nenhum foi pago online. Não há como aquele caminho ser alcançado por estes.

**O que sobra:** cosmético — aparecem sem nome de cliente e não entram em relatório por cliente.

**Caminho:** o mesmo botão de limpar movimentação de teste (`pedidos.deleteByLojaId`).

---

## 3. A ficha fantasma — a única que mexe em número hoje

Produto **1**, "Acai 500ml Atualizado", **ativo**, com duas linhas de ficha técnica:

| linha | insumo | quantidade | custo do insumo |
|---|---|---|---|
| 1 | 1 — Polpa de Açaí Orgânico | 0,5 | R$ 15,00 |
| 2 | **2 — não existe mais** | 0,2 | — |

Como sobra uma linha boa, o produto **não** cai no caminho de "produto sem ficha": o
`consumirFicha` conta 1 insumo consumido e devolve custo. O custo sai **0,5 × 15 = R$ 7,50** — que é
exatamente o `custo_unitario` gravado nos itens órfãos do item 1. **A parte do insumo fantasma
simplesmente não entra no CMV.**

**Por que eu não apago:** não sei o que era o insumo 2. Sei que eram 0,2 de algo, não sei de quê nem
quanto custava. A linha é a **única pista** de que falta um ingrediente nessa ficha — a tela já a
mostra como `?` e o `consumirFicha` já grava um aviso no log. Apagar trocaria uma ficha visivelmente
incompleta por uma ficha que parece completa e está errada.

**Caminho:** **Produtos → ficha do "Acai 500ml Atualizado"** — escolher o insumo certo, ou remover a
linha sabendo o que está removendo. É decisão de quem conhece a receita.

**De passagem:** o insumo 1 está com estoque **−11,500**. É o insumo negativo que não tinha aviso
nenhum até o conserto de 27/10 (`avisarSeOINSUMOvaiFicarNegativo`).

---

## 4. "Vale Refeicao" duplicado — um clique

| id | loja | descrição | com troco | online | ordem | ativo |
|---|---|---|---|---|---|---|
| 6 | 1 | Vale Refeicao | não | não | 0 | sim |
| 12 | 1 | Vale Refeicao | não | não | 0 | sim |

**O que quebra:** a lista de formas de pagamento mostra "Vale Refeicao" duas vezes, no balcão e no
checkout. A loja 1 tem 14 formas cadastradas.

**Por que remover é seguro, medido:** `pedido.forma_pagamento` guarda **texto**, não id (os valores
na base são "Pix", "Dinheiro (atualizado)", "Vale Refeicao"...), e **zero chaves estrangeiras**
apontam para `forma_pagamento`. Remover uma das duas não quebra referência nem perde histórico.

**Caminho:** **Ajustes → formas de pagamento → Remover** no id 12, com a confirmação que a tela já
pede.

---

## Resumo de quem faz o quê

| # | O quê | Caminho | Quem |
|---|---|---|---|
| 1 | 7 itens órfãos | botão de limpar movimentação de teste | dono, quando decidir sobre a loja de QA |
| 2 | 5 pedidos com cliente apagado | o mesmo botão | idem |
| 3 | ficha fantasma do produto 1 | Produtos → ficha | quem conhece a receita |
| 4 | Vale Refeicao duplicado | Ajustes → formas de pagamento → Remover | dono, um clique |

Os itens 1 e 2 são movimentação da loja de QA — e o **item 9** do `PENTE-FINO-SO-VOCE-PODE.md` já
pede uma decisão sobre essa loja, que domina todo relatório agregado (28 dos 33 pedidos da base). Se
essa decisão vier, **1 e 2 saem de lambuja**, pelo caminho auditado, em vez de por um `DELETE`
avulso.
