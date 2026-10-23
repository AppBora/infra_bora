# -*- coding: utf-8 -*-
"""Confere que TODO endpoint da aplicacao aparece em pelo menos um teste.
E o contrario tambem: que nenhum teste aponta para endpoint que nao existe."""
import io, os, sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from conteudo_a import PARTE_A  # noqa: E402
from conteudo_b import PARTE_B  # noqa: E402
from conteudo_c import PARTE_C  # noqa: E402

SECOES = PARTE_A + PARTE_B + PARTE_C

# ---- o que a aplicacao TEM (levantado do codigo, nao da minha cabeca)
reais = set()
for linha in io.open(os.path.join(AQUI, 'endpoints.txt'), encoding='utf-8'):
    linha = linha.strip()
    if not linha or linha.startswith('###'):
        continue
    verbo, caminho = linha.split(None, 1)
    reais.add(verbo + ' ' + caminho)
reais.add('GET /')  # a pagina inicial, servida pelo Caddy

# ---- o que o roteiro COBRE
cobertos = {}
ids = set()
for s in SECOES:
    for t in s['testes']:
        assert t['id'] not in ids, 'id repetido: ' + t['id']
        ids.add(t['id'])
        for ep in t.get('eps', []):
            cobertos.setdefault(ep, []).append(t['id'])

faltando = sorted(reais - set(cobertos))
inventados = sorted(set(cobertos) - reais)

print('endpoints da aplicacao: %d' % len(reais))
print('endpoints cobertos....: %d' % len(reais - set(faltando)))
print('testes................: %d em %d secoes' % (len(ids), len(SECOES)))
print('regressao.............: %d' % sum(1 for s in SECOES for t in s['testes'] if t.get('reg')))
if faltando:
    print('\nSEM TESTE NENHUM (%d):' % len(faltando))
    for e in faltando:
        print('  ' + e)
if inventados:
    print('\nAPONTAM PARA ENDPOINT QUE NAO EXISTE (%d):' % len(inventados))
    for e in inventados:
        print('  ' + e + '  <- ' + ', '.join(cobertos[e]))
if not faltando and not inventados:
    print('\nCOBERTURA COMPLETA: todo endpoint tem ao menos um teste, e nenhum teste aponta para o vazio.')
