# BoraHapp — manual da marca

Gerado por `python gerar_identidade.py`. **Nao edite PNG nem SVG a mao**: a proxima geracao
apaga. O briefing e o raciocinio do simbolo estao no topo de `gerar_marca_v2.py`.

---

## 1. O que a marca diz, e por que o simbolo e esse

A landing afirma: *"um painel que tem a cara da sua loja. **Nao a nossa**"* e *"sem taxa por
pedido"*.

**A sacola e escolha do dono, feita em 28/10/2026**, depois de eu propor um monograma "B" e
mostrar a medicao. Ele manteve a sacola e pediu os quatro consertos. Fica registrado o que eu
argumentei, porque continua valendo: sacola e **sinal de categoria** -- ela diz "eu sou o
delivery", e quem e o delivery e o lojista, nao o BoraHapp. Esse ponto nao da para consertar
inteiro mantendo a sacola. O que deu para fazer foi **baixar o volume dela**: sem seta, sem
ponto, sem cor extra -- a sacola mais abstrata possivel ainda sendo sacola. Quem carrega a marca
e a palavra.

## 2. Os quatro consertos, e o que cada um resolveu

| Defeito da versao anterior | O que mudou |
|---|---|
| **Lia como cadeado** -- retangulo com UM arco centrado e a forma de fechadura | corpo **trapezio**, mais largo em cima (formato de sacola de papel), e **duas** alcas |
| **Morria em 16 px** | o desenho era de **linha**: 2,4 num simbolo de 48 vira 0,8 px em 16. Agora a sacola e **forma solida** -- e ha um **corte proprio de 16 px**, so o corpo |
| **O ponto verde** ocupava a posicao do selo de notificacao do iOS e do Android | **removido** |
| **"Eu sou o delivery"** | reduzido, nao resolvido: sem seta, sem ponto, forma mais abstrata |

**O movimento vem da inclinacao**, nao de seta. A sacola pende 4 graus para a frente: e a mesma
forma solida, entao nao custa nada em legibilidade, e diz carregada. "Bora" ja e pressa; o
simbolo nao precisa repetir.

**Dois erros meus no caminho, para ninguem refazer:** primeiro recortei as alcas como furos
DENTRO do corpo -- nao leu sacola, leu lixeira, e os dois rasgos viraram olhos. Depois, com as
alcas por cima, fiz o arco grosso e estreito: o **vao** quase fechou, e o vao e justamente o que
o olho le como alca.

## 3. Duas cores chapadas, e so

O quadrado numa cor, a sacola em outra. Sem contorno, sem furo, sem terceira cor. E o que faz a
marca sobreviver a carimbo, bordado, serigrafia e papel timbrado preto -- e o que a versao
anterior nao fazia, porque dependia de traco fino em tres cores.

## 4. As pecas

| Arquivo | Use quando |
|---|---|
| `borahapp-horizontal` | o padrao. Cabecalho, slide, assinatura de e-mail |
| `borahapp-horizontal-papel` / `-escuro` | sobre `#FBF7F3` / sobre `#1B1512` |
| `borahapp-simbolo` | avatar, canto de slide, qualquer uso a partir de 24 px |
| `borahapp-simbolo-16px` | **favicon e atalho de celular** -- so o corpo, sem alca |
| `borahapp-simbolo-tinta` | uma cor so: carimbo, gravacao, bordado |

PNG com 2400 px de largura (simbolo com 1200). SVG com o texto em curvas.

**Nao existe ainda a versao vertical.** O tamanho minimo dela esta na secao 7 por antecipacao.

## 5. Cor

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

## 6. Tipografia

A palavra e **Segoe UI Black**, a primeira da pilha que o site ja usa. Nos arquivos ela esta em
curvas, entao nada depende de instalacao.

"Bora" em tinta, "Happ" em brasa. **Sem espaco, sem hifen, sem camelCase extra**: `BoraHapp`.

---

## 7. Area de respiro e tamanho minimo

**Respiro:** deixe em volta, livre de qualquer coisa, uma margem igual a **metade do lado do
quadrado**. Nada entra nessa faixa — nem texto, nem borda, nem foto.

**Tamanho minimo**, medido e nao estimado (ver `prova-16px-novo-x-anterior.png`):

| Peca | Minimo | Por que |
|---|---|---|
| simbolo (com alca) | **24 px** | abaixo disso a alca funde com o corpo |
| `simbolo-16px` | **16 px** | e o corte feito para esse tamanho |
| horizontal | **110 px** de largura | abaixo, "Happ" empasta |
| vertical | **90 px** de largura | idem |

---

## 8. Usos proibidos

- esticar, espremer ou inclinar;
- trocar a cor do quadrado por outra que nao `brasa`, `tinta` ou `papel`;
- usar o simbolo com alca abaixo de 24 px -- use o `-16px`;
- devolver a seta, o ponto verde ou o contorno de linha;
- por sombra, brilho, contorno ou degrade;
- por o logo sobre foto movimentada sem uma chapa solida atras;
- reescrever a palavra em outra fonte;
- usar o horizontal abaixo de 110 px — use o simbolo sozinho.

---

## 9. O que continua aberto, e e decisao do dono

1. **A identidade antiga ainda esta no produto.** O quadrado roxo `#7c3aed` e o favicon de todas
   as telas do painel e o logo da tela de cadastro. Enquanto nao for trocado, convivem duas
   marcas. **Nada do produto foi alterado** para gerar este manual.
2. **O nome falado.** "BoraHapp" tropeca em voz alta: e "Bora" + "Happ"? "Bora App"? Se a marca
   vai ser dita em palestra e em venda, isso vale mais que o icone. Nao e coisa que eu decida
   sozinha.
3. **O verde.** Ficou como cor de apoio e nao entra na marca. Se ele tiver significado no
   produto (status, "no ar"), precisa de regra propria.
