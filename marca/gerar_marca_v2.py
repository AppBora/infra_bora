# -*- coding: utf-8 -*-
"""A identidade do BoraHapp: monograma, logotipo e as variacoes do sistema.

O BRIEFING, TIRADO DO QUE O PRODUTO AFIRMA
A landing diz "um painel que tem a cara da sua loja. NAO a nossa" e "sem taxa por pedido". Isso
decide o simbolo:

  1. O BoraHapp nao e marca de comida -- e a infraestrutura embaixo da marca de comida do cliente.
     Sacola, talher e moto dizem "eu sou o delivery", e quem e o delivery e o lojista. Por isso a
     sacola saiu.
  2. "Bora" ja e movimento: imperativo falado. A seta era redundancia -- e morria abaixo de 32 px.
  3. O que sobra para o simbolo dizer e PRESENCA, nao categoria. Marca que vai conviver ao lado da
     marca do lojista tem de ser firme e quieta.

Daí o monograma, na MESMA tipografia do logotipo: coerencia de sistema, e e a forma que aguenta
16 px -- que e o tamanho real de favicon e atalho de celular.

O QUE AQUI E DECISAO, E NAO GOSTO
- contraforma: o "B" e vazado no quadrado, nao desenhado por cima. Vazado, a marca funciona em
  uma cor so -- carimbo, bordado, gravacao, fax do contador. Logo que so existe em duas cores
  quebra no primeiro uso fora da tela.
- canto: tres cantos arredondados e um reto, embaixo a esquerda. E o detalhe que tira o quadrado
  do lugar-comum do "app genérico" e da direcao a forma, e sobrevive ao tamanho pequeno porque e
  geometria de canto, nao traco fino.
- cor: um tom so no simbolo. Tres cores num quadrado de 16 px viram papa.
"""
import io
import os

import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['svg.fonttype'] = 'path'

import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.font_manager import FontProperties  # noqa: E402
from matplotlib.patches import PathPatch  # noqa: E402
from matplotlib.path import Path  # noqa: E402
from matplotlib.textpath import TextPath  # noqa: E402
from matplotlib.transforms import Affine2D  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
FONTE = FontProperties(fname='C:/Windows/Fonts/seguibl.ttf')

# A cor da marca e ROXA desde 29/10/2026, por escolha do dono: o laranja-brasa ficou pesado para
# ele. A escolha tem uma economia junto -- o painel JA e roxo (`#7c3aed` no styles.css e em uns
# dez arquivos de JS), entao a marca passa a combinar com o produto sem repintar a interface.
#
# As chaves `brasa`/`brasa_clara` guardam o NOME antigo de proposito: elas sao lidas por
# `gerar_sacola.py` e renomear as duas sem necessidade so criaria chance de erro. O que importa e
# o valor.
COR = {
    'papel':  '#FBF7F3',
    'tinta':  '#1B1512',
    'brasa':  '#9333EA',        # a cor da marca (opcao D)
    'brasa_clara': '#A855F7',   # sobre o escuro: o #9333EA da 3,36:1, que passa raspando;
                                # este da 4,57:1. Medido, nao estimado.
    'verde':  '#176B4F',
}


def quadrado(x, y, lado, raio, canto_reto=None):
    """Quadrado de cantos arredondados, com UM canto opcionalmente reto.

    O `FancyBboxPatch` arredonda os quatro igual; aqui o caminho e montado a mao porque o canto
    reto e parte da marca, nao enfeite.
    """
    r = raio
    # cantos: 0=inferior esquerdo, 1=inferior direito, 2=superior direito, 3=superior esquerdo
    rr = [0 if canto_reto == i else r for i in range(4)]
    x0, y0, x1, y1 = x, y, x + lado, y + lado
    k = 0.5523  # aproximacao de arco de circulo por Bezier cubica

    v, c = [], []

    def canto(px, py, raio_c, de, para):
        """Arco do canto, ou vertice seco quando raio_c == 0."""
        if raio_c == 0:
            v.append((px, py)); c.append(Path.LINETO)
            return
        ax_, ay_ = px - de[0] * raio_c, py - de[1] * raio_c
        bx_, by_ = px + para[0] * raio_c, py + para[1] * raio_c
        v.append((ax_, ay_)); c.append(Path.LINETO)
        v.append((ax_ + de[0] * raio_c * k, ay_ + de[1] * raio_c * k)); c.append(Path.CURVE4)
        v.append((bx_ - para[0] * raio_c * k, by_ - para[1] * raio_c * k)); c.append(Path.CURVE4)
        v.append((bx_, by_)); c.append(Path.CURVE4)

    v.append((x0 + rr[0], y0)); c.append(Path.MOVETO)
    canto(x1, y0, rr[1], (1, 0), (0, 1))     # inferior direito
    canto(x1, y1, rr[2], (0, 1), (-1, 0))    # superior direito
    canto(x0, y1, rr[3], (-1, 0), (0, -1))   # superior esquerdo
    canto(x0, y0, rr[0], (0, -1), (1, 0))    # inferior esquerdo
    v.append((x0 + rr[0], y0)); c.append(Path.CLOSEPOLY)
    return Path(v, c)


def letra(ch, altura, centro):
    """O contorno da letra, na fonte do logotipo, centrado OPTICAMENTE pela caixa real.

    Centrar pela ancora do texto deixa o "B" torto: a caixa da fonte tem folga que nao e igual em
    cima e embaixo. Aqui o centro sai da extensao desenhada.
    """
    p = TextPath((0, 0), ch, size=100, prop=FONTE)
    ext = p.get_extents()
    escala = altura / ext.height
    t = (Affine2D().translate(-ext.x0 - ext.width / 2.0, -ext.y0 - ext.height / 2.0)
         .scale(escala).translate(*centro))
    return t.transform_path(p)


def reverter(p):
    """Inverte o SENTIDO de cada contorno de um caminho, preservando as curvas.

    Por que isto precisa existir: o furo da letra so vira furo de verdade se o contorno dela
    girar ao contrario do quadrado (regra nonzero). Inverter `vertices[::-1]` sem mexer nos
    `codes` produz lixo -- o "B" tem TRES contornos (o de fora e as duas barrigas), cada um com o
    seu MOVETO, e os pontos de controle das curvas deixam de casar com o codigo. Foi exatamente
    isso que fez o primeiro teste sair como quadrado macico, sem letra nenhuma.
    """
    subs, atual = [], None
    for v, c in zip(p.vertices, p.codes if p.codes is not None else []):
        if c == Path.MOVETO:
            if atual:
                subs.append(atual)
            atual = [(c, tuple(v))]
        else:
            atual.append((c, tuple(v)))
    if atual:
        subs.append(atual)

    vs, cs = [], []
    for sub in subs:
        sub = [(c, v) for c, v in sub if c != Path.CLOSEPOLY]
        if len(sub) < 2:
            continue
        # quebra em segmentos: cada um e (codigo, pontos de controle..., ponto final)
        segs, i = [], 1
        pontos = [v for _, v in sub]
        while i < len(sub):
            cod = sub[i][0]
            n = {Path.LINETO: 1, Path.CURVE3: 2, Path.CURVE4: 3}[cod]
            segs.append((cod, pontos[i:i + n]))
            i += n
        vs.append(sub[-1][1]); cs.append(Path.MOVETO)
        inicio = [sub[0][1]] + [s[1][-1] for s in segs][:-1]
        for (cod, pts), ini in zip(reversed(segs), reversed(inicio)):
            meio = list(reversed(pts[:-1]))
            for m in meio:
                vs.append(m); cs.append(cod)
            vs.append(ini); cs.append(cod)
        vs.append(sub[-1][1]); cs.append(Path.CLOSEPOLY)
    return Path(vs, cs)


def simbolo(ax, x, y, lado, fundo, letra_cor, canto_reto=0, vazado=True):
    """O monograma. Vazado = a letra e um FURO no quadrado, nao uma forma por cima."""
    q = quadrado(x, y, lado, lado * 0.235, canto_reto=canto_reto)
    b = letra('B', lado * 0.52, (x + lado / 2.0, y + lado / 2.0))
    if vazado:
        # Um caminho so, quadrado + letra, marcado com `fill-rule: evenodd` na hora de salvar o
        # SVG: ai o contorno de dentro vira FURO. Tentei antes inverter o sentido do contorno da
        # letra para valer na regra `nonzero` do matplotlib e NAO funcionou -- saiu quadrado
        # macico, sem letra. Ver `vazar_png`, que faz o mesmo furo no PNG pelo alfa.
        vs = list(q.vertices) + list(b.vertices)
        cs = list(q.codes) + list(b.codes)
        ax.add_patch(PathPatch(Path(vs, cs), facecolor=fundo, edgecolor='none',
                               gid='monograma-vazado'))
    else:
        ax.add_patch(PathPatch(q, facecolor=fundo, edgecolor='none'))
        ax.add_patch(PathPatch(b, facecolor=letra_cor, edgecolor='none'))


def vazar_png(caminho_cheio, caminho_letra, saida):
    """Fura o alfa do PNG usando a letra como molde. Furo de verdade, conferivel."""
    from PIL import Image
    cheio = Image.open(caminho_cheio).convert('RGBA')
    molde = Image.open(caminho_letra).convert('RGBA').resize(cheio.size, Image.LANCZOS)
    c, m = cheio.load(), molde.load()
    for yy in range(cheio.height):
        for xx in range(cheio.width):
            a = m[xx, yy][3]
            if a:
                r, g, bb, ca = c[xx, yy]
                c[xx, yy] = (r, g, bb, max(0, ca - a))
    cheio.save(saida)
    return saida


def evenodd_no_svg(caminho):
    """Marca o caminho do monograma com `evenodd`, que e o que transforma a letra em furo."""
    s = io.open(caminho, encoding='utf-8').read()
    if 'monograma-vazado' not in s:
        raise SystemExit('PAREI: nao achei o caminho do monograma em %s' % caminho)
    s = s.replace('id="monograma-vazado"', 'id="monograma-vazado" fill-rule="evenodd"')
    io.open(caminho, 'w', encoding='utf-8', newline=chr(10)).write(s)


def figura(largo, alto, fundo=None):
    fig = plt.figure(figsize=(largo / 50.0, alto / 50.0), dpi=100)
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, largo)
    ax.set_ylim(0, alto)
    ax.set_aspect('equal')
    ax.axis('off')
    if fundo:
        fig.patch.set_facecolor(fundo)
        ax.set_facecolor(fundo)
    else:
        fig.patch.set_alpha(0.0)
        ax.patch.set_alpha(0.0)
    return fig, ax


def salvar(fig, base, fundo, px=2400, largo=None):
    svg = os.path.join(AQUI, base + '.svg')
    png = os.path.join(AQUI, base + '.png')
    corte = dict(bbox_inches='tight', pad_inches=0.0)
    for caminho, fmt, extra in ((svg, 'svg', {}), (png, 'png', {'dpi': px / (largo / 50.0)})):
        fig.savefig(caminho, format=fmt, transparent=not fundo,
                    facecolor=fundo if fundo else 'none', **dict(corte, **extra))
    with open(svg, encoding='utf-8') as f:
        s = f.read()
    if '<text' in s or 'font-family' in s:
        raise SystemExit('PAREI: %s depende de fonte instalada.' % svg)
    plt.close(fig)
