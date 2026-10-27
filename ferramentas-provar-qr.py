# -*- coding: utf-8 -*-
"""
PROVA do gerador de QR (assets/js/qr.js): gera, renderiza e LE de volta.

Por que o juiz e um leitor, e nao outro gerador:
  - O api.qrserver.com usa mascara 2 em TODOS os casos -- nao faz a escolha por penalidade que a
    norma manda. Dois simbolos diferentes podem estar os dois certos.
  - O codificador do OpenCV escolhe sempre uma versao acima da minima, entao tambem nao serve
    para comparar modulo a modulo.
O que decide e se a camera le o texto certo.

Dois leitores, de propriedade diferente:
  - zbar (pyzbar): o decodificador de referencia, usado em produto de verdade ha 20 anos.
  - OpenCV QRCodeDetector: segunda opiniao.
Medido: o OpenCV NAO detecta alguns simbolos de mascara 2 que o zbar le sem reclamar. E limitacao
do detector dele, nao do simbolo -- por isso o zbar manda, e a divergencia e so reportada.

Precisa de internet so para instalar; depois roda offline. Nao entra na suite porque depende de
pacotes Python que a suite (Node puro) nao tem.
"""
import io
import json
import os
import random
import string
import subprocess
import sys

import cv2
import numpy as np
from PIL import Image
from pyzbar.pyzbar import decode as zbar_decode

FRONT = r'C:\Users\user\OneDrive\Desktop\Bora\bora-fase-2-frontend'
QRJS = io.open(os.path.join(FRONT, 'assets', 'js', 'qr.js'), encoding='utf-8').read()


def matrizes(textos):
    """Gera todas de uma vez: um processo node por texto custaria minutos."""
    js = QRJS + '\nconst T=' + json.dumps(textos) + ';' \
        + 'process.stdout.write(JSON.stringify(T.map(t=>globalThis.BoraQR.matriz(t))));'
    # O Windows limita o tamanho da linha de comando, e o corpus estoura: vai por arquivo.
    tmp = os.path.join(os.path.dirname(os.path.abspath(__file__)), '_gerar.mjs')
    io.open(tmp, 'w', encoding='utf-8').write(js)
    r = subprocess.run(['node', tmp], capture_output=True, text=True)
    os.remove(tmp)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip()[:400])
    return json.loads(r.stdout)


def imagem(m, escala=8, margem=4):
    n = len(m)
    lado = (n + margem * 2) * escala
    img = np.full((lado, lado), 255, dtype=np.uint8)
    for r in range(n):
        for c in range(n):
            if m[r][c]:
                img[(r + margem) * escala:(r + margem + 1) * escala,
                    (c + margem) * escala:(c + margem + 1) * escala] = 0
    return img


def corpus():
    t = [
        'https://borahapp.com.br/cardapio.html?loja=18',
        'https://borahapp.com.br/cardapio.html?loja=1',
        'https://borahapp.com.br/cardapio-folha.html?loja=18',
        'https://borahapp.com.br/cardapio.html?loja=17&wa=5511999998888',
        'https://borahapp.com.br/acompanhar.html?loja=18&pedido=1234&t=abcdef0123456789',
        'https://borahapp.com.br/cardapio.html?loja=999999&wa=5511988887777&origem=mesa-12',
        'Zirá Açaíteria — Açaí, Crepe e Sorvete',
        'Pizzaria Bella Napoli · R$ 52,90',
        'a', 'BORA', '0', ' ', '?&=#%+',
    ]
    # todos os tamanhos ate a versao 20, para pegar as viradas de versao
    t += ['A' * n for n in range(1, 420, 3)]
    # conteudo aleatorio, que e onde mascara ruim aparece
    rnd = random.Random(42)
    alfabeto = string.ascii_letters + string.digits + ':/?&=._-#%+ '
    for _ in range(120):
        n = rnd.randint(1, 300)
        t.append(''.join(rnd.choice(alfabeto) for _ in range(n)))
    # links reais com parametros variados
    for loja in (1, 17, 18, 23, 999):
        for wa in ('', '&wa=5511988887777'):
            t.append('https://borahapp.com.br/cardapio.html?loja=%d%s' % (loja, wa))
    return t


def main():
    textos = corpus()
    print('gerando %d codigos...' % len(textos))
    ms = matrizes(textos)

    cvl = cv2.QRCodeDetector()
    ok_z = ok_cv = 0
    falhas_z, so_cv = [], []
    versoes = {}

    for t, m in zip(textos, ms):
        v = (len(m) - 17) // 4
        versoes[v] = versoes.get(v, 0) + 1
        img = imagem(m)

        z = zbar_decode(Image.fromarray(img))
        lido_z = z[0].data.decode('utf-8') if z else ''
        if lido_z == t:
            ok_z += 1
        else:
            falhas_z.append((t[:60], lido_z[:40]))

        lido_cv, _, _ = cvl.detectAndDecode(img)
        if lido_cv == t:
            ok_cv += 1
        elif lido_z == t:
            so_cv.append(t[:60])

    print()
    print('zbar   leu certo: %d de %d' % (ok_z, len(textos)))
    print('opencv leu certo: %d de %d' % (ok_cv, len(textos)))
    print('versoes usadas  :', dict(sorted(versoes.items())))
    if falhas_z:
        print('\nFALHAS DE VERDADE (zbar nao leu):')
        for f in falhas_z[:12]:
            print('  ', f)
    if so_cv:
        print('\nlidos pelo zbar e NAO pelo opencv: %d (limitacao do detector do opencv)' % len(so_cv))
        for s in so_cv[:4]:
            print('  ', s)
    return 0 if not falhas_z else 1


if __name__ == '__main__':
    sys.exit(main())
