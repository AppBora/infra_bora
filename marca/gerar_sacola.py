# -*- coding: utf-8 -*-
"""A sacola redesenhada: a marca que o dono escolheu, com os quatro defeitos consertados.

O QUE ESTAVA ERRADO NA ANTERIOR, E O QUE MUDOU AQUI

1. LIA COMO CADEADO. Retangulo com UM arco centrado em cima e a forma universal de fechadura.
   Agora o corpo e TRAPEZIO -- mais largo em cima, que e o formato de sacola de papel -- e as
   alcas sao DUAS, recortadas no proprio corpo. Duas alcas e sacola; uma alca centrada e cadeado.

2. MORRIA EM 16 px. Esse era o defeito de verdade, e nao era a silhueta: o desenho era de LINHA.
   Traco de 2,4 num simbolo de 48 vira 0,8 px num icone de 16 -- some. Agora a sacola e uma forma
   SOLIDA. Forma cheia aguenta tamanho pequeno; contorno fino nao aguenta, nunca.

3. O PONTO VERDE saiu. Bolinha colorida no canto superior direito e, no iOS e no Android, o selo
   de notificacao nao lida. A marca estava pedindo emprestada uma convencao que ja significa
   outra coisa.

4. "EU SOU O DELIVERY". Este e o unico que nao da para consertar inteiro mantendo a sacola, e
   fica dito: sacola e sinal de categoria, e quem e o delivery e o lojista. O que da para fazer, e
   esta feito, e reduzir o peso -- sem seta, sem ponto, sem cor extra, a sacola mais abstrata
   possivel ainda sendo sacola. O que carrega a marca e a palavra.

O MOVIMENTO, SEM SETA
A sacola e levemente INCLINADA para a frente. A seta anterior era um elemento a mais que morria
no tamanho pequeno; a inclinacao e a MESMA forma solida, entao nao custa nada em legibilidade e
diz carregada, em movimento. "Bora" ja e pressa; o simbolo nao precisa repetir.
"""
import io
import os
import sys

import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['svg.fonttype'] = 'path'

import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import PathPatch  # noqa: E402
from matplotlib.path import Path  # noqa: E402
from matplotlib.transforms import Affine2D  # noqa: E402
from PIL import Image  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from gerar_marca_v2 import COR, FONTE, figura, quadrado  # noqa: E402

L = 48.0
RAIO = L * 0.235
INCLINACAO = 4.0          # graus. Em 7 a sacola parecia caindo, nao sendo carregada.


def _arred(pontos, r):
    """Poligono com os cantos arredondados em `r`. Sacola de canto seco parece caixa."""
    n = len(pontos)
    v, c = [], []
    for i in range(n):
        p0, p1, p2 = pontos[(i - 1) % n], pontos[i], pontos[(i + 1) % n]
        def anda(de, para, d):
            dx, dy = para[0] - de[0], para[1] - de[1]
            m = (dx * dx + dy * dy) ** 0.5
            d = min(d, m / 2.0)
            return (de[0] + dx / m * d, de[1] + dy / m * d)
        a = anda(p1, p0, r)
        b = anda(p1, p2, r)
        if i == 0:
            v.append(a); c.append(Path.MOVETO)
        else:
            v.append(a); c.append(Path.LINETO)
        v.append(p1); c.append(Path.CURVE3)
        v.append(b); c.append(Path.CURVE3)
    v.append(v[0]); c.append(Path.CLOSEPOLY)
    return Path(v, c)


def sacola():
    """Corpo trapezio + DUAS alcas por cima. Devolve (corpo, alcas_como_caminhos).

    Por que as alcas voltaram para CIMA do corpo: eu tinha recortado as duas como furos no
    proprio corpo, e o resultado nao lia sacola -- lia lixeira, e os dois rasgos viravam OLHOS.
    A alca acima da linha do corpo e a assinatura da forma; sem ela, sobra um balde.

    Por que o corpo e trapezio mais largo EM CIMA: e o que separa sacola de papel de caixa. E e o
    que mata a leitura de cadeado, que era o defeito numero 1 da versao anterior.
    """
    # A sacola ocupa ~55% do quadrado. Em 70% ela encostava nas bordas e o simbolo ficava sem ar
    # -- e icone sem respiro parece erro de recorte quando entra num slide.
    topo_e, topo_d = 13.0, 35.0
    base_e, base_d = 15.5, 32.5
    y_base, y_topo = 13.0, 30.0
    corpo = _arred([(base_e, y_base), (base_d, y_base), (topo_d, y_topo), (topo_e, y_topo)], 2.0)

    # as alcas: dois arcos grossos saindo do topo do corpo. Grossos de proposito -- traco fino e
    # exatamente o que fez a marca anterior sumir em 16 px.
    # Juntas e estreitas: afastadas, as duas alcas liam como ORELHAS em vez de alca de sacola.
    # O VAO da alca e o que o olho le como alca. Com arco grosso e estreito ele quase fechava,
    # e as duas viravam dois tocos. Arco mais largo e traco mais fino abrem o vao.
    alcas = []
    for cx in (20.2, 28.0):
        r = 3.0
        alcas.append(Path(
            [(cx - r, y_topo - 0.5), (cx - r, y_topo + 5.4), (cx + r, y_topo + 5.4),
             (cx + r, y_topo - 0.5)],
            [Path.MOVETO, Path.CURVE4, Path.CURVE4, Path.CURVE4]))

    t = (Affine2D().translate(-L / 2.0, -L / 2.0)
         .rotate_deg(-INCLINACAO).translate(L / 2.0, L / 2.0 - 1.5))
    return t.transform_path(corpo), [t.transform_path(a) for a in alcas]


def simbolo_png_svg(base, cor_quadrado, cor_sacola, fundo=None, lado_px=1200):
    """Quadrado + sacola. UMA cor para o quadrado, UMA para a sacola: nada mais.

    Nao ha mais furo aqui, entao nao ha mais o truque do evenodd/alfa: a alca e forma por cima,
    e a sacola inteira e uma so cor. Marca de duas cores chapadas e o que aguenta carimbo.
    """
    corpo, alcas = sacola()
    q = quadrado(0, 0, L, RAIO)
    # 1 unidade do desenho = 1.44 pontos nesta figura; a alca tem 2.6 unidades de grossura.
    grossura = 1.9 * 1.44

    fig, ax = figura(L, L, fundo=fundo)
    ax.add_patch(PathPatch(q, facecolor=cor_quadrado, edgecolor='none'))
    for a in alcas:
        ax.add_patch(PathPatch(a, facecolor='none', edgecolor=cor_sacola,
                               linewidth=grossura, capstyle='round', joinstyle='round'))
    ax.add_patch(PathPatch(corpo, facecolor=cor_sacola, edgecolor='none'))

    svg = os.path.join(AQUI, base + '.svg')
    png = os.path.join(AQUI, base + '.png')
    fig.savefig(svg, format='svg', transparent=not fundo, facecolor=fundo if fundo else 'none')
    fig.savefig(png, format='png', dpi=lado_px / (L / 50.0),
                transparent=not fundo, facecolor=fundo if fundo else 'none')
    plt.close(fig)
    return svg, png


def logotipo(base, cor_quadrado, cor_sacola, cor_bora, cor_happ, fundo=None, px=2400):
    mono = os.path.join(AQUI, '_tmp_s.png')
    simbolo_png_svg('_tmp_s', cor_quadrado, cor_sacola, fundo=None, lado_px=900)
    margem, vao = L * 0.14, L * 0.26
    alto = L * 1.34 + 2 * margem
    fig, ax = figura(L * 4.6, alto, fundo=fundo)
    ax.imshow(plt.imread(mono), extent=(margem, margem + L, (alto - L) / 2.0, (alto + L) / 2.0),
              zorder=2)
    base_x, base_y = margem + L + vao, alto / 2.0
    t1 = ax.text(base_x, base_y, 'Bora', fontproperties=FONTE, fontsize=32,
                 color=cor_bora, va='center', ha='left', zorder=3)
    fig.canvas.draw()
    w1 = t1.get_window_extent(fig.canvas.get_renderer()).width / fig.dpi * 50.0
    t2 = ax.text(base_x + w1, base_y, 'Happ', fontproperties=FONTE, fontsize=32,
                 color=cor_happ, va='center', ha='left', zorder=3)
    fig.canvas.draw()
    fim = t2.get_window_extent(fig.canvas.get_renderer()).x1 / fig.dpi * 50.0
    ax.set_xlim(0, fim + margem)
    fig.set_size_inches((fim + margem) / 50.0, alto / 50.0)
    larg = fig.get_size_inches()[0] * 50.0
    fig.savefig(os.path.join(AQUI, base + '.svg'), format='svg',
                transparent=not fundo, facecolor=fundo if fundo else 'none')
    fig.savefig(os.path.join(AQUI, base + '.png'), format='png', dpi=px / (larg / 50.0),
                transparent=not fundo, facecolor=fundo if fundo else 'none')
    plt.close(fig)
    os.remove(mono)
    os.remove(os.path.join(AQUI, '_tmp_s.svg'))


def simbolo_pequeno(base, cor_quadrado, cor_sacola, lado_px=256):
    """O corte para 16 px: so o corpo, maior, sem alca.

    Em 16 px a alca funde com o corpo de qualquer jeito -- isso vale para QUALQUER desenho de
    sacola, nao e defeito deste. O que se faz e um corte proprio: tira a alca, engorda o corpo e
    deixa a forma que sobra ser nitida de proposito, em vez de ser o resto de uma forma maior.
    """
    corpo, _ = sacola()
    e = 1.22
    corpo = (Affine2D().translate(-L / 2.0, -L / 2.0).scale(e)
             .translate(L / 2.0, L / 2.0).transform_path(corpo))
    fig, ax = figura(L, L)
    ax.add_patch(PathPatch(quadrado(0, 0, L, RAIO), facecolor=cor_quadrado, edgecolor='none'))
    ax.add_patch(PathPatch(corpo, facecolor=cor_sacola, edgecolor='none'))
    fig.savefig(os.path.join(AQUI, base + '.svg'), format='svg', transparent=True)
    fig.savefig(os.path.join(AQUI, base + '.png'), format='png',
                dpi=lado_px / (L / 50.0), transparent=True)
    plt.close(fig)


if __name__ == '__main__':
    simbolo_png_svg('borahapp-simbolo', COR['brasa'], COR['papel'])
    simbolo_png_svg('borahapp-simbolo-tinta', COR['tinta'], COR['papel'])
    simbolo_png_svg('borahapp-simbolo-papel', COR['papel'], COR['brasa'])
    simbolo_pequeno('borahapp-simbolo-16px', COR['brasa'], COR['papel'])
    logotipo('borahapp-horizontal', COR['brasa'], COR['papel'], COR['tinta'], COR['brasa'])
    logotipo('borahapp-horizontal-papel', COR['brasa'], COR['papel'], COR['tinta'], COR['brasa'],
             fundo=COR['papel'])
    logotipo('borahapp-horizontal-escuro', COR['brasa'], COR['papel'], COR['papel'],
             COR['brasa_clara'], fundo=COR['tinta'])
    for n in ('borahapp-simbolo', 'borahapp-horizontal', 'borahapp-horizontal-papel',
              'borahapp-horizontal-escuro'):
        im = Image.open(os.path.join(AQUI, n + '.png'))
        print('ok  %-30s %dx%d' % (n, im.width, im.height))
