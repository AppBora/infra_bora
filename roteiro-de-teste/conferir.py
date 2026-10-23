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
# ---- endpoint que EXISTE e nenhuma tela chama
# O conferidor provava que todo endpoint tem TESTE. Nao provava que alguem consegue USAR.
# Sete itens do roteiro ganharam passos impossiveis por isso: o endpoint existia, o teste existia,
# e nao havia botao em tela nenhuma. Quem seguisse o passo a passo nao achava o que clicar.
FRONT = os.path.join(AQUI, '..', 'bora-fase-2-frontend')
chamados = ''
if os.path.isdir(FRONT):
    for base, _, arquivos in os.walk(FRONT):
        if 'testes' in base or (os.sep + 'dev') in base or 'node_modules' in base:
            continue
        for nome in arquivos:
            # O proprio ROTEIRO-DE-TESTE.html mora aqui e cita TODOS os endpoints: deixa-lo
            # entrar fazia a conferencia achar que tudo tem tela.
            if nome == 'ROTEIRO-DE-TESTE.html':
                continue
            if nome.endswith(('.js', '.html')) and '.antes-' not in nome:
                try:
                    chamados += io.open(os.path.join(base, nome), encoding='utf-8', errors='ignore').read()
                except OSError:
                    pass


# Nao sao chamados por tela POR DEFINICAO: entram de fora (webhook), sao de monitoramento,
# ou a pagina e servida pelo Caddy. Cobrar tela deles seria ruido.
DE_FORA = ('/public/asaas-webhook', '/public/pix-webhook', '/public/opendelivery',
           '/public/whatsapp-webhook', '/webhooks/', '/api/health', '/actuator/')


def alcancavel(ep):
    caminho = ep.split(None, 1)[1]
    if caminho == '/' or any(caminho.startswith(x) for x in DE_FORA):
        return True
    # Casar so o prefixo nao serve: '/api/integracoes/{canal}/diagnostico' passaria por causa de
    # qualquer outra chamada a '/api/integracoes'. O que identifica a rota e o ULTIMO pedaco fixo.
    fixos = [p for p in caminho.split('/') if p and not p.startswith('{')]
    if not fixos:
        return True
    return fixos[-1] in chamados


sem_tela = sorted(e for e in reais if not alcancavel(e)) if chamados else []
if sem_tela:
    print('')
    print('EXISTEM NO SERVIDOR E NENHUMA TELA CHAMA (%d):' % len(sem_tela))
    for e in sem_tela:
        print('  ' + e + '  <- testado por ' + ', '.join(cobertos.get(e, ['(ninguem)'])))
    print('  (nao e defeito de codigo: e funcao pronta que o lojista nao alcanca)')

if not faltando and not inventados:
    print('\nCOBERTURA COMPLETA: todo endpoint tem ao menos um teste, e nenhum teste aponta para o vazio.')
