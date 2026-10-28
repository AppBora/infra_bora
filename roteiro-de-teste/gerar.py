# -*- coding: utf-8 -*-
"""Gera ROTEIRO-DE-TESTE.html: um arquivo so, sem internet, com check, observacao e exportacao."""
import io, json, os, sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from conteudo_a import PARTE_A  # noqa: E402
from conteudo_b import PARTE_B  # noqa: E402
from conteudo_c import PARTE_C  # noqa: E402

SECOES = PARTE_A + PARTE_B + PARTE_C

# ------------------------------------------------------------------ a conferencia, de novo
reais = set()
for linha in io.open(os.path.join(AQUI, 'endpoints.txt'), encoding='utf-8'):
    linha = linha.strip()
    if linha and not linha.startswith('###'):
        v, c = linha.split(None, 1)
        reais.add(v + ' ' + c)
reais.add('GET /')
cobertos = set()
ids = set()
for s in SECOES:
    for t in s['testes']:
        assert t['id'] not in ids, 'id repetido: ' + t['id']
        ids.add(t['id'])
        cobertos |= set(t.get('eps', []))
assert not (reais - cobertos), 'endpoint sem teste: %s' % sorted(reais - cobertos)
assert not (cobertos - reais), 'teste apontando para o vazio: %s' % sorted(cobertos - reais)

TOTAL_TESTES = len(ids)
TOTAL_REG = sum(1 for s in SECOES for t in s['testes'] if t.get('reg'))

CSS = r'''
:root{
  --marca:#7c3aed; --marca-fraca:#f3effd;
  --ok:#166534; --ok-bg:#dcfce7;
  --falha:#991b1b; --falha-bg:#fee2e2;
  --pulou:#92400e; --pulou-bg:#fef3c7;
  --bg:#faf9fb; --surf:#fff; --linha:#e7e3ec; --fg:#1d1824; --fg2:#6b6376; --fita:#5b21b6;
  --corpo:system-ui,-apple-system,"Segoe UI",Roboto,Arial,sans-serif;
  --mono:ui-monospace,SFMono-Regular,Consolas,"Liberation Mono",monospace;
  color-scheme:light;
}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){
  --marca:#b794f6; --marca-fraca:#2a2135; --ok:#6ee7a8; --ok-bg:#12301f;
  --falha:#fca5a5; --falha-bg:#3a1618; --pulou:#fcd34d; --pulou-bg:#352714;
  --bg:#141019; --surf:#1e1824; --linha:#342c3e; --fg:#f1ecf5; --fg2:#a99fb4; --fita:#c4b5fd;
  color-scheme:dark;
}}
*{box-sizing:border-box}
html,body{margin:0}
body{background:var(--bg);color:var(--fg);font-family:var(--corpo);line-height:1.55;font-size:15px}
.wrap{max-width:900px;margin:0 auto;padding:0 16px 72px}
h1,h2,h3{line-height:1.15;margin:0}
h1{font-size:clamp(25px,5vw,38px);font-weight:800;letter-spacing:-.02em}
h2{font-size:clamp(18px,3.2vw,24px);font-weight:700}
h3{font-size:15.5px;font-weight:700}
p{margin:.55em 0}
code{font-family:var(--mono);font-size:.88em;background:var(--marca-fraca);color:var(--fita);
  padding:1px 5px;border-radius:5px;overflow-wrap:anywhere}
header.capa{padding:34px 0 14px}
.selo{display:inline-block;font-family:var(--mono);font-size:11px;letter-spacing:.09em;
  text-transform:uppercase;color:var(--fita);background:var(--marca-fraca);
  padding:5px 11px;border-radius:999px;margin-bottom:12px}
.sub{color:var(--fg2);max-width:64ch}
.barra{position:sticky;top:0;z-index:20;background:var(--bg);border-bottom:1px solid var(--linha);
  padding:10px 0;margin-bottom:18px}
.barra-i{display:flex;flex-wrap:wrap;align-items:center;gap:8px}
.trilho{flex:1 1 160px;min-width:0;height:9px;border-radius:99px;background:var(--linha);overflow:hidden;display:flex}
.trilho i{display:block;height:100%;transition:width .2s ease}
.t-ok{background:var(--ok)}.t-falha{background:var(--falha)}.t-pulou{background:var(--pulou)}
.contagem{font-family:var(--mono);font-size:12.5px;color:var(--fg2);font-variant-numeric:tabular-nums;white-space:nowrap}
.contagem b{color:var(--fg)}
.fbt,.lbt{border:1px solid var(--linha);background:var(--surf);color:var(--fg2);
  font:600 12.5px var(--corpo);padding:6px 11px;border-radius:999px;cursor:pointer;min-height:33px}
.lbt{border-radius:8px}
.fbt[aria-pressed="true"]{background:var(--marca);border-color:var(--marca);color:#fff}
.lbt.forte{background:var(--marca);border-color:var(--marca);color:#fff}
.fbt:focus-visible,.lbt:focus-visible,.est:focus-visible{outline:2px solid var(--marca);outline-offset:2px}
.recado{font-size:13px;color:var(--fg2);margin-top:7px;min-height:1.3em}
section.bloco{margin-top:26px;scroll-margin-top:92px}
.cab{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;margin-bottom:2px}
.num{font-family:var(--mono);font-size:11.5px;color:var(--fita);background:var(--marca-fraca);
  padding:2px 8px;border-radius:6px;flex:0 0 auto}
.tela{font-family:var(--mono);font-size:11.5px;color:var(--fg2)}
.resumo-sec{font-size:13.5px;color:var(--fg2);margin:3px 0 11px}
.teste{background:var(--surf);border:1px solid var(--linha);border-radius:12px;padding:13px 14px;margin-bottom:9px}
.teste[data-estado="ok"]{border-color:var(--ok);background:var(--ok-bg)}
.teste[data-estado="falha"]{border-color:var(--falha);background:var(--falha-bg)}
.teste[data-estado="pulou"]{border-color:var(--pulou);background:var(--pulou-bg)}
.teste-topo{display:flex;gap:10px;align-items:flex-start}
.teste-txt{flex:1;min-width:0}
.passo{font-size:14px;margin:.4em 0}
.comotestar{font-size:13px;font-weight:600;margin:.5em 0 .25em;color:var(--fg2)}
.passos{font-size:14px;margin:.2em 0 .5em;padding-left:22px}
.passos li{margin:.18em 0}
.espera{font-size:14px;margin:.4em 0;padding-left:11px;border-left:3px solid var(--marca)}
.sefalha{font-size:13px;color:var(--fg2);margin:.4em 0 0}
.estados{display:flex;gap:4px;flex:0 0 auto}
.est{width:34px;height:34px;border-radius:9px;border:1px solid var(--linha);background:var(--bg);
  cursor:pointer;font-size:15px;display:grid;place-items:center;color:var(--fg2)}
.est[aria-pressed="true"]{color:#fff}
.est.e-ok[aria-pressed="true"]{background:var(--ok);border-color:var(--ok)}
.est.e-falha[aria-pressed="true"]{background:var(--falha);border-color:var(--falha)}
.est.e-pulou[aria-pressed="true"]{background:var(--pulou);border-color:var(--pulou)}
.nota{width:100%;margin-top:9px;font:inherit;font-size:13.5px;padding:8px 10px;border-radius:9px;
  border:1px solid var(--linha);background:var(--bg);color:var(--fg);resize:vertical;min-height:40px}
.teste[data-estado=""] .nota{display:none}
.caixa{border:1px solid var(--linha);border-left:4px solid var(--marca);background:var(--surf);
  border-radius:10px;padding:13px 15px;margin:15px 0}
.caixa.perigo{border-left-color:var(--falha)}
.caixa h3{margin-bottom:5px}
.caixa ul{margin:.4em 0;padding-left:20px}
.caixa li{margin:.3em 0;font-size:14.5px}
.indice{display:grid;grid-template-columns:repeat(auto-fill,minmax(215px,1fr));gap:7px;margin:14px 0 4px}
.indice a{display:flex;gap:8px;align-items:baseline;text-decoration:none;color:var(--fg);
  border:1px solid var(--linha);background:var(--surf);border-radius:9px;padding:8px 10px;font-size:13.5px}
.indice a:hover{border-color:var(--marca)}
.indice span{font-family:var(--mono);font-size:11px;color:var(--fita);flex:0 0 auto}
.geral{width:100%;font:inherit;font-size:14px;padding:11px;border-radius:10px;border:1px solid var(--linha);
  background:var(--surf);color:var(--fg);resize:vertical;min-height:90px;margin-top:6px}
.pe{margin-top:36px;padding-top:18px;border-top:1px solid var(--linha);color:var(--fg2);font-size:13px}
@media (max-width:560px){.estados{flex-direction:column}}
@media print{.barra,.estados,.indice,.lbt,.fbt{display:none}.teste{break-inside:avoid}.nota{display:block!important}}
'''

CABECA = u'''<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Roteiro de Teste do BoraHapp</title>
<style>%s</style>
</head>
<body>
<div class="wrap">
  <header class="capa">
    <div class="selo">Roteiro completo &middot; v154 &middot; 28/10/2026</div>
    <h1>Roteiro de Teste do BoraHapp</h1>
    <p class="sub">A aplica&ccedil;&atilde;o inteira, item por item: <b>%d testes</b> em %d se&ccedil;&otilde;es, cobrindo
      <b>as 35 telas</b> e <b>os %d endpoints</b> que o sistema tem. No fim, os testes que cruzam
      funcionalidades. Marque conforme testar, escreva o que aconteceu e clique em
      <b>Baixar resultado</b> &mdash; me mande o arquivo que eu leio e ajo nas observa&ccedil;&otilde;es.</p>
  </header>

  <div class="barra">
    <div class="barra-i">
      <div class="trilho" role="img" aria-label="progresso">
        <i class="t-ok" id="bOk" style="width:0%%"></i>
        <i class="t-falha" id="bFalha" style="width:0%%"></i>
        <i class="t-pulou" id="bPulou" style="width:0%%"></i>
      </div>
      <div class="contagem" id="contagem">&mdash;</div>
      <button class="fbt" id="fTodos" aria-pressed="true">Todos</button>
      <button class="fbt" id="fFalta" aria-pressed="false">N&atilde;o testados</button>
      <button class="fbt" id="fFalha" aria-pressed="false">Falhou</button>
      <button class="fbt" id="fReg" aria-pressed="false">S&oacute; regress&atilde;o</button>
      <button class="lbt forte" id="btBaixar">Baixar resultado</button>
      <button class="lbt" id="btCarregar">Carregar</button>
      <button class="lbt" id="btLimpar">Limpar</button>
      <input type="file" id="arq" accept=".md,.json,.txt" hidden>
    </div>
    <div class="recado" id="recado"></div>
  </div>

  <div class="caixa">
    <h3>Como usar</h3>
    <ul>
      <li>Marque <b>&#10003;</b> passou, <b>&#10005;</b> falhou, <b>&mdash;</b> pulou. Ao marcar, abre a
        caixa de observa&ccedil;&atilde;o do item.</li>
      <li>O que voc&ecirc; escrever fica guardado <b>neste navegador, neste computador</b>. Pode fechar e voltar.</li>
      <li>No fim, <b>Baixar resultado</b> gera um <code>.md</code> na sua pasta de Downloads.
        <b>Me mande esse arquivo</b> &mdash; eu leio e ajo.</li>
      <li><b>Carregar</b> abre de volta um resultado baixado antes, para continuar ou testar noutro computador.</li>
      <li><b>%d testes s&atilde;o de regress&atilde;o</b>: cobrem defeitos que j&aacute; aconteceram de verdade. Cada um diz
        <i>por que importa</i>. S&atilde;o os que t&ecirc;m mais chance de voltar &mdash; o filtro separa s&oacute; eles.</li>
    </ul>
  </div>

  <div class="caixa">
    <h3>Antes de come&ccedil;ar</h3>
    <ul>
      <li><b>Uma loja de teste</b>, n&atilde;o a de um cliente. V&aacute;rios testes criam pedido, mexem em estoque
        e disparam aviso para cliente.</li>
      <li><b>Quatro contas</b>, uma por papel: <code>ADMINISTRADOR_BORA</code>,
        <code>ADMINISTRADOR_LOJA</code>, <code>GERENTE</code>, <code>OPERADOR</code>. Boa parte dos
        testes &eacute; sobre quem <i>n&atilde;o</i> pode ver ou fazer.</li>
      <li><b>Um celular de verdade</b> para a se&ccedil;&atilde;o 32.</li>
      <li><b>Duas abas</b> para a se&ccedil;&atilde;o I-E (duas pessoas ao mesmo tempo).</li>
      <li>Uma <b>ferramenta de requisi&ccedil;&atilde;o</b> (Postman, curl ou as ferramentas do navegador) para a
        se&ccedil;&atilde;o 30, que &eacute; o que chega de fora sem ningu&eacute;m clicar.</li>
    </ul>
  </div>

  <div class="caixa perigo">
    <h3>N&atilde;o fa&ccedil;a em loja de cliente</h3>
    <p>Despachar pedido e mudar status <b>avisam o cliente final no WhatsApp</b>. Cancelar devolve
      estoque e cashback. Excluir pedido devolve dinheiro. Em loja de verdade, isso fala com gente de
      fora e mexe em dinheiro.</p>
  </div>

  <nav class="indice" id="indice" aria-label="Se&ccedil;&otilde;es"></nav>
  <div id="conteudo"></div>

  <section class="bloco">
    <div class="cab"><span class="num">fim</span><h2>Observa&ccedil;&otilde;es gerais</h2></div>
    <p class="resumo-sec">O que n&atilde;o coube em nenhum item: impress&atilde;o geral, coisa que incomodou,
      ideia que surgiu testando.</p>
    <textarea class="geral" id="geral" placeholder="Escreva aqui"></textarea>
  </section>

  <footer class="pe">
    <p>Gerado a partir do invent&aacute;rio real do sistema em 28/10/2026, n&atilde;o de mem&oacute;ria: <b>35 telas</b> e
      <b>%d endpoints</b> levantados do c&oacute;digo. Um verificador confere que <b>todo endpoint aparece em
      pelo menos um teste</b> e que nenhum teste aponta para endpoint que n&atilde;o existe &mdash; por isso a
      cobertura &eacute; completa por constru&ccedil;&atilde;o, e n&atilde;o por julgamento.</p>
  </footer>
</div>
<script>
const SECOES = %s;
''' % (CSS, TOTAL_TESTES, len(SECOES), len(reais), TOTAL_REG, len(reais),
       json.dumps(SECOES, ensure_ascii=False))

CORPO = r'''
const CHAVE = 'bora-roteiro-completo-v1';
let estados = {}, geral = '';
try {
  const g = JSON.parse(localStorage.getItem(CHAVE) || '{}') || {};
  estados = g.estados || {}; geral = g.geral || '';
} catch (e) { estados = {}; geral = ''; }
function guardar(){ try { localStorage.setItem(CHAVE, JSON.stringify({estados:estados, geral:geral})); } catch (e) {} }
function recado(t){
  const el = document.getElementById('recado');
  el.textContent = t || '';
  if (t) setTimeout(function(){ if (el.textContent === t) el.textContent = ''; }, 7000);
}
const esc = s => String(s == null ? '' : s);
let filtro = 'todos';

function totais(){
  let t=0, ok=0, falha=0, pulou=0;
  for (const s of SECOES) for (const x of s.testes) {
    t++;
    const e = (estados[x.id]||{}).estado;
    if (e==='ok') ok++; else if (e==='falha') falha++; else if (e==='pulou') pulou++;
  }
  return {t:t, ok:ok, falha:falha, pulou:pulou};
}
function pintar(){
  const r = totais();
  document.getElementById('bOk').style.width = (r.ok/r.t*100)+'%';
  document.getElementById('bFalha').style.width = (r.falha/r.t*100)+'%';
  document.getElementById('bPulou').style.width = (r.pulou/r.t*100)+'%';
  document.getElementById('contagem').innerHTML =
    '<b>'+(r.ok+r.falha+r.pulou)+'</b> de '+r.t+' &middot; '+r.ok+' ok &middot; '+r.falha+' falhou &middot; '+r.pulou+' pulou';
}
function visivel(x){
  const e = (estados[x.id]||{}).estado || '';
  if (filtro==='falta') return e==='';
  if (filtro==='falha') return e==='falha';
  if (filtro==='reg') return !!x.reg;
  return true;
}
function aplicar(){
  for (const s of SECOES) {
    let algum = false;
    for (const x of s.testes) {
      const el = document.getElementById('t_'+x.id);
      if (!el) continue;
      const v = visivel(x);
      el.hidden = !v;
      if (v) algum = true;
    }
    const sec = document.getElementById('s_'+s.n);
    if (sec) sec.hidden = !algum;
  }
}
function marcar(id, valor){
  const atual = (estados[id]||{}).estado || '';
  const novo = atual===valor ? '' : valor;
  estados[id] = Object.assign({}, estados[id], {estado:novo});
  const el = document.getElementById('t_'+id);
  el.dataset.estado = novo;
  const bs = el.querySelectorAll('.est');
  for (let i=0;i<bs.length;i++) bs[i].setAttribute('aria-pressed', String(bs[i].dataset.valor===novo));
  if (novo) { const n = document.getElementById('n_'+id); if (n) n.focus(); }
  guardar(); pintar(); aplicar();
}
function montar(){
  let hi='', hc='';
  for (const s of SECOES) {
    hi += '<a href="#s_'+s.n+'"><span>'+esc(s.n)+'</span>'+esc(s.t)+'</a>';
    hc += '<section class="bloco" id="s_'+s.n+'">'
       + '<div class="cab"><span class="num">'+esc(s.n)+'</span><h2>'+esc(s.t)+'</h2>'
       + (s.tela ? '<span class="tela">'+esc(s.tela)+'</span>' : '') + '</div>'
       + '<p class="resumo-sec">'+esc(s.r)+'</p>';
    for (const x of s.testes) {
      const e = (estados[x.id]||{}).estado || '';
      const nota = (estados[x.id]||{}).nota || '';
      hc += '<article class="teste" id="t_'+x.id+'" data-estado="'+e+'">'
        + '<div class="teste-topo"><div class="teste-txt">'
        + '<h3>'+esc(x.id)+' &middot; '+esc(x.t)+(x.reg?' <span class="num">regressão</span>':'')+'</h3>'
        + '<p class="comotestar">Como testar</p>'
        + '<ol class="passos">'+x.passos.map(function(q){return '<li>'+q+'</li>';}).join('')+'</ol>'
        + '<p class="espera"><b>Tem que acontecer:</b> '+x.e+'</p>'
        + (x.f ? '<p class="sefalha"><b>Por que isso importa:</b> '+x.f+'</p>' : '')
        + '</div><div class="estados">'
        + '<button class="est e-ok" data-id="'+x.id+'" data-valor="ok" aria-pressed="'+(e==='ok')+'" aria-label="Passou" title="passou">&#10003;</button>'
        + '<button class="est e-falha" data-id="'+x.id+'" data-valor="falha" aria-pressed="'+(e==='falha')+'" aria-label="Falhou" title="falhou">&#10005;</button>'
        + '<button class="est e-pulou" data-id="'+x.id+'" data-valor="pulou" aria-pressed="'+(e==='pulou')+'" aria-label="Pulou" title="pulou">&mdash;</button>'
        + '</div></div>'
        + '<textarea class="nota" id="n_'+x.id+'" placeholder="O que aconteceu? Quanto mais detalhe, melhor eu ajo nisso.">'+esc(nota)+'</textarea>'
        + '</article>';
    }
    hc += '</section>';
  }
  document.getElementById('indice').innerHTML = hi;
  document.getElementById('conteudo').innerHTML = hc;
  document.getElementById('geral').value = geral;
  pintar(); aplicar();
}
document.getElementById('conteudo').addEventListener('click', function(ev){
  const b = ev.target.closest ? ev.target.closest('.est') : null;
  if (b) marcar(b.dataset.id, b.dataset.valor);
});
document.getElementById('conteudo').addEventListener('input', function(ev){
  if (!ev.target.classList.contains('nota')) return;
  const id = ev.target.id.slice(2);
  estados[id] = Object.assign({}, estados[id], {nota: ev.target.value});
  guardar();
});
document.getElementById('geral').addEventListener('input', function(ev){ geral = ev.target.value; guardar(); });

const BOTOES = [['fTodos','todos'],['fFalta','falta'],['fFalha','falha'],['fReg','reg']];
for (const par of BOTOES) {
  document.getElementById(par[0]).addEventListener('click', function(){
    filtro = par[1];
    for (const o of BOTOES) document.getElementById(o[0]).setAttribute('aria-pressed', String(o[0]===par[0]));
    aplicar();
  });
}

const ROTULO = {ok:'PASSOU', falha:'FALHOU', pulou:'pulou', '':'nao testado'};
function gerarTexto(){
  const r = totais(), d = new Date();
  const dd = String(d.getDate()).padStart(2,'0')+'/'+String(d.getMonth()+1).padStart(2,'0')+'/'+d.getFullYear()
           +' '+String(d.getHours()).padStart(2,'0')+':'+String(d.getMinutes()).padStart(2,'0');
  const L = [];
  L.push('# Resultado do roteiro de teste do BoraHapp');
  L.push('');
  L.push('Preenchido em ' + dd + '.');
  L.push('');
  L.push('- Passou: **'+r.ok+'**');
  L.push('- Falhou: **'+r.falha+'**');
  L.push('- Pulou: '+r.pulou);
  L.push('- Nao testado: '+(r.t-r.ok-r.falha-r.pulou));
  L.push('- Total: '+r.t);
  L.push('');
  if (r.falha) {
    L.push('## O que falhou'); L.push('');
    for (const s of SECOES) {
      const ruins = s.testes.filter(function(x){ return ((estados[x.id]||{}).estado)==='falha'; });
      if (!ruins.length) continue;
      L.push('### '+s.n+'. '+s.t+(s.tela?'  ('+s.tela+')':'')); L.push('');
      for (const x of ruins) {
        L.push('- **'+x.id+' '+x.t+'**'+(x.reg?' [regressao]':''));
        L.push('  - Como testar:');
        x.passos.forEach(function(q,i){ L.push('    '+(i+1)+'. '+q.replace(/<[^>]*>/g,'')); });
        L.push('  - Tem que acontecer: '+x.e.replace(/<[^>]*>/g,''));
        const nota = ((estados[x.id]||{}).nota||'').trim();
        L.push('  - **O que aconteceu: '+(nota||'(sem observacao)')+'**');
      }
      L.push('');
    }
  }
  const comNota = [];
  for (const s of SECOES) for (const x of s.testes) {
    const st = estados[x.id]||{};
    if ((st.nota||'').trim() && st.estado!=='falha') comNota.push([x, st]);
  }
  if (comNota.length) {
    L.push('## Observacoes em itens que nao falharam'); L.push('');
    for (const p of comNota) {
      L.push('- **'+p[0].id+' '+p[0].t+'** ('+ROTULO[p[1].estado||'']+')');
      L.push('  - '+p[1].nota.trim());
    }
    L.push('');
  }
  if ((geral||'').trim()) { L.push('## Observacoes gerais'); L.push(''); L.push(geral.trim()); L.push(''); }
  L.push('## Tudo, item por item'); L.push('');
  for (const s of SECOES) {
    L.push('### '+s.n+'. '+s.t); L.push('');
    for (const x of s.testes) {
      const st = estados[x.id]||{};
      const m = st.estado==='ok'?'[x]':st.estado==='falha'?'[!]':st.estado==='pulou'?'[-]':'[ ]';
      L.push('- '+m+' '+x.id+' '+x.t+((st.nota||'').trim()?' — '+st.nota.trim():''));
    }
    L.push('');
  }
  L.push('<!-- BORA-ROTEIRO-JSON');
  L.push(JSON.stringify({estados:estados, geral:geral}));
  L.push('-->');
  return L.join('\n');
}
document.getElementById('btBaixar').addEventListener('click', function(){
  const txt = gerarTexto(), d = new Date();
  const nome = 'roteiro-bora-'+d.getFullYear()+String(d.getMonth()+1).padStart(2,'0')
    +String(d.getDate()).padStart(2,'0')+'-'+String(d.getHours()).padStart(2,'0')
    +String(d.getMinutes()).padStart(2,'0')+'.md';
  try {
    const blob = new Blob([txt], {type:'text/markdown;charset=utf-8'});
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob); a.download = nome;
    document.body.appendChild(a); a.click();
    setTimeout(function(){ URL.revokeObjectURL(a.href); a.remove(); }, 1000);
    recado('Baixei ' + nome + ' na sua pasta de Downloads. Me mande esse arquivo.');
  } catch (e) {
    recado('Nao consegui baixar. Abri o texto para voce copiar.');
    const ta = document.createElement('textarea');
    ta.value = txt;
    ta.style.cssText = 'position:fixed;left:12px;top:12px;width:calc(100% - 24px);height:70vh;z-index:99;font-family:monospace;font-size:12px';
    document.body.appendChild(ta); ta.select();
    ta.addEventListener('blur', function(){ ta.remove(); }, {once:true});
  }
});
document.getElementById('btCarregar').addEventListener('click', function(){ document.getElementById('arq').click(); });
document.getElementById('arq').addEventListener('change', function(ev){
  const f = ev.target.files && ev.target.files[0];
  if (!f) return;
  const leitor = new FileReader();
  leitor.onload = function(){
    try {
      const txt = String(leitor.result);
      const i = txt.indexOf('<!-- BORA-ROTEIRO-JSON');
      const cru = i>=0 ? txt.slice(txt.indexOf('\n', i)+1, txt.lastIndexOf('-->')).trim() : txt.trim();
      const dados = JSON.parse(cru);
      estados = dados.estados || {}; geral = dados.geral || '';
      guardar(); montar(); recado('Carregado de ' + f.name + '.');
    } catch (e) { recado('Nao consegui ler esse arquivo. Use um .md baixado por este roteiro.'); }
  };
  leitor.readAsText(f);
  ev.target.value = '';
});
let confirmando = false;
document.getElementById('btLimpar').addEventListener('click', function(ev){
  const btn = ev.currentTarget;
  if (!confirmando) {
    confirmando = true; btn.textContent = 'Apagar tudo?';
    recado('Clique de novo para apagar tudo. Baixe antes, se quiser guardar.');
    setTimeout(function(){ if (confirmando) { confirmando = false; btn.textContent = 'Limpar'; } }, 5000);
    return;
  }
  confirmando = false; btn.textContent = 'Limpar';
  estados = {}; geral = '';
  guardar(); montar(); recado('Limpo.');
});
montar();
</script>
</body>
</html>
'''

saida = os.path.join(AQUI, '..', 'ROTEIRO-DE-TESTE.html')
io.open(saida, 'w', encoding='utf-8', newline='\n').write(CABECA + CORPO)
print('ok: %s (%.0f KB)' % (saida, os.path.getsize(saida) / 1024))
print('   %d testes, %d secoes, %d endpoints cobertos, %d de regressao'
      % (TOTAL_TESTES, len(SECOES), len(reais), TOTAL_REG))
