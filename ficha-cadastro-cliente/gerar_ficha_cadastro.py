"""Gera a Ficha de Cadastro e Ativação de Cliente — BoraHapp (PDF A4, campos preenchíveis).

Uso:  python gerar_ficha_cadastro.py
Saída: Ficha-Cadastro-Cliente-BoraHapp.pdf (nesta pasta)

Fontes dos dados: bora-projeto-completo/docs/GUIA_CADASTRO_DE_LOJA.md, entidades em
bora-fase-3-backend-java (Loja, ConfiguracaoLoja, Produto, ComplementoGrupo, TaxaEntrega, ...),
IntegracaoService.java, bora-landing/termos.html e precos.html. Cores: marca/MANUAL-DA-MARCA.md.
"""
import re
from io import BytesIO
from pathlib import Path

from reportlab.lib.colors import HexColor, white
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib.utils import simpleSplit
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (BaseDocTemplate, CondPageBreak, Flowable, Frame, KeepTogether, PageBreak,
                                PageTemplate, Paragraph, Spacer)

AQUI = Path(__file__).resolve().parent
MARCA = AQUI.parent / "marca"
SAIDA = AQUI / "Ficha-Cadastro-Cliente-BoraHapp.pdf"
VERSAO = "Versão 1.0 · novembro/2026"

# ------------------------------------------------------------------ marca (MANUAL-DA-MARCA.md + site.css)
ROXO = HexColor("#9333EA")
ROXO_ESC = HexColor("#7E22CE")
ROXO_FRACO = HexColor("#F6EDFE")
TINTA = HexColor("#1B1512")
TINTA2 = HexColor("#4B4039")
FUMACA = HexColor("#7C6F66")
PAPEL = HexColor("#FBF7F3")
LINHA = HexColor("#E7DCD0")
LINHA_F = HexColor("#D4C4B4")
VERDE = HexColor("#176B4F")
VERDE_FRACO = HexColor("#E6F2EC")
ALERTA = HexColor("#B03D1E")
ALERTA_FRACA = HexColor("#FCEDE7")

EMPRESA = "BoraHapp · ADF Sistemas e Tecnologias LTDA · CNPJ 68.761.778/0001-57"
CONTATO = "borahapp.com.br · WhatsApp (15) 99860-2332"


def _fontes():
    """Segoe UI (mesma família do logo e do site). Sem ela, cai para Helvetica."""
    win = Path("C:/Windows/Fonts")
    nomes = {"R": "segoeui.ttf", "B": "segoeuib.ttf", "S": "seguisb.ttf", "K": "seguibl.ttf"}
    try:
        for k, f in nomes.items():
            pdfmetrics.registerFont(TTFont(f"Bora-{k}", str(win / f)))
        pdfmetrics.registerFontFamily("Bora-R", normal="Bora-R", bold="Bora-B", italic="Bora-R", boldItalic="Bora-B")
        return {k: f"Bora-{k}" for k in nomes}
    except Exception:
        return {"R": "Helvetica", "B": "Helvetica-Bold", "S": "Helvetica-Bold", "K": "Helvetica-Bold"}


F = _fontes()
LOGO = MARCA / "borahapp-horizontal.png"          # fundo claro
LOGO_PROP = 1020 / 2400

_contador = {"n": 0}


def _nome(rotulo):
    _contador["n"] += 1
    base = re.sub(r"[^a-z0-9]+", "_", rotulo.lower().encode("ascii", "ignore").decode())[:30].strip("_") or "campo"
    return f"{base}_{_contador['n']}"


# ------------------------------------------------------------------ estilos de texto
def est(nome, fonte="R", tam=9, cor=TINTA, lead=None, **kw):
    return ParagraphStyle(nome, fontName=F[fonte], fontSize=tam, textColor=cor, leading=lead or tam * 1.4, **kw)


TXT = est("txt", tam=9, cor=TINTA2)
TXT_P = est("txtp", tam=8, cor=FUMACA)
AVISO_TXT = est("aviso", tam=8.5, cor=TINTA2, lead=12.5)
SUB = est("sub", tam=8.5, cor=FUMACA, lead=12, spaceAfter=2)


# ------------------------------------------------------------------ peças visuais
class Secao(Flowable):
    """Cabeçalho de seção: número no quadrado roxo + título + selo (opcional / uso interno)."""

    def __init__(self, num, titulo, selo=None):
        super().__init__()
        self.num, self.titulo, self.selo = num, titulo, selo

    def wrap(self, aw, ah):
        self.aw = aw
        return aw, 12 * mm

    def draw(self):
        c = self.canv
        c.setFillColor(ROXO)
        c.roundRect(0, 2 * mm, 8.5 * mm, 8.5 * mm, 2 * mm, stroke=0, fill=1)
        c.setFillColor(white)
        c.setFont(F["K"], 12)
        c.drawCentredString(4.25 * mm, 4.9 * mm, str(self.num))
        c.setFillColor(TINTA)
        c.setFont(F["K"], 14)
        c.drawString(11.5 * mm, 4.2 * mm, self.titulo)
        if self.selo:
            tw = pdfmetrics.stringWidth(self.titulo, F["K"], 14)
            fundo, cor = (VERDE_FRACO, VERDE) if self.selo == "opcional" else (ROXO_FRACO, ROXO_ESC)
            texto = self.selo.upper()
            w = pdfmetrics.stringWidth(texto, F["B"], 6.5) + 5 * mm
            x = 11.5 * mm + tw + 3 * mm
            c.setFillColor(fundo)
            c.roundRect(x, 3.6 * mm, w, 5 * mm, 2.5 * mm, stroke=0, fill=1)
            c.setFillColor(cor)
            c.setFont(F["B"], 6.5)
            c.drawCentredString(x + w / 2, 5.3 * mm, texto)
        c.setStrokeColor(LINHA)
        c.setLineWidth(0.6)
        c.line(0, 0.6 * mm, self.aw, 0.6 * mm)


class Linha(Flowable):
    """Linha de campos. campos = [(rótulo, fração, tipo)]
    tipo: 'texto' | 'texto:N' (N linhas) | 'cor' (texto + amostra) | 'check' (caixa de marcar)."""

    def __init__(self, campos):
        super().__init__()
        self.campos = campos

    def _alt_caixa(self, tipo):
        if tipo.startswith("texto:"):
            return int(tipo.split(":")[1]) * 5.2 * mm + 1.8 * mm
        return 7 * mm

    def wrap(self, aw, ah):
        self.aw = aw
        caixas = [self._alt_caixa(t) for _, _, t in self.campos if t != "check"] or [7 * mm]
        self.alt_caixa = max(caixas)
        tem_rotulo = any(t != "check" for _, _, t in self.campos)
        self.h = self.alt_caixa + (4 * mm if tem_rotulo else 0) + 2.6 * mm
        return aw, self.h

    def draw(self):
        c = self.canv
        gap = 3 * mm
        util = self.aw - gap * (len(self.campos) - 1)
        x = 0
        base = 2.6 * mm
        for rotulo, frac, tipo in self.campos:
            w = util * frac
            obrig = rotulo.endswith("*")
            nome = rotulo.rstrip("*").strip()
            if tipo == "check":
                y = base + (self.alt_caixa - 4.2 * mm) / 2
                c.acroForm.checkbox(name=_nome(nome), tooltip=nome, x=x, y=y, size=4.2 * mm, buttonStyle="check",
                                    borderColor=LINHA_F, fillColor=white, textColor=ROXO, borderWidth=0.8,
                                    relative=True)
                c.setFillColor(TINTA)
                c.setFont(F["R"], 8.5)
                linhas = simpleSplit(nome, F["R"], 8.5, w - 6 * mm)
                ty = y + 1.2 * mm + (len(linhas) - 1) * 1.7 * mm
                for ln in linhas:
                    c.drawString(x + 5.8 * mm, ty, ln)
                    ty -= 3.4 * mm
            else:
                hb = self._alt_caixa(tipo)
                yb = base + self.alt_caixa - hb
                # rótulo
                c.setFont(F["S"], 7.2)
                c.setFillColor(FUMACA)
                c.drawString(x, base + self.alt_caixa + 1.2 * mm, nome)
                if obrig:
                    c.setFillColor(ROXO)
                    c.drawString(x + pdfmetrics.stringWidth(nome, F["S"], 7.2) + 0.6 * mm, base + self.alt_caixa + 1.2 * mm, "*")
                larg = w - (9 * mm if tipo == "cor" else 0)
                c.setFillColor(white)
                c.setStrokeColor(LINHA_F)
                c.setLineWidth(0.7)
                c.roundRect(x, yb, larg, hb, 1.6 * mm, stroke=1, fill=1)
                multi = tipo.startswith("texto:")
                c.acroForm.textfield(name=_nome(nome), tooltip=nome, x=x + 0.8 * mm, y=yb + 0.6 * mm,
                                     width=larg - 1.6 * mm, height=hb - 1.2 * mm, borderWidth=0, borderColor=white,
                                     fillColor=white, textColor=TINTA, fontName="Helvetica", fontSize=9,
                                     fieldFlags="multiline" if multi else "", relative=True)
                if tipo == "cor":                      # quadrado para colar/pintar a amostra da cor
                    c.setFillColor(white)
                    c.setStrokeColor(LINHA_F)
                    c.setDash(2, 1.5)
                    c.roundRect(x + larg + 2 * mm, yb, 7 * mm, hb, 1.6 * mm, stroke=1, fill=1)
                    c.setDash()
            x += w + gap


class Tabela(Flowable):
    """Tabela preenchível. colunas = [(título, fração, tipo)], tipo: 'texto' | 'check' | 'fixo' | 'fixo_b'.
    valores = lista de linhas com o texto das colunas fixas (None nas colunas preenchíveis)."""

    def __init__(self, colunas, linhas=0, valores=None, alt=6.6 * mm):
        super().__init__()
        self.colunas, self.alt = colunas, alt
        self.valores = valores or [[None] * len(colunas) for _ in range(linhas)]

    def wrap(self, aw, ah):
        self.aw = aw
        self.larg = [aw * f for _, f, _ in self.colunas]
        self.alts = []
        for linha in self.valores:
            n = 1
            for (t, f, tipo), w, v in zip(self.colunas, self.larg, linha):
                if tipo.startswith("fixo") and v:
                    fonte = F["B"] if tipo == "fixo_b" else F["R"]
                    n = max(n, len(simpleSplit(v, fonte, 7.8, w - 3 * mm)))
            self.alts.append(max(self.alt, n * 3.5 * mm + 2.6 * mm))
        self.h = 6.2 * mm + sum(self.alts)
        return aw, self.h

    def draw(self):
        c = self.canv
        y = self.h - 6.2 * mm
        c.setFillColor(ROXO_FRACO)
        c.roundRect(0, y, self.aw, 6.2 * mm, 1.6 * mm, stroke=0, fill=1)
        c.setFillColor(ROXO_ESC)
        c.setFont(F["B"], 7.2)
        x = 0
        for (titulo, _, _), w in zip(self.colunas, self.larg):
            c.drawString(x + 1.6 * mm, y + 2.1 * mm, titulo)
            x += w
        for i, (linha, h) in enumerate(zip(self.valores, self.alts)):
            y -= h
            c.setFillColor(white if i % 2 == 0 else PAPEL)
            c.rect(0, y, self.aw, h, stroke=0, fill=1)
            x = 0
            for (titulo, _, tipo), w, v in zip(self.colunas, self.larg, linha):
                if tipo == "check":
                    s = 4 * mm
                    c.acroForm.checkbox(name=_nome(titulo or "marcar"), tooltip=titulo, x=x + (w - s) / 2,
                                        y=y + (h - s) / 2, size=s, buttonStyle="check", borderColor=LINHA_F,
                                        fillColor=white, textColor=ROXO, borderWidth=0.8, relative=True)
                elif tipo.startswith("fixo"):
                    fonte = F["B"] if tipo == "fixo_b" else F["R"]
                    c.setFillColor(TINTA if tipo == "fixo_b" else TINTA2)
                    c.setFont(fonte, 7.8)
                    ls = simpleSplit(v or "", fonte, 7.8, w - 3 * mm)
                    ty = y + h / 2 + (len(ls) - 1) * 1.75 * mm - 1 * mm
                    for ln in ls:
                        c.drawString(x + 1.6 * mm, ty, ln)
                        ty -= 3.5 * mm
                else:
                    c.acroForm.textfield(name=_nome(titulo or "celula"), tooltip=titulo, x=x + 0.6 * mm, y=y + 0.7 * mm,
                                         width=w - 1.2 * mm, height=h - 1.4 * mm, borderWidth=0, borderColor=white,
                                         fillColor=white if i % 2 == 0 else PAPEL, textColor=TINTA,
                                         fontName="Helvetica", fontSize=8, relative=True)
                x += w
            c.setStrokeColor(LINHA)
            c.setLineWidth(0.5)
            c.line(0, y, self.aw, y)
        # divisórias verticais
        x = 0
        c.setStrokeColor(LINHA)
        for w in self.larg[:-1]:
            x += w
            c.line(x, 0, x, self.h - 6.2 * mm)
        c.setStrokeColor(LINHA_F)
        c.setLineWidth(0.7)
        c.roundRect(0, 0, self.aw, self.h, 1.6 * mm, stroke=1, fill=0)


class Lista(Flowable):
    """Itens com caixa de marcar, em 1 ou 2 colunas."""

    def __init__(self, itens, colunas=1, tam=8.5):
        super().__init__()
        self.itens, self.ncol, self.tam = itens, colunas, tam

    def wrap(self, aw, ah):
        self.aw = aw
        self.wcol = (aw - 4 * mm * (self.ncol - 1)) / self.ncol
        self.linhas = [simpleSplit(t, F["R"], self.tam, self.wcol - 7 * mm) for t in self.itens]
        self.alt_item = [len(ls) * 3.7 * mm + 2.4 * mm for ls in self.linhas]
        porcol = -(-len(self.itens) // self.ncol)
        self.cols = [list(range(len(self.itens)))[k * porcol:(k + 1) * porcol] for k in range(self.ncol)]
        self.h = max(sum(self.alt_item[i] for i in col) for col in self.cols) if self.itens else 0
        return aw, self.h

    def draw(self):
        c = self.canv
        for k, col in enumerate(self.cols):
            x = k * (self.wcol + 4 * mm)
            y = self.h
            for i in col:
                h = self.alt_item[i]
                y -= h
                topo = y + h - 1.2 * mm
                c.acroForm.checkbox(name=_nome(self.itens[i]), tooltip=self.itens[i], x=x, y=topo - 4.2 * mm,
                                    size=4.2 * mm, buttonStyle="check", borderColor=LINHA_F, fillColor=white,
                                    textColor=ROXO, borderWidth=0.8, relative=True)
                c.setFillColor(TINTA)
                c.setFont(F["R"], self.tam)
                ty = topo - 3.1 * mm
                for ln in self.linhas[i]:
                    c.drawString(x + 6 * mm, ty, ln)
                    ty -= 3.7 * mm


class Aviso(Flowable):
    """Caixa de destaque com barra lateral (info = roxo, alerta = vermelho, ok = verde)."""

    def __init__(self, html, tipo="info"):
        super().__init__()
        self.p = Paragraph(html, AVISO_TXT)
        self.fundo, self.barra = {"info": (PAPEL, ROXO), "alerta": (ALERTA_FRACA, ALERTA),
                                  "ok": (VERDE_FRACO, VERDE)}[tipo]

    def wrap(self, aw, ah):
        self.aw = aw
        _, ph = self.p.wrap(aw - 9 * mm, ah)
        self.h = ph + 5 * mm
        return aw, self.h

    def draw(self):
        c = self.canv
        c.setFillColor(self.fundo)
        c.roundRect(0, 0, self.aw, self.h, 2 * mm, stroke=0, fill=1)
        c.setFillColor(self.barra)
        c.roundRect(0, 0, 1.4 * mm, self.h, 0.7 * mm, stroke=0, fill=1)
        self.p.drawOn(c, 5 * mm, 2.5 * mm)


class Capa(Flowable):
    """Topo da primeira página: logo, título e o lema da marca."""

    def wrap(self, aw, ah):
        self.aw = aw
        return aw, 44 * mm

    def draw(self):
        c = self.canv
        c.setFillColor(PAPEL)
        c.roundRect(0, 0, self.aw, 44 * mm, 4 * mm, stroke=0, fill=1)
        lw = 50 * mm
        c.drawImage(str(LOGO), 6 * mm, 44 * mm - 5 * mm - lw * LOGO_PROP, lw, lw * LOGO_PROP, mask="auto")
        c.setFillColor(ROXO_ESC)
        c.setFont(F["B"], 7.5)
        c.drawString(7 * mm, 17.5 * mm, "F I C H A   D E   A T I V A Ç Ã O")
        c.setFillColor(TINTA)
        c.setFont(F["K"], 21)
        c.drawString(7 * mm, 9.5 * mm, "Cadastro de novo cliente")
        c.setFont(F["R"], 9.5)
        c.setFillColor(TINTA2)
        c.drawString(7 * mm, 4.5 * mm, "Tudo o que precisamos para deixar a sua loja 100% ativa no BoraHapp.")
        # lema à direita
        c.setFillColor(ROXO)
        c.setFont(F["K"], 13)
        c.drawRightString(self.aw - 7 * mm, 34 * mm, "Seu delivery,")
        c.drawRightString(self.aw - 7 * mm, 28.5 * mm, "no seu controle.")
        c.setFillColor(FUMACA)
        c.setFont(F["R"], 7.5)
        c.drawRightString(self.aw - 7 * mm, 23 * mm, "Mensalidade fixa · sem taxa por pedido")
        c.drawRightString(self.aw - 7 * mm, 4.5 * mm, VERSAO)


def legenda(txt):
    return Paragraph(txt, SUB)


def espaco(h=3):
    return Spacer(1, h * mm)


# ------------------------------------------------------------------ conteúdo
def bloco_loja(n):
    return KeepTogether([
        Paragraph(f"<font name='{F['B']}' color='#7E22CE'>LOJA {n}</font>", est(f"l{n}", tam=8)),
        espaco(1),
        Linha([("Nome da loja (como o cliente vê)*", 0.62, "texto"), ("CNPJ ou CPF da loja", 0.38, "texto")]),
        Linha([("CEP*", 0.18, "texto"), ("Logradouro (rua, avenida)*", 0.62, "texto"), ("Número*", 0.2, "texto")]),
        Linha([("Complemento", 0.24, "texto"), ("Bairro*", 0.3, "texto"), ("Cidade*", 0.34, "texto"), ("UF*", 0.12, "texto")]),
        Linha([("Telefone / WhatsApp de atendimento ao cliente", 0.5, "texto"),
               ("Ponto de referência / observação", 0.5, "texto")]),
        espaco(2),
    ])


def conteudo():
    s = []
    s += [Capa(), espaco(3)]
    s += [Paragraph(f"<font name='{F['B']}' color='#7E22CE'>USO INTERNO BORA</font>", est("ui", tam=7.5)), espaco(1),
          Linha([("Data do cadastro", 0.2, "texto"), ("Consultor(a) Bora", 0.34, "texto"),
                 ("ID da loja (gerado no sistema)", 0.24, "texto"), ("Origem do cliente", 0.22, "texto")]),
          espaco(1)]
    s += [Aviso(
        "<b>Como preencher.</b> Os campos são editáveis no leitor de PDF (Adobe, Edge, Chrome) — ou imprima e preencha "
        "à mão. Campos com <font color='#9333EA'><b>*</b></font> são obrigatórios para ativar a loja. Uma ficha por "
        "cliente; se houver mais de uma loja, preencha a seção 3 para cada uma. "
        "<b>Por segurança, não escreva senhas, tokens nem “Client Secret” nesta ficha</b> — eles são digitados pelo "
        "próprio cliente no painel."), espaco(4)]
    s += [Paragraph(f"<font name='{F['K']}' size='11'>Antes de começar, separe</font>", est("sep", cor=TINTA)), espaco(2),
          Lista(["Logo em PNG com fundo transparente (mínimo 512 × 512 px)",
                 "Cor da marca (código hex, ex.: #9333EA) ou uma referência",
                 "Cardápio: foto, print do iFood ou planilha (Categoria ; Nome ; Preço)",
                 "Bairros atendidos com taxa de entrega e tempo",
                 "Horários reais de funcionamento",
                 "CPF/CNPJ e dados do responsável",
                 "RG ou CNH (frente e verso) e uma selfie — só para receber PIX",
                 "Acesso de super-admin ao iFood / portal 99 — só se for integrar"], colunas=2), espaco(3)]

    # 1 ---------------------------------------------------------------- empresa
    s += [KeepTogether([
        Secao(1, "Dados da empresa"), espaco(2),
        Linha([("Razão social*", 0.64, "texto"), ("CNPJ ou CPF*", 0.36, "texto")]),
        Linha([("Nome fantasia", 0.64, "texto"), ("Inscrição estadual (só para NFC-e)", 0.36, "texto")]),
        legenda("Tipo de empresa (para CNPJ):"),
        Linha([("MEI", 0.2, "check"), ("LTDA", 0.2, "check"), ("Empresário individual", 0.3, "check"),
               ("Associação", 0.3, "check")]),
        legenda("Lojas com o mesmo CNPJ ficam na mesma empresa e podem ser acessadas com o mesmo login."),
        espaco(4)])]

    # 2 ---------------------------------------------------------------- responsável
    s += [KeepTogether([
        Secao(2, "Responsável e acesso ao painel"), espaco(2),
        Linha([("Nome completo*", 0.64, "texto"), ("CPF*", 0.36, "texto")]),
        Linha([("E-mail de acesso (será o login e o e-mail de cobrança)*", 0.64, "texto"),
               ("Celular / WhatsApp do dono*", 0.36, "texto")]),
        Linha([("Data de nascimento (obrigatória para PIX com CPF)", 0.5, "texto"),
               ("Cargo / função na empresa", 0.5, "texto")]),
        Aviso("A <b>senha</b> (mínimo de 8 caracteres) é criada pelo próprio responsável no primeiro acesso. "
              "O WhatsApp do dono recebe o resumo diário de vendas quando o Módulo IA está contratado."),
        espaco(4)])]

    # 3 ---------------------------------------------------------------- lojas
    s += [CondPageBreak(95 * mm), Secao(3, "Lojas / unidades"), espaco(1),
          legenda("Uma loja por bloco. Mais de 2 lojas? Use uma cópia desta página."), espaco(1),
          bloco_loja(1), bloco_loja(2)]

    # 4 ---------------------------------------------------------------- identidade visual
    s += [KeepTogether([
        Secao(4, "Identidade visual (a cara da sua loja)"), espaco(2),
        Linha([("Nome de exibição no cardápio e no app*", 0.6, "texto"), ("Nome do sistema (opcional)", 0.4, "texto")]),
        Linha([("Cor principal (hex, ex.: #9333EA)*", 0.5, "cor"), ("Cor secundária (hex)", 0.5, "cor")]),
        Linha([("Logo enviado (PNG transparente, mín. 512 px)*", 0.5, "check"),
               ("Banner / imagem de capa enviada (opcional)", 0.5, "check")]),
        Linha([("Subdomínio desejado (opcional)", 0.5, "texto"),
               ("Cashback para clientes (% de 0 a 50 — padrão 5%)", 0.5, "texto")]),
        Linha([("Observações sobre a marca", 1, "texto:2")]),
        Aviso("O painel, o cardápio e o app instalável ficam com a <b>sua</b> marca e as <b>suas</b> cores. "
              "A assinatura “BoraHapp” aparece discretamente no rodapé."),
        espaco(4)])]

    # 5 ---------------------------------------------------------------- horários
    dias = ["Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado"]
    s += [KeepTogether([
        Secao(5, "Horário de funcionamento"), espaco(2),
        Tabela([("Dia", 0.22, "fixo_b"), ("Abre (HH:mm)", 0.18, "texto"), ("Fecha (HH:mm)", 0.18, "texto"),
                ("Aberto?", 0.12, "check"), ("Observação", 0.30, "texto")],
               valores=[[d, None, None, None, None] for d in dias]),
        espaco(1),
        legenda("Um intervalo por dia. Sem preencher, a loja começa com 18:00–23:00 todos os dias — confirme com o cliente."),
        espaco(4)])]

    # 6 ---------------------------------------------------------------- entrega
    s += [KeepTogether([
        Secao(6, "Área de entrega e entregadores"), espaco(2),
        Tabela([("Bairro", 0.26, "texto"), ("Taxa (R$)", 0.12, "texto"), ("Tempo (min)", 0.12, "texto"),
                ("Bairro", 0.26, "texto"), ("Taxa (R$)", 0.12, "texto"), ("Tempo (min)", 0.12, "texto")], linhas=10),
        espaco(1),
        legenda("<b>Obrigatório pelo menos 1 bairro com taxa</b> — sem isso o cliente não consegue fechar pedido "
                "com entrega. Mais bairros: anexe uma lista."),
        espaco(2)])]
    s += [KeepTogether([
        Paragraph(f"<font name='{F['B']}' color='#7E22CE'>ENTREGADORES (não precisam de login)</font>", est("ent", tam=8)),
        espaco(1),
        Tabela([("Nome", 0.36, "texto"), ("Telefone", 0.24, "texto"),
                ("Veículo (moto, bike, carro, a pé)", 0.28, "texto"), ("Ativo?", 0.12, "check")], linhas=4),
        espaco(4)])]

    # 7 ---------------------------------------------------------------- pagamentos
    s += [KeepTogether([
        Secao(7, "Formas de pagamento aceitas"), espaco(2),
        Linha([("Dinheiro (com troco)", 0.33, "check"), ("PIX online pelo BoraHapp", 0.34, "check"),
               ("Cartão de crédito na entrega", 0.33, "check")]),
        Linha([("Cartão de débito na entrega", 0.33, "check"), ("Vale-refeição", 0.34, "check"),
               ("Outra (escreva ao lado)", 0.33, "check")]),
        Linha([("Outras formas / observações", 1, "texto")]),
        espaco(4)])]

    # 8 ---------------------------------------------------------------- PIX
    s += [KeepTogether([
        Secao(8, "Recebimento por PIX no cardápio", "opcional"), espaco(1),
        legenda("Conta de recebimento criada pela Bora (Asaas). O dinheiro do PIX cai na conta da loja."),
        espaco(1),
        Linha([("CPF ou CNPJ do titular*", 0.4, "texto"), ("Celular*", 0.3, "texto"),
               ("Faturamento mensal aprox. (R$)*", 0.3, "texto")]),
        Linha([("Data de nascimento (se CPF)", 0.3, "texto"), ("CEP*", 0.2, "texto"), ("Endereço*", 0.5, "texto")]),
        Linha([("Número*", 0.2, "texto"), ("Bairro*", 0.4, "texto"), ("Complemento", 0.4, "texto")]),
        legenda("Validação de identidade — feita no aplicativo Asaas, pelo link que a Bora envia:"),
        Linha([("RG ou CNH com foto (frente e verso)", 0.5, "check"), ("Selfie do responsável", 0.5, "check")]),
        espaco(4)])]

    # 9 ---------------------------------------------------------------- cardápio
    s += [CondPageBreak(120 * mm), Secao(9, "Cardápio"), espaco(1),
          legenda("Como o cardápio vai chegar até a Bora:"),
          Linha([("Foto do cardápio impresso", 0.25, "check"), ("Print / arquivo do iFood", 0.25, "check"),
                 ("Planilha (Categoria ; Nome ; Preço)", 0.3, "check"), ("Vou cadastrar no painel", 0.2, "check")]),
          espaco(1),
          Tabela([("Categoria", 0.17, "texto"), ("Produto*", 0.31, "texto"), ("Preço (R$)*", 0.11, "texto"),
                  ("Custo (R$)", 0.1, "texto"), ("Código iFood / 99", 0.15, "texto"), ("Estoque", 0.08, "texto"),
                  ("Foto?", 0.08, "check")], linhas=16),
          espaco(1),
          legenda("Custo serve para calcular o lucro (CMV). Estoque em branco = não controla. "
                  "“Código iFood / 99” é o código externo do item no marketplace. Mais itens: anexe a planilha."),
          espaco(3),
          KeepTogether([
              Paragraph(f"<font name='{F['B']}' color='#7E22CE'>COMPLEMENTOS E VARIAÇÕES</font>", est("comp", tam=8)),
              legenda("Ex.: grupo “Tamanho” mín. 1 / máx. 1 · grupo “Adicionais” mín. 0 / máx. 5."),
              Tabela([("Produto", 0.22, "texto"), ("Grupo (ex.: Tamanho)", 0.2, "texto"), ("Mín.", 0.07, "texto"),
                      ("Máx.", 0.07, "texto"), ("Opções e preços (ex.: Bacon +R$ 4,00; Cheddar +R$ 3,00)", 0.44, "texto")],
                     linhas=8),
              espaco(4)])]

    # 10 --------------------------------------------------------------- integradores
    integ = [
        # "Em homologacao" ficou errado nos dois: o iFood entrega pedido no painel desde 19/09/2026
        # (7 pedidos medidos no banco) e as 5 lojas do 99Food autenticam e consultam pedido desde
        # 10/11/2026. Medido na producao em 12/11/2026 -- e o 99 fica "Conectado", e nao "No ar",
        # porque nenhum pedido chegou por ele ainda.
        ["iFood", "Merchant ID da loja (Portal do Parceiro). O vínculo é autorizado por um super-admin da conta "
                  "iFood com o código que o painel gera.", "No ar"],
        ["99Food", "App Shop ID da loja (shopId, no painel da loja no 99Food).", "Conectado"],
        ["Rappi", "Merchant ID e Client ID do portal Rappi.", "Vínculo manual"],
        ["Uber Eats", "Merchant ID (Store ID) e Client ID.", "Vínculo manual"],
        ["aiqfome", "Merchant ID e Client ID.", "Vínculo manual"],
        ["Goomer", "Merchant ID e Client ID.", "Vínculo manual"],
        ["WhatsApp (Meta)", "Número do WhatsApp Business e Phone Number ID.", "Sob consulta"],
        ["PIX no cardápio", "Conta de recebimento criada pela Bora (seção 8). Informe o ID da subconta.", "Disponível"],
        ["NFC-e (Focus NFe)", "CNPJ com 14 dígitos, inscrição estadual e certificado digital A1 no painel Focus.",
         "Sob consulta"],
        ["Módulo IA", "Resumo diário no WhatsApp do dono e cardápio por foto. +R$ 99/mês por loja.", "Disponível"],
    ]
    s += [CondPageBreak(130 * mm), KeepTogether([
        Secao(10, "Integradores e IDs de acesso"), espaco(1),
        legenda("Marque o que a loja vai usar e anote os IDs. As credenciais secretas são digitadas no painel, "
                "em Integrações."),
        Tabela([("Usar?", 0.08, "check"), ("Integrador", 0.16, "fixo_b"), ("O que informar", 0.36, "fixo"),
                ("ID / código da loja", 0.26, "texto"), ("Situação", 0.14, "fixo")],
               valores=[[None, a, b, None, sit] for a, b, sit in integ]),
        espaco(2),
        Linha([("Aceitar automaticamente os pedidos dos marketplaces", 0.5, "check"),
               ("Usar o mesmo cardápio do iFood / 99 (importar)", 0.5, "check")]),
        Aviso("<b>Nunca escreva Client Secret, tokens ou senhas nesta ficha.</b> Eles dão acesso à conta da loja e "
              "são digitados pelo próprio cliente no painel, em <b>Integrações</b>. Ordem recomendada de ativação: "
              "conteúdo → assinatura → PIX → WhatsApp → marketplaces.", "alerta"),
        espaco(4)])]

    # 11 --------------------------------------------------------------- equipe
    s += [KeepTogether([
        Secao(11, "Equipe (usuários do painel)", "opcional"), espaco(1),
        legenda("Até 15 usuários ativos por loja. Cada pessoa cria a própria senha no primeiro acesso."),
        Tabela([("Nome", 0.26, "texto"), ("E-mail (login)", 0.32, "texto"),
                ("Papel (Operador / Gerente / Admin.)", 0.27, "texto"), ("Loja(s)", 0.15, "texto")], linhas=8),
        espaco(4)])]

    # 12 --------------------------------------------------------------- plano
    s += [KeepTogether([
        Secao(12, "Plano e condições"), espaco(2),
        Aviso("<b>Plano Único — R$ 199/mês por loja.</b> Pedidos ilimitados · até 15 usuários · sem taxa por pedido. "
              "Teste grátis de 7 dias · garantia de reembolso de 7 dias após a 1ª cobrança · sem fidelidade e sem multa · "
              "suspensão após 10 dias sem pagamento · 10 dias de acesso ao painel após cancelar · reajuste avisado com "
              "30 dias de antecedência.", "ok"),
        espaco(2),
        Linha([("Valor mensal por loja (R$)*", 0.34, "texto"), ("Quantidade de lojas*", 0.3, "texto"),
               ("Total mensal (R$)*", 0.36, "texto")]),
        Linha([("Módulo IA (+R$ 99/mês por loja)", 0.5, "check"), ("Condição especial de fundador", 0.5, "check")]),
        Linha([("Observações comerciais", 1, "texto:2")]),
        legenda("Aceites do cliente:"),
        Lista(["Li e aceito os Termos de Uso do BoraHapp (versão 2026-10-04 — borahapp.com.br/termos.html).",
               "Estou ciente de que, pela LGPD, a loja é a controladora dos dados dos seus clientes e a Bora atua "
               "como operadora, tratando os dados só para prestar o serviço."]),
        espaco(4)])]

    # 13 --------------------------------------------------------------- checklist interno
    s += [CondPageBreak(150 * mm), Secao(13, "Checklist de ativação", "uso interno Bora"), espaco(2),
          Paragraph(f"<font name='{F['B']}' color='#7E22CE'>ANTES DE ENTREGAR O PAINEL</font>", est("c1", tam=8)),
          espaco(1),
          Lista(["Preço negociado lançado ANTES de o cliente assinar",
                 "Split do PIX definido (padrão 2%)",
                 "Módulo IA ligado (se contratado)",
                 "Cashback e horários conferidos com o cliente (não deixar o padrão 5% e 18h–23h sem confirmar)"],
                colunas=2), espaco(3),
          Paragraph(f"<font name='{F['B']}' color='#7E22CE'>“COMECE POR AQUI” — A LOJA ESTÁ OPERANDO QUANDO 1 A 5 "
                    f"ESTÃO VERDES</font>", est("c2", tam=8)),
          espaco(1),
          Lista(["1. Logo salvo", "2. Pelo menos 1 produto ativo", "3. Pelo menos 1 bairro com taxa",
                 "4. Horários de funcionamento definidos", "5. Assinatura ATIVA no Asaas",
                 "6. Equipe cadastrada (opcional)", "7. Recebimento por PIX ativo (opcional)",
                 "8. Integradores marcados na seção 10 conectados"], colunas=2), espaco(3),
          Paragraph(f"<font name='{F['B']}' color='#7E22CE'>TESTE DE ACEITE (FAZER JUNTO COM O CLIENTE)</font>",
                    est("c3", tam=8)),
          espaco(1),
          Lista(["Pedido por telefone com um produto que tem complementos", "Cupom aplicado no pedido",
                 "Pedido fechado e levado até ENTREGUE", "Link público de acompanhamento conferido",
                 "Dashboard e Relatório conferidos", "Link do cardápio enviado ao cliente"], colunas=2),
          espaco(3),
          Linha([("Link do cardápio (borahapp.com.br/cardapio.html?loja=ID)", 0.6, "texto"),
                 ("Data da ativação", 0.2, "texto"), ("Responsável Bora", 0.2, "texto")]),
          espaco(6)]

    # 14 --------------------------------------------------------------- assinaturas
    s += [KeepTogether([Secao(14, "Assinaturas"), espaco(4), Assinaturas(), espaco(2),
                        Linha([("Local", 0.6, "texto"), ("Data", 0.4, "texto")])])]
    return s


class Assinaturas(Flowable):
    def wrap(self, aw, ah):
        self.aw = aw
        return aw, 26 * mm

    def draw(self):
        c = self.canv
        w = (self.aw - 10 * mm) / 2
        for i, (titulo, sub) in enumerate([("Cliente / responsável legal", "Nome e CPF"),
                                           ("Consultor(a) BoraHapp", "ADF Sistemas e Tecnologias LTDA")]):
            x = i * (w + 10 * mm)
            c.setStrokeColor(TINTA2)
            c.setLineWidth(0.7)
            c.line(x, 14 * mm, x + w, 14 * mm)
            c.setFillColor(TINTA)
            c.setFont(F["B"], 8.5)
            c.drawString(x, 10 * mm, titulo)
            c.setFillColor(FUMACA)
            c.setFont(F["R"], 7.5)
            c.drawString(x, 6.5 * mm, sub)
            c.acroForm.textfield(name=_nome("nome_" + titulo), tooltip=f"Nome — {titulo}", x=x, y=0, width=w,
                                 height=5.5 * mm, borderWidth=0.6, borderColor=LINHA_F, fillColor=white,
                                 textColor=TINTA, fontName="Helvetica", fontSize=8, relative=True)


# ------------------------------------------------------------------ página
ML, MR, MT, MB = 16 * mm, 16 * mm, 19 * mm, 17 * mm


def _pagina(total):
    def desenhar(c, doc):
        W, H = A4
        c.saveState()
        if doc.page > 1:                                   # cabeçalho discreto a partir da 2ª página
            lw = 30 * mm
            c.drawImage(str(LOGO), ML, H - 13.5 * mm, lw, lw * LOGO_PROP, mask="auto")
            c.setFont(F["S"], 7.5)
            c.setFillColor(FUMACA)
            c.drawRightString(W - MR, H - 10 * mm, f"Ficha de cadastro e ativação de cliente · {VERSAO}")
            c.setStrokeColor(LINHA)
            c.setLineWidth(0.6)
            c.line(ML, H - 15 * mm, W - MR, H - 15 * mm)
        c.setStrokeColor(LINHA)
        c.line(ML, 11.5 * mm, W - MR, 11.5 * mm)
        c.setFont(F["R"], 6.8)
        c.setFillColor(FUMACA)
        c.drawString(ML, 7.5 * mm, EMPRESA)
        c.drawRightString(W - MR, 7.5 * mm, f"{CONTATO}   ·   Página {doc.page} de {total}")
        c.restoreState()
    return desenhar


def montar(destino, total):
    _contador["n"] = 0
    doc = BaseDocTemplate(str(destino) if not hasattr(destino, "write") else destino, pagesize=A4,
                          leftMargin=ML, rightMargin=MR, topMargin=MT, bottomMargin=MB,
                          title="Ficha de Cadastro e Ativação de Cliente — BoraHapp", author="BoraHapp",
                          subject="Cadastro de novo cliente na plataforma BoraHapp", creator="BoraHapp")
    frame = Frame(ML, MB, A4[0] - ML - MR, A4[1] - MT - MB, id="f", leftPadding=0, rightPadding=0,
                  topPadding=0, bottomPadding=0)
    doc.addPageTemplates([PageTemplate(id="p", frames=[frame], onPage=_pagina(total))])
    doc.build(conteudo())
    return doc.page


if __name__ == "__main__":
    paginas = montar(BytesIO(), "?")          # 1ª passada: conta as páginas
    montar(SAIDA, paginas)
    print(f"ok: {SAIDA} ({paginas} páginas)")
