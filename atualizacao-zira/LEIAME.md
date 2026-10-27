# Atualização de preços da Zirá — cardápio de 23/10/2026

Comparei o cardápio das fotos com o que está **no ar** hoje (li o cardápio público da loja 18, não
digitei o estado atual). O resultado:

| | |
|---|---|
| preços de produto que mudam | **10** |
| adicionais que mudam | **329**, em 16 produtos |
| tamanhos do Açaí Puro | **4** |
| produtos a renomear e reprecificar | **3** |
| produtos novos | **6** |

## Por que um script, e não na mão

**O grupo de adicionais é copiado dentro de cada produto — não é um só compartilhado.** Trocar
"Kit Kat R$ 2,50 → R$ 4,00" são **15 edições**, uma por produto. No total são 329. Na tela isso é
meio dia de cliques, com erro garantido em algum lugar.

O script faz as mesmas chamadas que as telas fazem, pelo seu próprio login. **Eu não vejo senha
nem token** — quem roda é você, no seu navegador, já logado.

## Como rodar

1. Entre no painel e **entre na loja da Zirá** (loja 18). Confira o nome no topo.
2. Qualquer tela, `F12` → aba **Console**.
3. Cole o `aplicar-precos-zira.js` inteiro e aperte Enter.
   **Na primeira vez ele não muda nada** — só imprime a lista do que faria.
4. Leia a lista. Se estiver certa, troque `const APLICAR = false` para `true`, cole de novo.

Ele **para sozinho** se você estiver na loja errada, e também se a conta não puder ver custo
(gravar assim apagaria o custo de todos os produtos).

## As três decisões que você tomou

- **Os especiais viram 9 produtos.** Ziraninho, Ziraçoca e Ziratella × 300/500/770ml
  (R$ 24,90 / 29,90 / 34,90). Os três que já existem viram o de 300ml, e nascem 6 novos com os
  mesmos adicionais copiados.
- **Os 19 produtos fora do cardápio não são tocados** — bebidas, sorvetes, garrafinhas, caixas,
  Copo Fitness, Whey, Cozinheiras, Napolitano e mantimentos seguem como estão.
- **"Monte Seu Açaí" vai de R$ 90,00 para R$ 0,00.** O preço passa a vir só do recipiente, que é
  como o cardápio novo apresenta o Açaí Puro.

## O que o script NÃO manda, de propósito

Cada um destes é um defeito que o código já pagou caro uma vez:

- **`imagemUrl`** — o servidor grava esse campo quando ele vem. Devolver o *endereço* da foto
  apagaria a foto de verdade.
- **`estoque`** na edição — o servidor ignora de propósito; mandar o número que a tela carregou
  apagaria o consumo do dia.
- **`insumoId` e `quantidade`** dos adicionais são **preservados**: é a ligação com a ficha
  técnica, e perdê-la pararia a baixa de insumo por adicional.
- **`custo` e `estoqueMinimo`** voltam com o valor exato que foram lidos, porque o servidor grava
  os dois sem condição.

## Três coisas que achei e que valem sua decisão depois

1. **"Monte Seu Açaí" está vendendo a R$ 100,00.** Base R$ 90,00 mais o recipiente obrigatório de
   R$ 10 a R$ 50. Ele está **ativo no cardápio público agora**. O script zera a base, mas vale
   conferir se o desenho é esse mesmo.
2. **"Ziraniho" está escrito com um "n" a menos** que o cardápio ("Ziraninho"). O script corrige
   junto com o tamanho.
3. **"Copo do Patrão 700ml"** — o cardápio novo diz **770 ML**. Não renomeei: você pediu preços, e
   nome de produto aparece no pedido do cliente. Se quiser, é uma linha.
4. **Granola e Leite Condensado** aparecem como adicional pago de R$ 2,00, e o cardápio novo não
   lista preço pago para eles (só no combo grátis). Ficaram como estão.

## Antes de rodar, uma coisa fora deste assunto

**O acesso da Zirá vence em 26/10.** Se vencer, o cardápio dela sai do ar e nada disto vai
aparecer para o cliente.
