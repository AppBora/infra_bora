// Alinha o catalogo de UMA loja da Zira ao cardapio de papel.
//
// Como usar: abra o painel ja logado na loja certa, aperte F12, cole isto no Console.
// Comeca em ENSAIO (APLICAR = false): a primeira colada so IMPRIME o que faria, nao grava nada.
// Conferido o plano, troque para true e cole de novo.
//
// Ele PARA sozinho se:
//   - a sessao nao estiver na loja de LOJA_ESPERADA (evita gravar na loja errada);
//   - a lista de produtos vier sem o campo `custo` (gravar sem custo apagaria o custo de todos).
//
// Ja rodou na loja 18 em 27/10/2026. As lojas 19 e 20 estavam com o catalogo de setembro,
// servindo cardapio publico com a Barca a R$ 39,00 em vez de R$ 47,90.

const LOJA_ESPERADA = 18;   // <<< TROQUE para a loja que voce quer alinhar
const APLICAR = false;      // <<< false = ensaio (nao grava). true = grava de verdade.

(async () => {
  const money = (v) => 'R$ ' + Number(v).toFixed(2).replace('.', ',');

  const PRECO_PRODUTO = {
    'Barca de Açaí Gourmet': 47.90, 'Titanic Tamanho Família': 66.90,
    'Roleta de Açaí Gourmet': 50.90, 'Copo de Açaí 300ml': 19.90,
    'Copo de Açaí 500ml': 24.90, 'Copo de Açaí 770ml': 28.90,
    'Pote de Açaí 1L': 35.90, 'Copo da Patroa 500ml': 31.90,
    'Copo do Patrão 700ml': 36.90, 'Leve 5 Pague 4 Açaí': 74.90,
    'Monte Seu Açaí': 0.00,
  };
  const PRECO_ADICIONAL = {
    'Banana': 3.00, 'Morango': 3.00, 'Calda de Chocolate': 3.00, 'Calda de Morango': 3.00,
    'Leite em Pó': 3.00, 'Sucrilhos': 3.00, 'Oreo': 3.50, 'Ovomaltine': 3.00,
    'Kit Kat': 4.00, 'Bis': 3.00, 'Chocoboll': 3.00, 'Ouro Branco': 3.00,
    'Sonho de Valsa': 3.00, 'Paçoquita': 3.00, 'Aveia': 3.00, 'Confete': 3.00,
    'Whey Protein': 7.00, 'Doce de Leite': 3.00, 'Pasta de Amendoim Integral': 3.50,
    'Creme de Avelã': 4.50, 'Creme de Leitinho': 4.50, 'Creme de Paçoca': 4.50,
  };
  const PRECO_RECIPIENTE = {
    'Copo 300ml Puro': 12.90, 'Copo 500ml Puro': 16.90,
    'Copo 700ml Puro': 19.90, 'Pote 1L Puro': 24.90,
  };
  const RENOMEAR_PRODUTO = { 'Copo do Patrão 700ml': 'Copo do Patrão 770ml' };
  const RENOMEAR_RECIPIENTE = { 'Copo 700ml Puro': 'Copo 770ml Puro' };
  const CRIAR_ADICIONAL = [{ grupo: 'Adicionais Extras', nome: 'Morango', preco: 3.00 }];
  const ESPECIAIS = [
    { atual: 'Ziraniho', nome: 'Ziraninho' },   // o nome estava escrito errado na base
    { atual: 'Ziraçoca', nome: 'Ziraçoca' },
    { atual: 'Ziratella', nome: 'Ziratella' },
  ];
  const TAMANHOS = [['300ml', 24.90], ['500ml', 29.90], ['770ml', 34.90]];
  // "Açaí Puro" e uma categoria do papel que existia so como RECIPIENTE dentro do "Monte Seu
  // Açaí" -- no balcao nao havia o que clicar. Cada um nasce com a foto do copo do mesmo tamanho.
  const ACAI_PURO = [
    ['Açaí Puro 300ml', 12.90, 'Copo de Açaí 300ml'],
    ['Açaí Puro 500ml', 16.90, 'Copo de Açaí 500ml'],
    ['Açaí Puro 770ml', 19.90, 'Copo de Açaí 770ml'],
    ['Açaí Puro 1 Litro', 24.90, 'Pote de Açaí 1L'],
  ];
  const GRATIS = '4 Adicionais Grátis';

  const user = Bora.user && Bora.user();
  if (!user) { console.error('Não achei a sessão. Faça login e tente de novo.'); return; }
  if (Number(user.lojaId) !== LOJA_ESPERADA) {
    console.error('PAREI: você está na loja ' + user.lojaId + ', e este script é da loja ' + LOJA_ESPERADA);
    return;
  }
  const produtos = await Bora.api('/api/produtos');
  if (produtos.length && !('custo' in produtos[0])) {
    console.error('PAREI: a lista veio SEM o campo de custo. Gravar assim apagaria o custo de todos.');
    return;
  }
  console.log('Loja ' + user.lojaId + ' · ' + (APLICAR ? 'APLICANDO DE VERDADE' : 'ENSAIO (nada será gravado)'));

  const porNome = {}; produtos.forEach(p => { porNome[p.nome] = p; });
  const feito = [], falhou = [], plano = [], foraDoPapel = {};

  const corpoDe = (p, m) => Object.assign({
    nome: p.nome, categoria: p.categoria, preco: Number(p.preco), custo: p.custo,
    estoqueMinimo: p.estoqueMinimo, ativo: p.ativo !== false, codigoExterno: p.codigoExterno || '',
  }, m);

  async function executar(rotulo, fn) {
    plano.push(rotulo);
    if (!APLICAR) return;
    try { await fn(); feito.push(rotulo); }
    catch (e) { falhou.push(rotulo + '  ->  ' + (e && e.message || e)); }
  }

  // A foto mora como data URL dentro da coluna; a lista devolve so um ENDERECO para ela.
  // Por isso copiar exige baixar a imagem e remontar o data URL -- devolver o endereco
  // substituiria a foto do lojista por um link apontando para si mesmo, e a perderia.
  async function fotoDe(p) {
    const r = await fetch(p.imagemUrl);
    const bytes = new Uint8Array(await r.arrayBuffer());
    let bin = ''; for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
    return 'data:' + (r.headers.get('content-type') || 'image/jpeg') + ';base64,' + btoa(bin);
  }

  // 1. precos dos produtos, e o Copo do Patrao que vira 770ml
  for (const [nome, novo] of Object.entries(PRECO_PRODUTO)) {
    const p = porNome[nome];
    if (!p) { falhou.push('produto do papel não existe nesta loja: ' + nome); continue; }
    const m = {};
    const precoMudou = Math.abs(Number(p.preco) - novo) >= 0.001;
    if (precoMudou) m.preco = novo;
    const nomeNovo = RENOMEAR_PRODUTO[nome];
    if (nomeNovo && p.nome !== nomeNovo) m.nome = nomeNovo;
    if (!Object.keys(m).length) continue;
    const rot = [m.nome ? 'renomear para ' + m.nome : null,
                 precoMudou ? money(p.preco) + ' -> ' + money(novo) : null].filter(Boolean).join(' · ');
    await executar('produto · ' + nome + ': ' + rot,
      () => Bora.api('/api/produtos/' + p.id, { method: 'PUT', body: JSON.stringify(corpoDe(p, m)) }));
  }

  // 2. adicionais e recipientes
  for (const p of produtos) {
    let grupos;
    try { grupos = await Bora.api('/api/produtos/' + p.id + '/complementos'); }
    catch (e) { falhou.push('não li os adicionais de ' + p.nome + ': ' + e.message); continue; }
    if (!grupos || !grupos.length) continue;
    const mudou = [];
    for (const g of grupos) {
      if (g.nome === GRATIS) continue;
      for (const i of (g.itens || [])) {
        // A ORDEM IMPORTA: buscar o preco pelo nome ORIGINAL antes de renomear. Renomear
        // primeiro fazia o "Copo 770ml Puro" nao ser achado na tabela e ficar em R$ 17,00.
        const nomeOriginal = i.nome;
        const alvo = g.nome === 'Recipientes' ? PRECO_RECIPIENTE[nomeOriginal] : PRECO_ADICIONAL[nomeOriginal];
        const renomeado = g.nome === 'Recipientes' ? RENOMEAR_RECIPIENTE[nomeOriginal] : null;
        if (renomeado && i.nome !== renomeado) { mudou.push(nomeOriginal + ' -> ' + renomeado); i.nome = renomeado; }
        if (alvo == null) { foraDoPapel[g.nome + ' · ' + nomeOriginal + ' ' + money(i.preco)] = true; continue; }
        if (Math.abs(Number(i.preco) - alvo) < 0.001) continue;
        mudou.push(i.nome + ' ' + money(i.preco) + '->' + money(alvo));
        i.preco = alvo;
      }
      for (const novo of CRIAR_ADICIONAL) {
        if (novo.grupo !== g.nome) continue;
        if ((g.itens || []).some(i => i.nome === novo.nome)) continue;
        (g.itens = g.itens || []).push({ nome: novo.nome, preco: novo.preco });
        mudou.push('CRIAR ' + novo.nome + ' ' + money(novo.preco));
      }
    }
    if (!mudou.length) continue;
    await executar('adicionais · ' + p.nome + ' (' + mudou.length + ')',
      () => Bora.api('/api/produtos/' + p.id + '/complementos', { method: 'PUT', body: JSON.stringify(grupos) }));
  }

  // 3. os especiais viram 3 tamanhos, e os novos herdam a foto do 300ml
  for (const esp of ESPECIAIS) {
    const p = porNome[esp.atual];
    if (!p) { falhou.push('especial não existe nesta loja: ' + esp.atual); continue; }
    let dataUrl = null;
    if (p.imagemUrl) { try { dataUrl = await fotoDe(p); } catch (e) { falhou.push('não li a foto de ' + esp.atual + ': ' + e.message); } }
    const nome300 = esp.nome + ' ' + TAMANHOS[0][0];
    await executar('renomear · ' + esp.atual + ' ' + money(p.preco) + ' -> ' + nome300 + ' ' + money(TAMANHOS[0][1]),
      () => Bora.api('/api/produtos/' + p.id, { method: 'PUT', body: JSON.stringify(corpoDe(p, { nome: nome300, preco: TAMANHOS[0][1] })) }));
    let modelo = [];
    try { modelo = await Bora.api('/api/produtos/' + p.id + '/complementos') || []; } catch (e) { }
    for (const [tam, preco] of TAMANHOS.slice(1)) {
      const nomeNovo = esp.nome + ' ' + tam;
      if (porNome[nomeNovo]) { plano.push('(já existe, pulei) ' + nomeNovo); continue; }
      await executar('criar · ' + nomeNovo + ' ' + money(preco) + ' + ' + modelo.length + ' grupo(s)' + (dataUrl ? ' + foto' : ' SEM FOTO'), async () => {
        const base = { nome: nomeNovo, categoria: p.categoria, preco, custo: p.custo,
                       estoqueMinimo: null, ativo: true, codigoExterno: '' };
        const criado = await Bora.api('/api/produtos', { method: 'POST', body: JSON.stringify(Object.assign({ estoque: null }, base)) });
        if (modelo.length) await Bora.api('/api/produtos/' + criado.id + '/complementos', { method: 'PUT', body: JSON.stringify(modelo) });
        // A foto vai num PUT separado: o POST de criacao nao carrega imagemUrl, entao todo
        // produto criado por script nasce cego se este passo nao existir.
        if (dataUrl) await Bora.api('/api/produtos/' + criado.id, { method: 'PUT', body: JSON.stringify(Object.assign({}, base, { imagemUrl: dataUrl })) });
      });
    }
  }

  // 4. a categoria "Açaí Puro" do papel
  const monte = porNome['Monte Seu Açaí'];
  let gruposPuro = [];
  if (monte) {
    try { gruposPuro = ((await Bora.api('/api/produtos/' + monte.id + '/complementos')) || []).filter(g => g.nome !== 'Recipientes'); }
    catch (e) { falhou.push('não li os grupos do Monte Seu Açaí: ' + e.message); }
  }
  for (const [nome, preco, fonteNome] of ACAI_PURO) {
    if (porNome[nome]) { plano.push('(já existe, pulei) ' + nome); continue; }
    const fonte = porNome[fonteNome];
    let dataUrl = null;
    if (fonte && fonte.imagemUrl) { try { dataUrl = await fotoDe(fonte); } catch (e) { falhou.push('não li a foto de ' + fonteNome + ': ' + e.message); } }
    await executar('criar · ' + nome + ' ' + money(preco) + ' + ' + gruposPuro.length + ' grupo(s)' + (dataUrl ? ' + foto de "' + fonteNome + '"' : ' SEM FOTO'), async () => {
      const base = { nome, categoria: 'Açaí Puro', preco, custo: null,
                     estoqueMinimo: null, ativo: true, codigoExterno: '' };
      const criado = await Bora.api('/api/produtos', { method: 'POST', body: JSON.stringify(Object.assign({ estoque: null }, base)) });
      if (gruposPuro.length) await Bora.api('/api/produtos/' + criado.id + '/complementos', { method: 'PUT', body: JSON.stringify(gruposPuro) });
      if (dataUrl) await Bora.api('/api/produtos/' + criado.id, { method: 'PUT', body: JSON.stringify(Object.assign({}, base, { imagemUrl: dataUrl })) });
    });
  }

  console.log('--- PLANO (' + plano.length + ') ---');
  plano.forEach(x => console.log('   ' + x));
  console.log('--- itens que a loja tem e o papel NÃO: deixados intactos de propósito ---');
  Object.keys(foraDoPapel).forEach(x => console.log('   ' + x));
  if (APLICAR) {
    console.log('APLICADAS COM SUCESSO: ' + feito.length);
    console.log('FALHARAM: ' + falhou.length);
    falhou.forEach(f => console.log('   x ' + f));
  } else {
    console.log('ENSAIO: nada foi gravado. Troque APLICAR para true e cole de novo.');
    if (falhou.length) { console.log('avisos:'); falhou.forEach(f => console.log('   ! ' + f)); }
  }
})();
