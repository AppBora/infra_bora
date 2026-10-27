# Insumo, produto, ficha técnica e a baixa na venda

Tudo neste documento foi lido no código, não é de cabeça. Os caminhos estão citados para você
poder cobrar depois.

---

## As três peças

| | o que é | tem | onde se cadastra |
|---|---|---|---|
| **Insumo** | o que você **compra e conta na prateleira** | unidade (un/kg/g/L/ml), custo, estoque | tela **Insumos** |
| **Produto** | o que o **cliente pede** | preço, categoria, foto | tela **Produtos** |
| **Ficha técnica** | **quanto de cada insumo vai em 1 produto** | insumo + quantidade | **Produtos → botão 🧪** |

A ficha é a ponte. Sem ela, insumo e produto não se falam.

---

## A regra de ouro

> **Produto COM ficha → a venda baixa os INSUMOS.**
> **Produto SEM ficha → a venda baixa o estoque do PRÓPRIO produto.**
> **Nunca os dois.**

Está em `PedidoService.java:244-268`, nesta ordem:

1. `consumirFicha(...)` tenta baixar os insumos da ficha.
2. Se o produto **não tem ficha**, essa chamada devolve `null`.
3. Só então: `if (custoFicha == null) baixarEstoque(produto)`.

É por isso que **produto acabado não precisa de estoque próprio** quando tem ficha: quem segura
o controle é o insumo. Foi exatamente o ponto que você levantou.

### Exemplo, com a Zirá

Ficha do **Copo de Açaí 300ml**:

| insumo | quantidade por copo |
|---|---|
| Polpa de Açaí | 0,3 kg |
| Copo 300ml | 1 un |
| Tampa 300ml | 1 un |
| Colher Descartável | 1 un |

Vendeu **2 copos** → o sistema baixa 0,6 kg de polpa, 2 copos, 2 tampas e 2 colheres. O estoque
do produto "Copo de Açaí 300ml" **não é tocado**.

---

## O custo e a margem saem daí

Com ficha, o custo do item vendido é **a soma de (custo do insumo × quantidade)**. Sem ficha, é o
campo `custo` do produto.

É esse número que alimenta **CMV, margem e lucro** nos relatórios. Por isso o custo do insumo
importa: **com todos os insumos em R$ 0, a margem sai como 100% e o CMV como zero** — e os
relatórios ficam bonitos e errados.

---

## O adicional também baixa estoque

Desde a V55. Cada item de complemento (Kit Kat, Granola, Creme de Avelã...) pode ser **ligado a
um insumo**, com quantidade. Quando o cliente escolhe aquele adicional, o insumo dele sai do
estoque e o custo entra no custo do item (`InsumoService.consumirAdicionais`).

Isso se cadastra junto com os complementos do produto, não na ficha.

**Metade do valor de uma venda pode estar nos adicionais.** Sem essa ligação, a granola e o
leite condensado somem da prateleira sem o sistema saber.

---

## Quando a venda é RECUSADA por falta de insumo

Depende de quem está com o produto na mão — e é decisão de desenho, não acaso:

| canal | falta insumo | por quê |
|---|---|---|
| **Cardápio público** (cliente pelo QR) | **RECUSA** | O cliente não tem nada na mão. Vender e depois cancelar é pior que dizer "acabou" na hora. |
| **Balcão / PDV** | **PASSA**, e avisa | O operador está com o copo na mão. Travar a venda com o cliente na frente é pior que o saldo negativo — que pelo menos denuncia que a contagem está errada. |
| **Marketplace** (iFood/99) | **PASSA** | O pedido já foi aceito do outro lado. |

A recusa vem **do banco** (`consumirSeTiver`), não de uma conferência antes: duas vendas ao mesmo
tempo leriam o mesmo saldo e as duas passariam.

---

## "Esgotado" no cardápio

O cardápio marca o produto como esgotado quando (`PublicController.java:248`):

```
estoque do produto < 1   OU   a ficha não dá para fazer nem 1 unidade
```

Consequência prática, e é importante: **assim que você montar a ficha, o produto fica esgotado
enquanto qualquer insumo dela estiver zerado.** Hoje os 43 insumos da Zirá estão em zero. Monte a
ficha **depois** de lançar a contagem, ou o cardápio inteiro apaga.

É uma **foto**, não uma reserva: entre o cliente abrir o cardápio e confirmar, alguém pode levar o
último. Quem garante de verdade é a baixa no banco, na hora de gravar.

---

## Cancelamento devolve

Cancelou ou estornou, `devolverFicha` devolve os insumos — mesma conta, sinal trocado
(`EstornoDaVendaService.java:120`). O mesmo vale para os adicionais.

---

## Duas armadilhas que já existem na base

1. **Ficha fantasma.** `produto_insumo` não tem chave estrangeira. Se o insumo for apagado, a
   linha da ficha fica apontando para o nada. Hoje o sistema **recusa apagar** insumo que está em
   alguma ficha, mas base antiga já tem o problema — conferido em produção em 21/10/2026. Efeito:
   **o custo do item sai menor do que é.**

2. **Se TODOS os insumos da ficha sumiram**, o sistema trata o produto como se não tivesse ficha
   e baixa o estoque dele mesmo — em vez de gravar que consumiu e não consumir nada. É a melhor
   verdade disponível, mas é sinal de ficha quebrada.

---

## A ordem certa para a Zirá

1. **Lançar a contagem dos 43 insumos** em Estoque (hoje estão todos em zero).
2. **Preencher o custo de cada insumo** — sem isso, CMV e margem não existem.
3. **Importar o cardápio** (13 produtos novos, 10 preços).
4. **Montar as fichas** (Produtos → 🧪), produto por produto.
5. **Ligar os adicionais aos insumos**, nos complementos.

Os passos 1 e 2 **antes** do 4, senão o cardápio inteiro aparece esgotado para o cliente.
