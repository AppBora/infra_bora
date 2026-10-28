# -*- coding: utf-8 -*-
"""Gera ROTEIRO-DE-TESTE.pdf: o mesmo roteiro, desenhado para PAPEL.

POR QUE EXISTE
O HTML e um aplicativo: tem botao de passou/falhou, campo de observacao e exportacao. No papel
nada disso funciona -- o que serve e uma linha por teste, com um quadrado para marcar e espaco
para escrever a mao. Mesma fonte de dados (os conteudo_*.py), layout diferente.

A ARMADILHA DAS FONTES
As fontes embutidas do PDF (Helvetica, Courier) so tem Latin-1. Um caractere fora disso -- as
setas, o travessao, os emoji dos botoes -- sai como QUADRADO PRETO, e sai calado: o PDF gera sem
erro nenhum. Por isso existe o TRADUCAO abaixo e, no fim, uma conferencia que ESTOURA se sobrou
qualquer caractere que a fonte nao desenha. Preferivel falhar aqui do que o dono descobrir com a
folha ja impressa na mao.
"""
import io
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from conteudo_a import PARTE_A  # noqa: E402
from conteudo_b import PARTE_B  # noqa: E402
from conteudo_c import PARTE_C  # noqa: E402

from reportlab.lib import colors  # noqa: E402
from reportlab.lib.enums import TA_LEFT  # noqa: E402
from reportlab.lib.pagesizes import A4  # noqa: E402
from reportlab.lib.styles import ParagraphStyle  # noqa: E402
from reportlab.lib.units import mm  # noqa: E402
from reportlab.platypus import (BaseDocTemplate, Frame, KeepTogether,  # noqa: E402
                                PageTemplate, Paragraph, Spacer)

SECOES = PARTE_A + PARTE_B + PARTE_C
VERSAO = 'v154'
DATA = '28/10/2026'
SAIDA = os.path.join(AQUI, '..', 'ROTEIRO-DE-TESTE.pdf')

MARCA = colors.HexColor('#5b21b6')
CINZA = colors.HexColor('#6b6376')
LINHA = colors.HexColor('#d9d4df')

# Fora do Latin-1 => quadrado preto. Tudo o que o roteiro usa, traduzido para o que a fonte tem.
TRADUCAO = {
    u'—': u'-',      # travessao
    u'–': u'-',      # meia risca
    u'→': u'->',     # seta para a direita
    u'↑': u'[sobe]',
    u'↓': u'[desce]',
    u'…': u'...',
    u'−': u'-',      # sinal de menos
    u'\U0001F513': u'',   # cadeado aberto (so enfeite de botao)
    u'\U0001F4B0': u'',   # saco de dinheiro (idem)
}


def papel(txt):
    """O texto do roteiro, pronto para a fonte do PDF."""
    if txt is None:
        return u''
    t = unicode_str(txt)
    for de, para in TRADUCAO.items():
        t = t.replace(de, para)
    # As unicas marcacoes do conteudo sao <b> e <code>. O Paragraph entende <b>; <code> nao existe
    # para ele, entao vira Courier -- que e o que <code> queria dizer.
    t = t.replace(u'<code>', u'\x01').replace(u'</code>', u'\x02')
    t = t.replace(u'<b>', u'\x03').replace(u'</b>', u'\x04')
    t = t.replace(u'&', u'&amp;').replace(u'<', u'&lt;').replace(u'>', u'&gt;')
    t = t.replace(u'\x01', u'<font face="Courier">').replace(u'\x02', u'</font>')
    t = t.replace(u'\x03', u'<b>').replace(u'\x04', u'</b>')
    return t


def unicode_str(x):
    return x if isinstance(x, str) else str(x)


E = {
    'cab': ParagraphStyle('cab', fontName='Helvetica-Bold', fontSize=15, leading=18,
                          textColor=MARCA, spaceAfter=1 * mm),
    'sub': ParagraphStyle('sub', fontName='Helvetica', fontSize=8.5, leading=11,
                          textColor=CINZA, spaceAfter=3 * mm),
    'secao': ParagraphStyle('secao', fontName='Helvetica-Bold', fontSize=11, leading=13,
                            textColor=colors.white, backColor=MARCA,
                            borderPadding=(4, 5, 4, 5), spaceBefore=5 * mm, spaceAfter=1 * mm),
    'secaoSub': ParagraphStyle('secaoSub', fontName='Helvetica-Oblique', fontSize=8,
                               leading=10, textColor=CINZA, spaceAfter=2 * mm),
    'titulo': ParagraphStyle('titulo', fontName='Helvetica-Bold', fontSize=8.8, leading=11,
                             alignment=TA_LEFT, spaceBefore=1.6 * mm),
    'passo': ParagraphStyle('passo', fontName='Helvetica', fontSize=8, leading=10,
                            leftIndent=11 * mm, textColor=colors.HexColor('#1d1824')),
    'esperado': ParagraphStyle('esperado', fontName='Helvetica', fontSize=8, leading=10,
                               leftIndent=11 * mm, textColor=colors.HexColor('#14532d')),
    'jaaconteceu': ParagraphStyle('jaaconteceu', fontName='Helvetica-Oblique', fontSize=7.4,
                                  leading=9, leftIndent=11 * mm, textColor=colors.HexColor('#92400e')),
    'nota': ParagraphStyle('nota', fontName='Helvetica', fontSize=7, leading=9,
                           leftIndent=11 * mm, textColor=LINHA, spaceAfter=1.2 * mm,
                           borderWidth=0, borderPadding=0),
}


def bloco_do_teste(t):
    """Um teste: quadrado para marcar, titulo, passos, o que tem de acontecer, e a linha de nota."""
    partes = []
    reg = u' <font color="#92400e">[regressao]</font>' if t.get('reg') else u''
    partes.append(Paragraph(
        u'<font face="Courier-Bold">[&nbsp;&nbsp;]</font>&nbsp;&nbsp;'
        u'<font color="#5b21b6">%s</font>&nbsp; %s%s' % (papel(t['id']), papel(t['t']), reg),
        E['titulo']))
    passos = t.get('passos') or []
    if passos:
        # Numerados e em UM paragrafo: numa folha impressa, uma linha por passo dobraria o papel
        # sem acrescentar nada -- o numero ja diz a ordem.
        partes.append(Paragraph(
            u'&nbsp;'.join(u'<b>%d)</b> %s' % (i + 1, papel(p)) for i, p in enumerate(passos)),
            E['passo']))
    partes.append(Paragraph(u'<b>Tem de acontecer:</b> ' + papel(t.get('e', '')), E['esperado']))
    if t.get('f'):
        partes.append(Paragraph(u'Ja aconteceu: ' + papel(t['f']), E['jaaconteceu']))
    partes.append(Paragraph(u'_' * 112, E['nota']))
    return partes


def rodape(canvas, doc):
    canvas.saveState()
    canvas.setFont('Helvetica', 7.5)
    canvas.setFillColor(CINZA)
    canvas.drawString(14 * mm, 9 * mm, u'Roteiro de teste BoraHapp  %s  %s' % (VERSAO, DATA))
    canvas.drawRightString(A4[0] - 14 * mm, 9 * mm, u'pagina %d' % doc.page)
    canvas.setStrokeColor(LINHA)
    canvas.line(14 * mm, 12 * mm, A4[0] - 14 * mm, 12 * mm)
    canvas.restoreState()


def gerar():
    doc = BaseDocTemplate(SAIDA, pagesize=A4,
                          leftMargin=14 * mm, rightMargin=14 * mm,
                          topMargin=12 * mm, bottomMargin=16 * mm,
                          title=u'Roteiro de teste BoraHapp %s' % VERSAO,
                          author=u'BoraHapp')
    quadro = Frame(doc.leftMargin, doc.bottomMargin,
                   doc.width, doc.height, id='corpo',
                   leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
    doc.addPageTemplates([PageTemplate(id='pagina', frames=[quadro], onPage=rodape)])

    total = sum(len(s['testes']) for s in SECOES)
    reg = sum(1 for s in SECOES for t in s['testes'] if t.get('reg'))

    hist = []
    hist.append(Paragraph(u'Roteiro de teste - BoraHapp %s' % VERSAO, E['cab']))
    hist.append(Paragraph(
        u'%d testes em %d secoes, cobrindo as 35 telas e os 162 endpoints do sistema. '
        u'<b>%d sao de regressao</b>: defeito que ja aconteceu de verdade e nao pode voltar. '
        u'Gerado do inventario real do codigo em %s, nao de memoria.<br/>'
        u'Marque o quadrado quando passar. Quando falhar, escreva na linha o que voce viu e '
        u'guarde o <b>numero do item</b> - e por ele que o defeito vira conserto.'
        % (total, len(SECOES), reg, DATA), E['sub']))

    for s in SECOES:
        cabeca = [Paragraph(u'%s. %s' % (papel(s['n']), papel(s['t'])), E['secao'])]
        linha2 = u'  '.join(x for x in [papel(s.get('tela') or ''), papel(s.get('r') or '')] if x)
        if linha2:
            cabeca.append(Paragraph(linha2, E['secaoSub']))
        # A cabeca da secao nunca fica sozinha no pe da pagina, nem separada do primeiro teste.
        hist.append(KeepTogether(cabeca + bloco_do_teste(s['testes'][0])))
        for t in s['testes'][1:]:
            hist.append(KeepTogether(bloco_do_teste(t)))

    hist.append(Spacer(1, 4 * mm))
    hist.append(Paragraph(
        u'Fim. Itens marcados com [regressao] protegem defeito que ja aconteceu: '
        u'se um deles falhar, algo voltou atras.', E['sub']))
    doc.build(hist)
    return total, reg


def conferir_fontes():
    """Estoura se sobrou caractere que a fonte do PDF nao desenha.

    Sem isto, o PDF sai 'com sucesso' e com quadrados pretos no lugar das setas -- e quem
    descobre e quem esta com a folha na mao.
    """
    ruins = {}
    for s in SECOES:
        campos = [s.get('n', ''), s.get('t', ''), s.get('tela') or '', s.get('r') or '']
        for t in s['testes']:
            campos += [t.get('id', ''), t.get('t', ''), t.get('e', ''), t.get('f') or '']
            campos += list(t.get('passos') or [])
        for c in campos:
            for ch in papel(c):
                try:
                    ch.encode('latin-1')
                except Exception:
                    ruins[ch] = ruins.get(ch, 0) + 1
    if ruins:
        raise SystemExit(
            'PAREI: %d caractere(s) sairiam como quadrado preto no PDF: %s\n'
            'Acrescente cada um ao TRADUCAO, no topo deste arquivo.'
            % (len(ruins), ', '.join('%r (U+%04X, x%d)' % (c, ord(c), n) for c, n in ruins.items())))


if __name__ == '__main__':
    conferir_fontes()
    total, reg = gerar()
    tam = os.path.getsize(SAIDA)
    print(u'ok: %s (%d KB)' % (os.path.abspath(SAIDA), tam // 1024))
    print(u'   %d testes, %d secoes, %d de regressao' % (total, len(SECOES), reg))
