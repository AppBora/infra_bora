# Estoque da Zirá — a ordem, e por quê

Tudo aqui foi lido na produção em **24/10/2026**, somente-leitura. Loja 18.

---

## 🔴 Antes do estoque: ela está cobrando menos do que o cardápio impresso

Isso eu achei conferindo o import, e vale mais que o resto desta página. Comparei o arquivo
`atualizacao-zira/cardapio-impresso-para-colar.txt` (que saiu das suas duas fotos do cardápio) com
os preços que estão no ar **agora**:

| produto | está cobrando | o papel diz | diferença |
|---|---|---|---|
| Barca de Açaí Gourmet | R$ 39,00 | **R$ 47,90** | +8,90 |
| Roleta de Açaí Gourmet | R$ 38,00 | **R$ 50,90** | +12,90 |
| Copo do Patrão 700ml | R$ 27,90 | **R$ 36,90** | +9,00 |
| Copo da Patroa 500ml | R$ 22,90 | **R$ 31,90** | +9,00 |
| Leve 5 Pague 4 Açaí | R$ 59,60 | **R$ 74,90** | +15,30 |
| Titanic Tamanho Família | R$ 64,90 | **R$ 66,90** | +2,00 |
| Copo de Açaí 300ml | R$ 17,90 | **R$ 19,90** | +2,00 |
| Copo de Açaí 500ml | R$ 22,90 | **R$ 24,90** | +2,00 |
| Pote de Açaí 1L | R$ 37,00 | **R$ 35,90** | −1,10 |

**Nove itens saindo abaixo do papel, um acima.** Cada venda de Roleta hoje perde R$ 12,90. Isso não
depende de contagem, de ficha, de nada: é o passo 2 abaixo, e leva um minuto.

E **13 produtos do cardápio impresso não existem no sistema** — Açaí Puro (300/500/770ml e 1L),
Ziraninho, Ziraçoca e Ziratella (3 tamanhos cada). O cliente não consegue pedir nenhum deles pelo
aplicativo hoje.

---

## O estado medido

| o que | quanto |
|---|---|
| insumos cadastrados | **43** |
| insumos com contagem | **1** (Caixa de Morango) |
| insumos com custo | **1** |
| produtos ativos | 35 |
| produtos com ficha técnica | **0** |
| itens de complemento (adicionais) | 397, **0 ligados a insumo** |

---

## A armadilha que eu consertei hoje, e que você precisa entender

No banco, `0` e "vazio" **não são a mesma coisa**:

- **`0` = "não tem nenhum"** → **bloqueia a venda**. Assim que o insumo entra numa ficha técnica, o
  cardápio marca o produto como **esgotado** para o cliente.
- **vazio = "esta loja não controla o estoque deste item"** → não bloqueia nada.

Os 43 insumos foram criados com **zero**, porque o importador que eu escrevi gravava zero fixo, e
porque eu entendi "deixa com zero" literalmente. Eram 42 itens que a loja **tem na prateleira**,
marcados como "não tem nenhum". Enquanto não havia ficha, inofensivo. **No minuto em que a primeira
ficha fosse salva, o cardápio inteiro apagaria para o cliente** — sem erro nenhum na sua tela.

Pior: a tela de Estoque **escondia** quem estava com vazio e chamava o zero de RUPTURA. Ou seja, ela
mostrava a mentira e sumia com a verdade.

**Já está no ar o conserto** (conferido por md5 pelo HTTPS, e o arquivo baixado de produção compila):

- insumo aparece **sempre** na tela de Estoque, com selo **SEM CONTAGEM** em vez de RUPTURA;
- os números do topo falam só de quem tem contagem, e entrou um quarto: **"Insumo sem contagem"**;
- **apagar o campo da quantidade** passa a significar "não controla estoque" — era uma capacidade
  que o servidor já tinha e que nenhuma tela conseguia usar;
- sem contagem não mostra os botões `+`/`−`, porque o servidor recusaria com erro;
- o importador passa a criar **sem contagem**, não em zero. Isso **reverte** o "cadastra zerado" que
  você pediu — o pedido foi feito quando não havia ficha, e aí zero era inofensivo.

---

## A ordem, e o motivo de cada posição

### Passo 1 — Tirar os 42 do zero · ~4 minutos · **Estoque**

Abra **Estoque**. Os 42 aparecem com `0` e selo RUPTURA. Em cada um, **apague o número do campo** e
saia do campo. Ele passa a dizer **SEM CONTAGEM**.

Se a loja já puder contar, melhor ainda: **digite a contagem** em vez de apagar. Aí o controle de
estoque liga de verdade para aquele item. Os dois caminhos deixam a ficha segura; a diferença é que
contar também te dá baixa automática na venda.

**Por que é o passo 1:** sem isso, o passo 3 apaga o cardápio.

### Passo 2 — Importar o cardápio · ~1 minuto · **Produtos → Importar**

Cole o conteúdo de `atualizacao-zira/cardapio-impresso-para-colar.txt`. Vai dizer
**13 a criar · 10 a atualizar · 0 já igual**.

**É seguro:** o import só cria e atualiza. Os **25 produtos que não estão no arquivo** (Coca-Cola,
sorvetes Natuice, garrafinhas, caixas de 5L e 10L, Monte Seu Açaí) **não são tocados**, e produto
que você desativou não é religado. Conferi no código antes de escrever isto.

**Depois do import, 3 ficam repetidos:** existem hoje "Ziraçoca", "Ziraniho" e "Ziratella" **sem
tamanho**, e o import cria as versões com tamanho. Desmarque "ativo" nesses três. (De passagem:
"Ziraniho" está escrito errado no banco — falta o "n".)

**Por que vem antes da ficha:** a ficha é por produto, e 13 dos produtos ainda não existem.

### Passo 3 — Montar as fichas técnicas · **Produtos → 🧪 → Importar**

Cole `atualizacao-zira/fichas-para-colar.txt`. **Só depois do passo 1.**

### Passo 4 — Custo de cada insumo · **Insumos**

42 estão em R$ 0,00. Sem custo, a ficha não te dá margem nenhuma — ela sabe *quanto* de cada coisa
entra, mas não *quanto custa*. Esse número vem das notas da fornecedora: é dado que só a loja tem.

### Passo 5 — Ligar os 397 adicionais aos insumos

397 itens de complemento, nenhum ligado. Enquanto não estiverem, um açaí com 5 adicionais baixa só
o que está na ficha do copo — os adicionais saem de graça do estoque. É o passo mais longo e o menos
urgente dos cinco.

---

## O que eu não consigo fazer, e por que

Meu acesso ao banco de produção é **somente-leitura**, de propósito. Todos os cinco passos são
cliques e colagens seus. O que eu fiz foi: medir cada número aqui, consertar a armadilha do zero,
preparar os arquivos para colar, e conferir no código que o import não apaga os seus 25 produtos.
