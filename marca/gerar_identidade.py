# -*- coding: utf-8 -*-
"""A identidade do BoraHapp: monograma vazado, logotipo e as variacoes do sistema.

Ver `gerar_marca_v2.py` para o briefing e o porque do monograma. Aqui e a producao dos arquivos.

O FURO, QUE E O PONTO DA MARCA
O "B" e um FURO no quadrado, nao uma letra pintada por cima. Isso e o que faz a marca funcionar
em uma cor so -- carimbo, bordado, gravacao, serigrafia, papel timbrado em preto. Logo que so
existe em duas cores quebra no primeiro uso fora da tela.

Fazer o furo deu trabalho, e vale registrar para ninguem refazer o caminho errado:
  - o matplotlib preenche pela regra NONZERO, entao juntar quadrado + letra num caminho so
    nao fura nada: sai quadrado macico;
  - inverter o sentido do contorno da letra deveria resolver, e eu escrevi essa inversao. NAO
    funcionou -- o "B" tem tres contornos e as curvas nao casaram. Saiu macico de novo.
  - o que funciona, e esta aqui: no SVG, marcar o caminho com `fill-rule="evenodd"`; no PNG,
    furar o alfa usando a propria letra como molde. Os dois sao conferidos no fim do arquivo.
"""
import io
import os

import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['svg.fonttype'] = 'path'

import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import PathPatch  # noqa: E402
from matplotlib.path import Path  # noqa: E402
from PIL import Image  # noqa: E402

import sys  # noqa: E402
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gerar_marca_v2 import COR, FONTE, figura, letra, quadrado  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
L = 48.0
RAIO = L * 0.235
ALTURA_B = L * 0.52
CANTO_RETO = 0          # inferior esquerdo


def _tela(lado_px, fundo=None):
    fig, ax = figura(L, L, fundo=fundo)
    return fig, ax


def monograma(base, cor_quadrado, fundo=None, lado_px=1200):
    """Quadrado + B vazado. Gera SVG (evenodd) e PNG (alfa furado)."""
    # 1. o caminho composto, para o SVG
    fig, ax = _tela(lado_px, fundo)
    q = quadrado(0, 0, L, RAIO, canto_reto=CANTO_RETO)
    b = letra('B', ALTURA_B, (L / 2.0, L / 2.0))
    ax.add_patch(PathPatch(Path(list(q.vertices) + list(b.vertices),
                                list(q.codes) + list(b.codes)),
                           facecolor=cor_quadrado, edgecolor='none', gid='mono'))
    svg = os.path.join(AQUI, base + '.svg')
    fig.savefig(svg, format='svg', transparent=not fundo,
                facecolor=fundo if fundo else 'none')
    plt.close(fig)
    s = io.open(svg, encoding='utf-8').read()
    if 'id="mono"' not in s:
        raise SystemExit('PAREI: o caminho do monograma nao recebeu id em %s' % svg)
    s = s.replace('id="mono"', 'id="mono" fill-rule="evenodd"')
    io.open(svg, 'w', encoding='utf-8', newline=chr(10)).write(s)

    # 2. o PNG: quadrado cheio e letra como molde, na MESMA caixa (sem corte justo, senao as
    #    duas imagens saem com tamanhos diferentes e o molde nao encaixa)
    fig, ax = _tela(lado_px, fundo)
    ax.add_patch(PathPatch(q, facecolor=cor_quadrado, edgecolor='none'))
    cheio = os.path.join(AQUI, '_tmp_cheio.png')
    fig.savefig(cheio, format='png', dpi=lado_px / (L / 50.0),
                transparent=not fundo, facecolor=fundo if fundo else 'none')
    plt.close(fig)

    fig, ax = _tela(lado_px)
    ax.add_patch(PathPatch(b, facecolor='#000000', edgecolor='none'))
    molde = os.path.join(AQUI, '_tmp_molde.png')
    fig.savefig(molde, format='png', dpi=lado_px / (L / 50.0), transparent=True)
    plt.close(fig)

    png = os.path.join(AQUI, base + '.png')
    im = Image.open(cheio).convert('RGBA')
    mo = Image.open(molde).convert('RGBA').resize(im.size, Image.LANCZOS)
    pc, pm = im.load(), mo.load()
    for yy in range(im.height):
        for xx in range(im.width):
            a = pm[xx, yy][3]
            if a:
                r, g, bb, ca = pc[xx, yy]
                pc[xx, yy] = (r, g, bb, max(0, ca - a)) if not fundo else (
                    _mistura((r, g, bb), fundo, a))
    im.save(png)
    os.remove(cheio)
    os.remove(molde)
    return svg, png


def _mistura(rgb, hexa, alfa):
    """Sobre fundo cheio nao da para furar o alfa: o furo recebe a COR do fundo."""
    f = hexa.lstrip('#')
    fr, fg, fb = int(f[0:2], 16), int(f[2:4], 16), int(f[4:6], 16)
    t = alfa / 255.0
    return (int(rgb[0] * (1 - t) + fr * t), int(rgb[1] * (1 - t) + fg * t),
            int(rgb[2] * (1 - t) + fb * t), 255)


def logotipo(base, cor_quadrado, cor_bora, cor_happ, fundo=None, px=2400, vertical=False):
    """Simbolo + palavra. O simbolo entra como imagem ja vazada, para nao repetir a logica."""
    mono = os.path.join(AQUI, '_tmp_mono.png')
    monograma('_tmp_mono', cor_quadrado, fundo=None, lado_px=900)

    # MARGEM: sem ela o quadrado encosta na borda do arquivo e o canto arredondado sai cortado
    # -- e quem for usar o PNG num slide nao tem como saber se aquilo e o desenho ou o corte.
    # VAO: a distancia entre simbolo e palavra e 26% do lado do simbolo. Estava em 34% e lia
    # solto, porque o simbolo e um bloco cheio e nao um desenho de linha.
    margem = L * 0.14
    vao = L * 0.26
    folga = L * 0.30
    if vertical:
        largo, alto = L * 3.4, L + folga + L * 0.80
    else:
        largo, alto = L * 4.6, L * 1.34 + 2 * margem

    fig, ax = figura(largo, alto, fundo=fundo)
    img = plt.imread(mono)
    if vertical:
        sx = (largo - L) / 2.0
        ax.imshow(img, extent=(sx, sx + L, alto - L, alto), zorder=2)
        base_y = (alto - L) / 2.0 - L * 0.10
        base_x = largo / 2.0
        ha = 'center'
    else:
        ax.imshow(img, extent=(margem, margem + L, (alto - L) / 2.0, (alto + L) / 2.0), zorder=2)
        base_x, base_y, ha = margem + L + vao, alto / 2.0, 'left'

    tam = 30 if vertical else 32
    if ha == 'center':
        # centralizar duas cores exige medir: desenha fora da tela, mede, reposiciona
        t = ax.text(0, -999, 'BoraHapp', fontproperties=FONTE, fontsize=tam)
        fig.canvas.draw()
        largura = t.get_window_extent(fig.canvas.get_renderer()).width / fig.dpi * 50.0
        t.remove()
        base_x = largo / 2.0 - largura / 2.0
        ha = 'left'

    t1 = ax.text(base_x, base_y, 'Bora', fontproperties=FONTE, fontsize=tam,
                 color=cor_bora, va='center', ha=ha, zorder=3)
    fig.canvas.draw()
    w1 = t1.get_window_extent(fig.canvas.get_renderer()).width / fig.dpi * 50.0
    t2 = ax.text(base_x + w1, base_y, 'Happ', fontproperties=FONTE, fontsize=tam,
                 color=cor_happ, va='center', ha='left', zorder=3)
    fig.canvas.draw()
    fim = t2.get_window_extent(fig.canvas.get_renderer()).x1 / fig.dpi * 50.0
    if not vertical:
        ax.set_xlim(0, fim + margem)
        fig.set_size_inches((fim + margem) / 50.0, alto / 50.0)

    svg = os.path.join(AQUI, base + '.svg')
    png = os.path.join(AQUI, base + '.png')
    larg_fig = fig.get_size_inches()[0] * 50.0
    fig.savefig(svg, format='svg', transparent=not fundo, facecolor=fundo if fundo else 'none')
    fig.savefig(png, format='png', dpi=px / (larg_fig / 50.0),
                transparent=not fundo, facecolor=fundo if fundo else 'none')
    plt.close(fig)
    os.remove(mono)
    os.remove(os.path.join(AQUI, '_tmp_mono.svg'))
    return svg, png


def conferir(base, deve_ter_furo):
    """Prova o furo: conta pixels transparentes DENTRO da area do quadrado."""
    im = Image.open(os.path.join(AQUI, base + '.png')).convert('RGBA')
    px = im.load()
    w, h = im.size
    vazios = sum(1 for y in range(h // 4, 3 * h // 4) for x in range(w // 4, 3 * w // 4)
                 if px[x, y][3] < 40)
    area = (h // 2) * (w // 2)
    pct = 100.0 * vazios / area
    if deve_ter_furo and pct < 3:
        raise SystemExit('PAREI: %s nao tem furo (%.1f%% vazio no miolo). '
                         'A letra virou pintura por cima, nao recorte.' % (base, pct))
    return pct


if __name__ == '__main__':
    saidas = []
    saidas.append(('borahapp-simbolo', monograma('borahapp-simbolo', COR['brasa'])))
    saidas.append(('borahapp-simbolo-tinta', monograma('borahapp-simbolo-tinta', COR['tinta'])))
    saidas.append(('borahapp-simbolo-papel', monograma('borahapp-simbolo-papel', COR['papel'])))
    logotipo('borahapp-horizontal', COR['brasa'], COR['tinta'], COR['brasa'])
    logotipo('borahapp-horizontal-papel', COR['brasa'], COR['tinta'], COR['brasa'],
             fundo=COR['papel'])
    logotipo('borahapp-horizontal-escuro', COR['brasa'], COR['papel'], COR['brasa_clara'],
             fundo=COR['tinta'])
    logotipo('borahapp-vertical', COR['brasa'], COR['tinta'], COR['brasa'], vertical=True)

    for nome, _ in saidas:
        print('ok  %-28s furo no miolo: %.1f%%' % (nome, conferir(nome, True)))
    for nome in ('borahapp-horizontal', 'borahapp-horizontal-papel',
                 'borahapp-horizontal-escuro', 'borahapp-vertical'):
        im = Image.open(os.path.join(AQUI, nome + '.png'))
        print('ok  %-28s %dx%d' % (nome, im.width, im.height))
