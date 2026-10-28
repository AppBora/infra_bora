# marca/

As regras estao no **[MANUAL-DA-MARCA.md](MANUAL-DA-MARCA.md)**.

Tudo e **gerado**: `python gerar_sacola.py`. Nao edite PNG nem SVG a mao.

| arquivo | o que e |
|---|---|
| `borahapp-horizontal*` | o logo padrao: transparente, sobre papel, sobre escuro |
| `borahapp-simbolo*` | so a sacola no quadrado: brasa, tinta (uma cor), papel |
| `borahapp-simbolo-16px` | o corte para favicon e atalho -- **so o corpo, sem alca** |
| `gerar_sacola.py` | producao: o desenho da sacola e dos arquivos |
| `gerar_marca_v2.py` | o quadrado, a letra e as cores. O briefing esta no topo dele |
| `prova-16px.png` | a sacola nova contra a anterior, nos tamanhos reais |
| `comparacao-grafias.png` | BoraHapp x BorahApp, a comparacao que decidiu o nome |
| `bora-*-roxo.*` | **referencia**: a identidade roxa que ainda esta no produto |

## UMA geracao por vez

Esta pasta ja teve tres desenhos ao mesmo tempo -- a sacola de linha, o monograma e a sacola nova
-- e o dono abriu o arquivo errado por causa disso, porque os nomes eram parecidos. **O que nao e
a marca vigente sai da pasta.** O historico do git guarda.

Saiu em 28/10/2026:
- a **sacola de linha** (`borahapp-logo*`, `borahapp-icone*`, `gerar_marca.py`) -- morria em
  16 px e lia como cadeado;
- o **monograma "B"** (`gerar_identidade.py`, `borahapp-vertical*`) -- proposta minha, **recusada
  pelo dono**, que preferiu manter a sacola consertada.

## Ainda nao existe

**Versao vertical** (simbolo em cima, palavra embaixo), para espaco estreito e alto -- cracha,
adesivo. O manual cita area de respiro e tamanho minimo dela; quando for feita, sai do mesmo
`gerar_sacola.py`.
