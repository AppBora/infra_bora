# A marca do BoraHapp

Os arquivos desta pasta sao **gerados** por `python gerar_marca.py`. Nao edite o PNG nem o SVG a
mao: a proxima geracao apaga.

## ATENCAO: existem DUAS identidades no produto hoje

Isto apareceu ao procurar o logo, em 28/10/2026, e **e uma decisao do dono**, nao minha:

| | onde esta | como e |
|---|---|---|
| **Landing** (a cara publica) | `bora-landing/` | "Bora" em `#1B1512` + "Happ" em `#D9502B`, sobre papel `#FBF7F3`. Nenhum roxo. |
| **Roxa** (a do codigo) | `assets/img/logo-bora.svg`, `icone-bora.svg` | quadrado roxo `#7c3aed`, seta verde `#22c55e`, e a palavra **"Bora"** |

E a palavra tambem muda: o SVG diz **"Bora"**, o site diz **"BoraHapp"** 17 vezes na mesma pagina.
O favicon de TODAS as telas do painel e o roxo; a tela de cadastro tambem usa o roxo.

Enquanto isso nao for decidido, o gerador produz as duas. A **recomendacao** e a da landing: e o
que qualquer pessoa ve ao procurar o BoraHapp hoje.

## Os arquivos

| arquivo | para que |
|---|---|
| `borahapp-logo.png` / `.svg` | o logo, fundo transparente. O de uso geral. |
| `borahapp-logo-papel.png` | sobre o papel da marca (`#FBF7F3`) |
| `borahapp-logo-fundo-escuro.png` | sobre `#1B1512` |
| `borahapp-logo-para-fundo-escuro-transparente.png` | a versao clara, transparente, para por sobre foto escura |
| `borahapp-icone.png` / `.svg` | so o simbolo, quadrado, enchendo o quadro: avatar, canto de slide, favicon |
| `bora-logo-roxo.*`, `bora-icone-roxo.*` | a identidade roxa que esta no produto hoje |

PNG com 2400 px de largura (icone com 1200): aguenta projetor e impressao sem serrilhar.

## O que o gerador protege

**A palavra vira CURVA, nao texto.** O SVG original escreve "Bora" como `<text>` com
`font-family: 'Segoe UI', ...`. Na maquina de quem recebe, sem essa fonte, o navegador troca por
outra: a palavra muda de largura e o ponto verde -- que esta numa coordenada fixa -- cai em cima
da letra. Aqui `svg.fonttype = 'path'` converte tudo em contorno, e uma conferencia **estoura** se
sobrar qualquer `<text>` ou `font-family` no arquivo.

**A largura do quadro e MEDIDA, nao chutada.** A posicao de "Happ" sai da largura real de "Bora",
e o fim do quadro sai do fim real de "Happ". Sem isso sobrava uma faixa vazia a direita, e quem
centraliza num slide ve a marca fora do meio.

## Tres coisas que so apareceram ao OLHAR o resultado

1. **No fundo escuro, "Bora" sumia.** Ele e `#1B1512`, a mesma cor do fundo: saia so "Happ". Por
   isso existe a paleta `landing_escuro`, com "Bora" em papel.
2. **O icone tinha 18% de vazio em volta**, porque herdava a folga do logo. Num avatar redondo
   isso vira uma marca pequena dentro de um espaco grande. Agora o quadrado enche o quadro.
3. **A seta comecava DENTRO da sacola** (x=34 em vez de 35, que e a borda), e o desenho lia como
   flecha atravessando a sacola em vez de saindo dela.

Nenhuma das tres o gerador tinha como reclamar sozinho.
