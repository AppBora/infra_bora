# BoraHapp — manual da marca

Gerado por `python gerar_identidade.py`. **Nao edite PNG nem SVG a mao**: a proxima geracao
apaga. O briefing e o raciocinio do simbolo estao no topo de `gerar_marca_v2.py`.

---

## 1. O que a marca diz, e por que o simbolo e esse

A landing afirma: *"um painel que tem a cara da sua loja. **Nao a nossa**"* e *"sem taxa por
pedido"*. Isso decidiu o desenho, nesta ordem:

**O BoraHapp nao e uma marca de comida.** E a infraestrutura embaixo da marca de comida do
cliente. Sacola, talher e moto dizem "eu sou o delivery" — e quem e o delivery e o lojista. Um
simbolo de categoria aqui **compete com a marca de quem paga**. Por isso a sacola saiu.

**"Bora" ja e movimento.** E imperativo falado. A seta era redundancia — e morria abaixo de
32 px.

**O que sobra para o simbolo dizer e presenca, nao categoria.** Marca que vai conviver ao lado da
marca do lojista tem de ser firme e quieta. Daí o monograma.

**E uma escolha deliberadamente sobria.** Letra em quadrado e um padrao comum em software (e e
comum porque funciona). Para uma marca que nao pode roubar a cena do cliente, sobrio e a resposta
certa — nao a resposta facil.

---

## 2. As pecas

| Arquivo | O que e | Use quando |
|---|---|---|
| `borahapp-horizontal` | simbolo + palavra, lado a lado | o padrao. Cabecalho, slide, assinatura de e-mail |
| `borahapp-vertical` | simbolo em cima, palavra embaixo | espaco estreito e alto; cracha; adesivo |
| `borahapp-simbolo` | so o quadrado com o B | favicon, atalho de celular, avatar, carimbo |
| `*-papel` | sobre `#FBF7F3` | material impresso da marca |
| `*-escuro` | sobre `#1B1512` | slide escuro, video |
| `borahapp-simbolo-tinta` | monograma em uma cor so | fax, carimbo, gravacao, bordado |

PNG com 2400 px de largura (simbolo com 1200). SVG com o texto em **curvas** — abre igual na
maquina de quem receber, sem a fonte instalada.

---

## 3. O "B" e um FURO, e isso nao e detalhe

A letra nao e pintada por cima do quadrado: e um **recorte**. Por isso a marca funciona em uma cor
so — carimbo, bordado, serigrafia, papel timbrado preto — e por isso, no fundo escuro, o preto
atravessa o B. Logo que so existe em duas cores quebra no primeiro uso fora da tela.

---

## 4. Cor

| Nome | Codigo | Papel |
|---|---|---|
| brasa | `#D9502B` | a cor da marca. O quadrado, e "Happ" |
| tinta | `#1B1512` | "Bora", e todo texto sobre claro |
| papel | `#FBF7F3` | fundo da marca, e o B vazado sobre o brasa |
| brasa clara | `#E8603B` | **so** sobre fundo escuro — o `#D9502B` fecha demais contra o preto |
| verde | `#176B4F` | apoio, nunca na marca |

**Uma cor no simbolo.** Tres cores num quadrado de 16 px viram papa — foi o que aconteceu com a
marca anterior.

---

## 5. Tipografia

A palavra e **Segoe UI Black**, a primeira da pilha que o site ja usa. Nos arquivos ela esta em
curvas, entao nada depende de instalacao.

"Bora" em tinta, "Happ" em brasa. **Sem espaco, sem hifen, sem camelCase extra**: `BoraHapp`.

---

## 6. Area de respiro e tamanho minimo

**Respiro:** deixe em volta, livre de qualquer coisa, uma margem igual a **metade do lado do
quadrado**. Nada entra nessa faixa — nem texto, nem borda, nem foto.

**Tamanho minimo**, medido e nao estimado (ver `prova-16px-novo-x-anterior.png`):

| Peca | Minimo | Por que |
|---|---|---|
| simbolo | **16 px** | abaixo disso o B fecha |
| horizontal | **110 px** de largura | abaixo, "Happ" empasta |
| vertical | **90 px** de largura | idem |

---

## 7. Usos proibidos

- esticar, espremer ou inclinar;
- trocar a cor do quadrado por outra que nao `brasa`, `tinta` ou `papel`;
- pintar o B em vez de vazar;
- por sombra, brilho, contorno ou degrade;
- por o logo sobre foto movimentada sem uma chapa solida atras;
- reescrever a palavra em outra fonte;
- usar o horizontal abaixo de 110 px — use o simbolo sozinho.

---

## 8. O que continua aberto, e e decisao do dono

1. **A identidade antiga ainda esta no produto.** O quadrado roxo `#7c3aed` e o favicon de todas
   as telas do painel e o logo da tela de cadastro. Enquanto nao for trocado, convivem duas
   marcas. **Nada do produto foi alterado** para gerar este manual.
2. **O nome falado.** "BoraHapp" tropeca em voz alta: e "Bora" + "Happ"? "Bora App"? Se a marca
   vai ser dita em palestra e em venda, isso vale mais que o icone. Nao e coisa que eu decida
   sozinha.
3. **O verde.** Ficou como cor de apoio e nao entra na marca. Se ele tiver significado no
   produto (status, "no ar"), precisa de regra propria.
