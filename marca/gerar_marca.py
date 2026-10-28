# -*- coding: utf-8 -*-
"""Gera os arquivos da marca BoraHapp, em alta resolucao e sem depender de fonte.

POR QUE ISTO EXISTE
Pediram o logo para mandar a uma palestra. Ao procurar, achei DUAS identidades vivas no produto:

  1. `assets/img/logo-bora.svg` -- quadrado ROXO (#7c3aed) com sacola branca, seta VERDE
     (#22c55e) e a palavra "Bora". E o favicon de todas as telas e o logo da tela de cadastro.
  2. A landing (a cara publica de hoje) -- marca escrita "Bora" + "Happ", em #1B1512 e
     #D9502B, sobre papel #FBF7F3. Nenhum roxo, nenhum verde.

Elas nao combinam, e a palavra tambem muda: o SVG diz "Bora", o site diz "BoraHapp" 17 vezes.
Este script gera as DUAS, para a escolha ser do dono e nao minha. A geometria da sacola e a mesma
do SVG original nos dois casos -- o simbolo nao foi redesenhado, so recolorido na versao da
landing.

O PROBLEMA DA FONTE, QUE E O QUE QUEBRA LOGO ENVIADO POR E-MAIL
O SVG original escreve a palavra como TEXTO, com `font-family: 'Segoe UI', Inter, ...`. Na maquina
de quem recebe, sem essa fonte, o navegador troca por outra: a palavra muda de largura, e o ponto
verde -- que esta numa coordenada fixa -- cai em cima da letra. Aqui o texto vira CURVA
(`svg.fonttype = 'path'`), entao o arquivo desenha igual em qualquer lugar, inclusive em quem nao
tem Segoe UI nenhuma.
"""
import os

import matplotlib
matplotlib.use('Agg')
# Texto vira contorno no SVG. E a linha mais importante deste arquivo.
matplotlib.rcParams['svg.fonttype'] = 'path'

import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.font_manager import FontProperties  # noqa: E402
from matplotlib.patches import Circle, FancyBboxPatch, PathPatch  # noqa: E402
from matplotlib.path import Path  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))

# A fonte: Segoe UI Black, que e a primeira da pilha do site em Windows. Ela so e usada para
# DESENHAR; nada dela vai junto no arquivo, porque o texto sai como curva.
FONTE = FontProperties(fname='C:/Windows/Fonts/seguibl.ttf')

# ---------------------------------------------------------------- as duas paletas, medidas
PALETA = {
    'landing': {   # a cara publica de hoje (bora-landing/assets/site.css)
        'simbolo': '#D9502B',   # --brasa
        'detalhe': '#FFFFFF',
        'seta':    '#FBF7F3',   # --papel, para a seta ler dentro do brasa
        'texto1':  '#1B1512',   # --tinta  ("Bora")
        'texto2':  '#D9502B',   # --brasa  ("Happ")
        'ponto':   '#176B4F',   # --verde
        'fundo':   '#FBF7F3',   # --papel
    },
    'landing_escuro': {
        # A MESMA marca, para fundo escuro. Existe porque a versao normal escreve "Bora" em
        # --tinta (#1B1512), que sobre o proprio --tinta e invisivel: o logo saia so com "Happ".
        # So descobri olhando o PNG -- o gerador nao tinha como reclamar.
        'simbolo': '#D9502B', 'detalhe': '#FFFFFF', 'seta': '#FBF7F3',
        'texto1': '#FBF7F3',   # --papel no lugar da tinta
        'texto2': '#E8603B',   # brasa um tom acima, que sobre preto le melhor que o #D9502B
        'ponto': '#2E9B74', 'fundo': '#1B1512',
    },
    'roxo': {      # a do SVG que esta no produto hoje (favicon e tela de cadastro)
        'simbolo': '#7c3aed',
        'detalhe': '#FFFFFF',
        'seta':    '#22c55e',
        'texto1':  '#7c3aed',
        'texto2':  '#7c3aed',
        'ponto':   '#22c55e',
        'fundo':   '#FFFFFF',
    },
}


def simbolo(ax, cor, x=0.0, y=0.0, lado=48.0):
    """A sacola com a seta. Mesma geometria do logo-bora.svg, so reposicionada e recolorida."""
    e = lado / 48.0

    def px(vx, vy):
        """Do sistema do SVG (y cresce para baixo, 48x48) para o do desenho."""
        return (x + vx * e, y + (48 - vy) * e)

    ax.add_patch(FancyBboxPatch(
        (x + 1.2 * e, y + 1.2 * e), lado - 2.4 * e, lado - 2.4 * e,
        boxstyle='round,pad=%f,rounding_size=%f' % (1.2 * e, 11 * e),
        linewidth=0, facecolor=cor['simbolo'], mutation_aspect=1))

    # corpo da sacola
    cx, cy = px(9, 40)
    ax.add_patch(FancyBboxPatch(
        (cx + 1.5 * e, cy + 1.5 * e), 26 * e - 3 * e, 20 * e - 3 * e,
        boxstyle='round,pad=%f,rounding_size=%f' % (1.5 * e, 2.4 * e),
        linewidth=2.4 * e, edgecolor=cor['detalhe'], facecolor='none'))

    # alca: as duas curvas quadraticas do SVG, iguais
    ax.add_patch(PathPatch(Path(
        [px(14, 20), px(14, 12), px(22, 12), px(30, 12), px(30, 20)],
        [Path.MOVETO, Path.CURVE3, Path.CURVE3, Path.CURVE3, Path.CURVE3]),
        linewidth=2.4 * e, edgecolor=cor['detalhe'], facecolor='none',
        capstyle='round', joinstyle='round'))

    # seta de velocidade
    # x=35 e a borda direita da sacola (9+26). Comecar em 34 punha a seta DENTRO dela, e o
    # desenho lia como flecha atravessando a sacola em vez de saindo dela.
    ax.add_patch(PathPatch(Path([px(35, 27), px(43.5, 27)], [Path.MOVETO, Path.LINETO]),
                           linewidth=2.6 * e, edgecolor=cor['seta'], capstyle='round'))
    ax.add_patch(PathPatch(Path([px(40, 23), px(44, 27), px(40, 31)],
                                [Path.MOVETO, Path.LINETO, Path.LINETO]),
                           linewidth=2.6 * e, edgecolor=cor['seta'], facecolor='none',
                           capstyle='round', joinstyle='round'))
    # ponto de "em tempo real"
    px_, py_ = px(38, 13)
    ax.add_patch(Circle((px_, py_), 4 * e, facecolor=cor['ponto'], linewidth=0))


def desenhar(qual, com_palavra, fundo, arquivo_base, largura_px=2400):
    """Monta uma figura e salva SVG + PNG. `fundo=None` => PNG com fundo transparente."""
    cor = PALETA[qual]
    lado = 48.0
    # Sem palavra e ICONE: o quadrado E o icone, e tem de encher o quadro. Com 8 de folga de cada
    # lado (o que o quadro do logo usa) sobrava 18% de vazio em volta -- num avatar redondo ou no
    # canto de um slide, isso aparece como uma marca pequena demais dentro de um espaco grande.
    folga = 8.0 if com_palavra else 0.0
    alto = lado + 2 * folga
    largo = 230.0 if com_palavra else lado

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

    simbolo(ax, cor, x=folga, y=(alto - lado) / 2.0, lado=lado)

    if com_palavra:
        # "Bora" e "Happ" sao dois textos para terem cores diferentes. A posicao do segundo sai da
        # largura MEDIDA do primeiro, e nao de um numero chutado: trocar a fonte ou o tamanho nao
        # pode fazer as duas metades se sobreporem.
        base_x, base_y = 68.0, alto / 2.0
        t1 = ax.text(base_x, base_y, 'Bora', fontproperties=FONTE, fontsize=34,
                     color=cor['texto1'], va='center', ha='left')
        fig.canvas.draw()
        largura_bora = (t1.get_window_extent(fig.canvas.get_renderer()).width
                        / fig.dpi * 50.0)
        t2 = ax.text(base_x + largura_bora, base_y, 'Happ', fontproperties=FONTE, fontsize=34,
                     color=cor['texto2'], va='center', ha='left')
        # E a largura MEDIDA do conjunto que define o fim do quadro. O `bbox_inches='tight'` nao
        # resolve isto: o eixo ocupa a figura inteira e o fundo e um retangulo do tamanho dela,
        # entao o corte automatico nao enxerga a sobra. Sem esta linha o logo sai com uma faixa
        # vazia a direita, e quem centralizar num slide vai ver a marca fora do meio.
        fig.canvas.draw()
        fim = (t2.get_window_extent(fig.canvas.get_renderer()).x1 / fig.dpi * 50.0)
        ax.set_xlim(0, fim + 8)
        fig.set_size_inches((fim + 8) / 50.0, alto / 50.0)

    svg = os.path.join(AQUI, arquivo_base + '.svg')
    png = os.path.join(AQUI, arquivo_base + '.png')
    # `bbox_inches='tight'` corta a sobra: a largura do quadro era um chute (230), e o texto
    # termina antes dela. Logo entregue com vazio de um lado desalinha em qualquer slide onde
    # alguem o centralize.
    corte = dict(bbox_inches='tight', pad_inches=0.10 if com_palavra else 0.0)
    fig.savefig(svg, format='svg', transparent=not fundo,
                facecolor=fundo if fundo else 'none', **corte)
    fig.savefig(png, format='png', dpi=largura_px / (largo / 50.0),
                transparent=not fundo, facecolor=fundo if fundo else 'none', **corte)
    plt.close(fig)
    return svg, png


def conferir_svg_sem_fonte(caminho):
    """Prova que o SVG nao depende de fonte nenhuma: nao pode sobrar elemento <text>."""
    with open(caminho, encoding='utf-8') as f:
        s = f.read()
    if '<text' in s or 'font-family' in s:
        raise SystemExit('PAREI: %s ainda tem texto como FONTE, nao como curva. '
                         'Na maquina de quem receber, a palavra muda de largura.' % caminho)
    return len(s)


if __name__ == '__main__':
    feitos = []
    # A identidade da landing -- a cara publica de hoje
    feitos.append(desenhar('landing', True, None, 'borahapp-logo'))
    feitos.append(desenhar('landing', True, '#FBF7F3', 'borahapp-logo-papel'))
    feitos.append(desenhar('landing_escuro', True, '#1B1512', 'borahapp-logo-fundo-escuro'))
    feitos.append(desenhar('landing_escuro', True, None, 'borahapp-logo-para-fundo-escuro-transparente'))
    feitos.append(desenhar('landing', False, None, 'borahapp-icone', largura_px=1200))
    # A identidade roxa que esta no produto hoje (favicon e tela de cadastro)
    feitos.append(desenhar('roxo', True, None, 'bora-logo-roxo'))
    feitos.append(desenhar('roxo', False, None, 'bora-icone-roxo', largura_px=1200))

    for svg, png in feitos:
        n = conferir_svg_sem_fonte(svg)
        print('ok  %-34s svg %4d KB   png %4d KB'
              % (os.path.basename(svg).replace('.svg', ''),
                 n // 1024, os.path.getsize(png) // 1024))
    print('\ntexto conferido: nenhum arquivo depende de fonte instalada.')
