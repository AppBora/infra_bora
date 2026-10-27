/* ===========================================================================================
   ATUALIZAÇÃO DE PREÇOS DA ZIRÁ — cardápio de 23/10/2026
   ===========================================================================================

   COMO USAR
   1. Entre em borahapp.com.br com a sua conta e ENTRE NA LOJA DA ZIRÁ (loja 18).
      Confira no topo da tela que o nome é "Zirá Açaíteria" antes de continuar.
   2. Abra qualquer tela do painel (Produtos serve), aperte F12 → aba Console.
   3. Cole este arquivo inteiro e aperte Enter.
      Na primeira vez ele NÃO MUDA NADA: só imprime o que faria.
   4. Leia a lista. Se estiver certa, mude a linha `const APLICAR = false` para `true`,
      cole de novo e aperte Enter.

   POR QUE UM SCRIPT, E NÃO NA MÃO
   São 329 mudanças de adicional em 16 produtos, mais 10 preços e 6 produtos novos. O grupo de
   adicionais é COPIADO dentro de cada produto -- não é um só compartilhado -- então trocar
   "Kit Kat 2,50 → 4,00" são 15 edições, uma por produto. Na tela, isso é meio dia de cliques e
   erro garantido em algum lugar.

   O QUE ELE NÃO FAZ, DE PROPÓSITO
   - Não manda `imagemUrl`: o servidor grava esse campo quando ele vem, e mandar o ENDEREÇO da
     foto de volta apagaria a foto de verdade (ProdutoService.java:82).
   - Não manda `estoque` na edição: o servidor ignora de propósito, e mandar o número que a tela
     carregou apagaria o consumo do dia. Produto novo nasce sem controle de estoque.
   - Não mexe nos 19 produtos que não estão no cardápio novo (bebidas, sorvetes, garrafinhas,
     caixas, Copo Fitness, Whey, Cozinheiras, Napolitano, mantimentos).
   - Não mexe no grupo "4 Adicionais Grátis": grátis continua grátis.
   - Não mexe em Granola nem Leite Condensado pagos (R$ 2,00): o cardápio novo não dá preço
     pago para eles, então ficam como estão até alguém decidir.
   =========================================================================================== */

const APLICAR = false;        // ← troque para true SÓ depois de conferir o ensaio

(async () => {
  const LOJA_ESPERADA = 18;
  const money = (v) => 'R$ ' + Number(v).toFixed(2).replace('.', ',');

  // ---------------------------------------------------------------- o cardápio novo
  const PRECO_PRODUTO = {
    'Barca de Açaí Gourmet': 47.90,
    'Titanic Tamanho Família': 66.90,
    'Roleta de Açaí Gourmet': 50.90,
    'Copo de Açaí 300ml': 19.90,
    'Copo de Açaí 500ml': 24.90,
    'Copo de Açaí 770ml': 28.90,
    'Pote de Açaí 1L': 35.90,
    'Copo da Patroa 500ml': 31.90,
    'Copo do Patrão 700ml': 36.90,
    'Leve 5 Pague 4 Açaí': 74.90,
    'Monte Seu Açaí': 0.00,      // o preço passa a vir só do recipiente escolhido
  };

  const PRECO_ADICIONAL = {
    'Banana': 3.00, 'Morango': 3.00,
    'Calda de Chocolate': 3.00, 'Calda de Morango': 3.00,
    'Leite em Pó': 3.00, 'Sucrilhos': 3.00, 'Oreo': 3.50, 'Ovomaltine': 3.00,
    'Kit Kat': 4.00, 'Bis': 3.00, 'Chocoboll': 3.00, 'Ouro Branco': 3.00,
    'Sonho de Valsa': 3.00, 'Paçoquita': 3.00, 'Aveia': 3.00, 'Confete': 3.00,
    'Whey Protein': 7.00,
    'Doce de Leite': 3.00, 'Pasta de Amendoim Integral': 3.50,
    'Creme de Avelã': 4.50, 'Creme de Leitinho': 4.50, 'Creme de Paçoca': 4.50,
  };

  // "AÇAÍ PURO" do cardápio = o grupo Recipientes do Monte Seu Açaí
  const PRECO_RECIPIENTE = {
    'Copo 300ml Puro': 12.90,
    'Copo 500ml Puro': 16.90,
    'Copo 700ml Puro': 19.90,
    'Pote 1L Puro': 24.90,
  };

  // Os três especiais viram nove produtos. O que já existe vira o de 300ml.
  const ESPECIAIS = [
    { atual: 'Ziraniho', nome: 'Ziraninho' },   // o cadastro tem um "n" a menos que o cardápio
    { atual: 'Ziraçoca', nome: 'Ziraçoca' },
    { atual: 'Ziratella', nome: 'Ziratella' },
  ];
  const TAMANHOS = [['300ml', 24.90], ['500ml', 29.90], ['770ml', 34.90]];

  const GRATIS = '4 Adicionais Grátis';

  // ---------------------------------------------------------------- confere a loja
  const user = Bora.user && Bora.user();
  if (!user) { console.error('❌ Não achei a sessão. Entre no painel antes de rodar.'); return; }
  if (Number(user.lojaId) !== LOJA_ESPERADA) {
    console.error('❌ PAREI: você está na loja ' + user.lojaId + ', e este script é da loja '
      + LOJA_ESPERADA + ' (Zirá Açaíteria). Troque de loja e rode de novo.');
    return;
  }
  console.log('%cLoja ' + user.lojaId + ' · ' + (APLICAR ? 'APLICANDO DE VERDADE' : 'ENSAIO — nada será mudado'),
    'font-weight:bold;font-size:14px;color:' + (APLICAR ? '#b91c1c' : '#065f46'));

  const produtos = await Bora.api('/api/produtos');

  // O servidor OMITE o custo para papéis que não podem ver dinheiro de dono (ProdutoResumo.semCusto).
  // Se eu gravasse o cadastro sem ele, apagaria o custo de todos os produtos -- e com ele o CMV e a
  // margem dos relatórios. Então paro antes.
  if (produtos.length && !('custo' in produtos[0])) {
    console.error('❌ PAREI: a lista de produtos veio SEM o campo de custo, o que acontece quando a '
      + 'conta não pode ver custo. Gravar assim apagaria o custo de todos. Entre com uma conta de '
      + 'administrador da loja.');
    return;
  }

  const porNome = {};
  produtos.forEach(p => { porNome[p.nome] = p; });

  const feito = [], falhou = [], plano = [];

  /**
   * Corpo de edição de produto: devolve EXATAMENTE o que o cadastro tem, mudando só o pedido.
   *
   * `custo` e `estoqueMinimo` são gravados pelo servidor SEM CONDIÇÃO (ProdutoService.java:72,81).
   * Então mandar vazio no lugar do valor lido apagaria os dois. Passo o valor cru adiante.
   */
  function corpoDe(p, mudancas) {
    return Object.assign({
      nome: p.nome,
      categoria: p.categoria,
      preco: Number(p.preco),
      custo: p.custo,                      // cru: null continua null, número continua número
      estoqueMinimo: p.estoqueMinimo,      // idem
      ativo: p.ativo !== false,
      codigoExterno: p.codigoExterno || '',
      // estoque e imagemUrl ficam FORA: ver o cabeçalho deste arquivo.
    }, mudancas);
  }

  async function executar(rotulo, fn) {
    plano.push(rotulo);
    if (!APLICAR) return;
    try { await fn(); feito.push(rotulo); }
    catch (e) { falhou.push(rotulo + '  →  ' + (e && e.message || e)); }
  }

  // ---------------------------------------------------------------- 1) preços de produto
  for (const [nome, novo] of Object.entries(PRECO_PRODUTO)) {
    const p = porNome[nome];
    if (!p) { falhou.push('produto não encontrado: ' + nome); continue; }
    if (Math.abs(Number(p.preco) - novo) < 0.001) continue;
    await executar(`preço · ${nome}: ${money(p.preco)} → ${money(novo)}`, () =>
      Bora.api('/api/produtos/' + p.id, { method: 'PUT', body: JSON.stringify(corpoDe(p, { preco: novo })) }));
  }

  // ---------------------------------------------------------------- 2) adicionais, produto a produto
  for (const p of produtos) {
    let grupos;
    try { grupos = await Bora.api('/api/produtos/' + p.id + '/complementos'); }
    catch (e) { falhou.push('não li os adicionais de ' + p.nome + ': ' + e.message); continue; }
    if (!grupos || !grupos.length) continue;

    const mudou = [];
    for (const g of grupos) {
      if (g.nome === GRATIS) continue;
      for (const i of (g.itens || [])) {
        const alvo = g.nome === 'Recipientes' ? PRECO_RECIPIENTE[i.nome] : PRECO_ADICIONAL[i.nome];
        if (alvo == null) continue;
        if (Math.abs(Number(i.preco) - alvo) < 0.001) continue;
        mudou.push(`${i.nome} ${money(i.preco)}→${money(alvo)}`);
        i.preco = alvo;          // só o preço; insumoId e quantidade seguem intactos
      }
    }
    if (!mudou.length) continue;
    await executar(`adicionais · ${p.nome} (${mudou.length}): ${mudou.slice(0, 3).join(', ')}${mudou.length > 3 ? '…' : ''}`,
      () => Bora.api('/api/produtos/' + p.id + '/complementos', { method: 'PUT', body: JSON.stringify(grupos) }));
  }

  // ---------------------------------------------------------------- 3) os três especiais
  for (const esp of ESPECIAIS) {
    const p = porNome[esp.atual];
    if (!p) { falhou.push('especial não encontrado: ' + esp.atual); continue; }
    const [tam0, preco0] = TAMANHOS[0];
    const nome300 = `${esp.nome} ${tam0}`;
    await executar(`renomear · ${esp.atual} → ${nome300}, ${money(p.preco)} → ${money(preco0)}`, () =>
      Bora.api('/api/produtos/' + p.id, { method: 'PUT', body: JSON.stringify(corpoDe(p, { nome: nome300, preco: preco0 })) }));

    // os adicionais do 300ml, para copiar nos tamanhos novos
    let modelo = [];
    try { modelo = await Bora.api('/api/produtos/' + p.id + '/complementos') || []; } catch (e) { /* segue sem copiar */ }

    for (const [tam, preco] of TAMANHOS.slice(1)) {
      const nomeNovo = `${esp.nome} ${tam}`;
      if (porNome[nomeNovo]) { plano.push(`(já existe, pulei) ${nomeNovo}`); continue; }
      await executar(`criar · ${nomeNovo} ${money(preco)} + ${modelo.length} grupo(s) de adicional`, async () => {
        const criado = await Bora.api('/api/produtos', {
          method: 'POST',
          body: JSON.stringify({
            nome: nomeNovo, categoria: p.categoria, preco,
            custo: p.custo,
            estoque: null, estoqueMinimo: null,   // nasce sem controle de estoque
            ativo: true, codigoExterno: '',
          }),
        });
        if (modelo.length) {
          await Bora.api('/api/produtos/' + criado.id + '/complementos',
            { method: 'PUT', body: JSON.stringify(modelo) });
        }
      });
    }
  }

  // ---------------------------------------------------------------- o relatório
  console.log('\n%c' + (APLICAR ? 'O QUE FOI FEITO' : 'O QUE SERIA FEITO (ensaio)'), 'font-weight:bold;font-size:13px');
  plano.forEach((l, n) => console.log('  ' + String(n + 1).padStart(3) + '. ' + l));
  console.log('\ntotal de operações: ' + plano.length);

  if (APLICAR) {
    console.log('%caplicadas com sucesso: ' + feito.length, 'color:#065f46;font-weight:bold');
    if (falhou.length) {
      console.log('%cfalharam: ' + falhou.length, 'color:#b91c1c;font-weight:bold');
      falhou.forEach(f => console.log('   ✗ ' + f));
      console.log('As que falharam NÃO foram aplicadas. Rodar de novo refaz só o que ainda falta.');
    } else {
      console.log('%cNenhuma falha. Confira o cardápio digital.', 'color:#065f46');
    }
  } else if (falhou.length) {
    console.log('%cavisos do ensaio:', 'color:#b45309;font-weight:bold');
    falhou.forEach(f => console.log('   ! ' + f));
  }
  console.log(APLICAR ? '' : '\nPara aplicar: troque `const APLICAR = false` para `true` e cole de novo.');
})();
