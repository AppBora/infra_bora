#!/usr/bin/env node
/**
 * Mock da 99Food pelo padrao Open Delivery v1.7.1.
 *
 * Escrito a partir de dois documentos, NAO do codigo do Bora:
 *   - a especificacao oficial (openapi.yaml da Abrasel, versao v1.7.1)
 *   - o "Roteiro de Integracao OpenDelivery" que o time de integracao da 99 mandou
 *
 * O mock anterior do iFood aceitava tudo e por isso deixou passar furo depois de furo. Este
 * RECUSA o que a 99 recusa, e guarda cada recusa em /_mock/status: um teste so passa se, no fim,
 * a lista de recusas estiver vazia.
 *
 * Uso:
 *   node mock-99food.js            # sobe em :9199
 * API apontada para ele:
 *   BORA_OPENDELIVERY_BASE_URL=http://host.docker.internal:9199
 *   BORA_OPENDELIVERY_CLIENT_ID=mock-app        (App ID da plataforma)
 *   BORA_OPENDELIVERY_CLIENT_SECRET=mock-secret (App Secret da plataforma)
 *
 * Rotas de teste (fora do contrato da 99):
 *   GET  /_mock/novo-pedido?shop=loja-1&entrega=MERCHANT|MARKETPLACE&pagamento=ONLINE|CASH
 *   GET  /_mock/cliente-pede-cancelamento?pedido=ID   -> evento ORDER_CANCELLATION_REQUEST
 *   GET  /_mock/cliente-cancelou?pedido=ID            -> evento CANCELLED
 *   POST /_mock/webhook?destino=URL&pedido=ID[&assinatura=errada][&shop=OUTRA]
 *   GET  /_mock/status
 */
const http = require('http');
const crypto = require('crypto');
const { randomUUID } = crypto;

const PORT = Number(process.env.PORT || 9199);
const APP_ID = process.env.APP_ID || 'mock-app';
const APP_SECRET = process.env.APP_SECRET || 'mock-secret';

// RequestCancelled.code (especificacao)
const CODIGOS_CANCELAMENTO = [
  'SYSTEMIC_ISSUES', 'DUPLICATE_APPLICATION', 'UNAVAILABLE_ITEM', 'RESTAURANT_WITHOUT_DELIVERY_PERSON',
  'OUTDATED_MENU', 'ORDER_OUTSIDE_THE_DELIVERY_AREA', 'BLOCKED_CUSTOMER', 'OUTSIDE_DELIVERY_HOURS',
  'INTERNAL_DIFFICULTIES_OF_THE_RESTAURANT', 'RISK_AREA', 'DELIVERY_PROBLEM'
];
// RequestDenied.code (especificacao)
const CODIGOS_NEGATIVA = ['DISH_ALREADY_DONE', 'OUT_FOR_DELIVERY'];
// Rotas /v1/orders/{orderId}/{verbo} que existem na especificacao
const VERBOS = ['confirm', 'preparing', 'readyForPickup', 'pickedUp', 'dispatch', 'delivered',
  'requestCancellation', 'acceptCancellation', 'denyCancellation'];

const pedidos = new Map();   // orderId -> { shop, entrega, pedido }
const tokens = new Map();    // access_token -> app_shop_id
let eventos = [];            // [{ shop, evento }]
let seq = 0;
const recebidos = [];        // o que a API do Bora mandou para a "99"
const recusas = [];          // o que a "99" recusou, e por que

const log = (...a) => console.log('  [99food]', ...a);

function json(res, code, body) {
  const txt = JSON.stringify(body);
  res.writeHead(code, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(txt) });
  res.end(txt);
}

function semCorpo(res, code) {
  res.writeHead(code);
  res.end();
}

function recusar(res, code, motivo, extra) {
  recusas.push({ code, motivo, ...(extra || {}), em: new Date().toISOString() });
  log('RECUSADO ' + code + ': ' + motivo);
  return json(res, code, { title: motivo, status: code });
}

function lerCorpo(req) {
  return new Promise(resolve => {
    let b = '';
    req.on('data', c => (b += c));
    req.on('end', () => resolve(b));
  });
}

const preco = v => ({ value: Number(v.toFixed(2)), currency: 'BRL' });

function emitir(shop, orderId, eventType, metadata) {
  const evento = {
    eventId: randomUUID(), eventType, orderId,
    orderURL: 'http://localhost:' + PORT + '/v1/orders/' + orderId,
    createdAt: new Date().toISOString()
  };
  if (metadata) evento.metadata = metadata;
  eventos.push({ shop, evento });
  return evento;
}

function novoPedido(shop, entrega, pagamento) {
  seq += 1;
  const id = randomUUID();
  const pelaPlataforma = entrega === 'MARKETPLACE';
  // Retirada (aviso do Time de Engenharia 99Food, 22/09/2026 + especificacao v1.7.1): type TAKEOUT,
  // o objeto delivery NAO vem, vem o objeto takeout {mode, takeoutDateTime}; sem taxa de entrega.
  const retirada = entrega === 'TAKEOUT';
  const itensTotal = 47, taxa = retirada ? 0 : 7, desconto = 5, total = itensTotal + taxa - desconto; // 49,00 (retirada 42,00)
  const emDinheiro = pagamento === 'CASH' && !pelaPlataforma;
  const agora = new Date().toISOString();
  const pedido = {
    id, type: retirada ? 'TAKEOUT' : 'DELIVERY', displayId: String(4200 + seq), createdAt: agora,
    orderTiming: 'INSTANT', preparationStartDateTime: agora,
    merchant: { id: shop, name: 'Loja de Teste 99' },
    items: [
      {
        id: randomUUID(), index: 1, name: 'Acai 500ml', externalCode: 'ACAI500', quantity: 2,
        specialInstructions: 'sem granola',
        unitPrice: preco(20), optionsPrice: preco(3), subtotalPrice: preco(40), totalPrice: preco(43),
        options: [{ index: 1, id: randomUUID(), name: 'Leite em po', externalCode: 'LEITE', quantity: 1,
          unitPrice: preco(1.5), totalPrice: preco(3) }]
      },
      { id: randomUUID(), index: 2, name: 'Agua 500ml', externalCode: 'AGUA', quantity: 1,
        unitPrice: preco(4), totalPrice: preco(4) }
    ],
    otherFees: retirada ? [] : [{ name: 'Taxa de entrega', type: 'DELIVERY_FEE',
      receivedBy: pelaPlataforma ? 'MARKETPLACE' : 'MERCHANT', price: preco(taxa) }],
    discounts: [{ amount: preco(desconto), target: 'CART',
      sponsorshipValues: [{ name: 'MARKETPLACE', amount: preco(desconto) }] }],
    total: { itemsPrice: preco(itensTotal), otherFees: preco(taxa), discount: preco(desconto), orderAmount: preco(total) },
    payments: emDinheiro
      ? { prepaid: 0, pending: total, methods: [{ value: total, currency: 'BRL', type: 'PENDING', method: 'CASH', changeFor: 100 }] }
      : { prepaid: total, pending: 0, methods: [{ value: total, currency: 'BRL', type: 'PREPAID', method: 'CREDIT', brand: 'VISA' }] },
    customer: { id: randomUUID(), name: 'Cliente 99 Teste ' + seq, phone: { number: '62955550' + String(100 + seq) },
      ordersCountOnMerchant: 1 },
    delivery: {
      deliveredBy: entrega, estimatedDeliveryDateTime: agora,
      deliveryAddress: {
        country: 'BR', state: 'GO', city: 'Goiania', district: 'Setor Bueno', street: 'Avenida T-2',
        number: String(100 + seq), complement: 'Ap ' + seq, reference: 'em frente a praca', postalCode: '74210010',
        formattedAddress: 'Avenida T-2, ' + (100 + seq) + ' - Setor Bueno, Goiania - GO',
        coordinates: { latitude: -16.6918214, longitude: -49.2811349 }
      }
    },
    extraInfo: 'Tocar a campainha duas vezes'
  };
  if (retirada) {
    delete pedido.delivery;
    pedido.extraInfo = 'Vou chegar de moto';
    pedido.takeout = { mode: 'DEFAULT', takeoutDateTime: new Date(Date.now() + 20 * 60000).toISOString() };
  }
  pedidos.set(id, { shop, entrega, pedido });
  emitir(shop, id, 'CREATED');
  return pedido;
}

const lojaDoToken = req => {
  const a = req.headers['authorization'] || '';
  return a.startsWith('Bearer ') ? tokens.get(a.slice(7)) : undefined;
};

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const rota = url.pathname;
  const corpo = await lerCorpo(req);

  // ---- token: x-www-form-urlencoded; client_id = {app_id}_{app_shop_id} (roteiro, pag. 17) ----
  if (rota === '/oauth/token' && req.method === 'POST') {
    const tipo = String(req.headers['content-type'] || '');
    if (!tipo.includes('application/x-www-form-urlencoded')) {
      return recusar(res, 400, 'token exige application/x-www-form-urlencoded', { recebido: tipo });
    }
    const f = Object.fromEntries(new URLSearchParams(corpo));
    if (f.grant_type !== 'client_credentials') {
      return recusar(res, 400, 'grant_type deve ser client_credentials', { recebido: f.grant_type });
    }
    const m = /^(.+?)_(.+)$/.exec(f.client_id || '');
    if (!m || m[1] !== APP_ID) {
      return recusar(res, 401, 'client_id deve ser {app_id}_{app_shop_id}', { recebido: f.client_id });
    }
    if (f.client_secret !== APP_SECRET) return recusar(res, 401, 'client_secret invalido');
    const token = 'tok-' + randomUUID();
    tokens.set(token, m[2]);
    log('token emitido para a loja ' + m[2]);
    return json(res, 200, { access_token: token, token_type: 'bearer', expires_in: 3600 });
  }

  // ---- utilitarios de teste ----
  if (rota === '/_mock/novo-pedido') {
    const p = novoPedido(url.searchParams.get('shop') || 'loja-1',
      (url.searchParams.get('entrega') || 'MERCHANT').toUpperCase(),
      (url.searchParams.get('pagamento') || 'ONLINE').toUpperCase());
    log('pedido #' + p.displayId + ' criado (' + p.id + ')');
    return json(res, 200, { orderId: p.id, displayId: p.displayId });
  }
  if (rota === '/_mock/cliente-pede-cancelamento' || rota === '/_mock/cliente-cancelou') {
    const alvo = pedidos.get(url.searchParams.get('pedido') || '');
    if (!alvo) return json(res, 404, { erro: 'pedido desconhecido' });
    const tipo = rota.endsWith('cancelou') ? 'CANCELLED' : 'ORDER_CANCELLATION_REQUEST';
    emitir(alvo.shop, alvo.pedido.id, tipo, { reason: 'Cliente desistiu do pedido', code: 'CONSUMER_CANCELLATION_REQUESTED' });
    log(tipo + ' emitido para ' + alvo.pedido.id);
    return json(res, 200, { emitido: tipo });
  }
  if (rota === '/_mock/webhook' && req.method === 'POST') {
    const destino = url.searchParams.get('destino');
    const alvo = pedidos.get(url.searchParams.get('pedido') || '');
    if (!destino || !alvo) return json(res, 400, { erro: 'informe destino e pedido' });
    const evento = {
      eventId: randomUUID(), eventType: url.searchParams.get('tipo') || 'CREATED', orderId: alvo.pedido.id,
      orderURL: 'http://localhost:' + PORT + '/v1/orders/' + alvo.pedido.id, createdAt: new Date().toISOString()
    };
    const texto = JSON.stringify(evento);
    const certa = crypto.createHmac('sha256', APP_SECRET).update(texto).digest('hex');
    const assinatura = url.searchParams.get('assinatura') === 'errada' ? '0'.repeat(64) : certa;
    const merchant = url.searchParams.get('shop') || alvo.shop;
    try {
      const resp = await fetch(destino, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-App-Id': APP_ID, 'X-App-MerchantId': merchant, 'X-App-Signature': assinatura },
        body: texto
      });
      log('webhook ' + evento.eventType + ' -> ' + destino + ' respondeu ' + resp.status);
      return json(res, 200, { status: resp.status });
    } catch (e) {
      return json(res, 502, { erro: String(e) });
    }
  }
  if (rota === '/_mock/status') {
    return json(res, 200, { recebidos, recusas, eventosPendentes: eventos.length });
  }

  // ---- daqui para baixo exige token ----
  const shop = lojaDoToken(req);
  if (!shop) return recusar(res, 401, 'sem token valido', { rota });

  // GET /v1/events:polling
  if (rota === '/v1/events:polling' && req.method === 'GET') {
    return json(res, 200, eventos.filter(e => e.shop === shop).map(e => e.evento));
  }

  // POST /v1/events/acknowledgment — AckEvents exige id, orderId e eventType
  if (rota === '/v1/events/acknowledgment' && req.method === 'POST') {
    let lista;
    try { lista = JSON.parse(corpo); } catch (e) { return recusar(res, 400, 'acknowledgment com corpo ilegivel'); }
    if (!Array.isArray(lista)) return recusar(res, 400, 'acknowledgment deve ser uma lista');
    for (const a of lista) {
      if (!a || !a.id || !a.orderId || !a.eventType) {
        return recusar(res, 400, 'acknowledgment exige id, orderId e eventType', { item: a });
      }
    }
    const ids = new Set(lista.map(a => a.id));
    eventos = eventos.filter(e => !ids.has(e.evento.eventId));
    recebidos.push({ acao: 'acknowledgment', quantidade: lista.length, em: new Date().toISOString() });
    return semCorpo(res, 202);
  }

  // GET /v1/orders/{orderId}
  const detalhe = /^\/v1\/orders\/([^/]+)$/.exec(rota);
  if (detalhe && req.method === 'GET') {
    const alvo = pedidos.get(detalhe[1]);
    if (!alvo || alvo.shop !== shop) return recusar(res, 404, 'pedido nao encontrado', { orderId: detalhe[1] });
    return json(res, 200, alvo.pedido);
  }

  // POST /v1/orders/{orderId}/{verbo}
  const acao = /^\/v1\/orders\/([^/]+)\/([A-Za-z]+)$/.exec(rota);
  if (acao && req.method === 'POST') {
    const [, orderId, verbo] = acao;
    if (!VERBOS.includes(verbo)) return recusar(res, 404, 'verbo inexistente no Open Delivery: ' + verbo, { orderId });
    const alvo = pedidos.get(orderId);
    if (!alvo || alvo.shop !== shop) return recusar(res, 404, 'pedido nao encontrado', { orderId, verbo });
    // Roteiro, pag. 23: com entrega pela 99 o ultimo status da loja e readyForPickup.
    if (alvo.entrega === 'MARKETPLACE' && (verbo === 'dispatch' || verbo === 'delivered')) {
      return recusar(res, 422, 'entrega pela 99: a loja para em readyForPickup', { orderId, verbo });
    }
    // Retirada: nao ha entrega para despachar nem entregar; o fim e pickedUp. E pickedUp so vale
    // para TAKEOUT ("should be sent only ... when the Order serviceType = TAKEOUT").
    if (alvo.entrega === 'TAKEOUT' && (verbo === 'dispatch' || verbo === 'delivered')) {
      return recusar(res, 422, 'retirada: nao existe ' + verbo + ', o cliente retira (pickedUp)', { orderId, verbo });
    }
    if (verbo === 'pickedUp' && alvo.entrega !== 'TAKEOUT') {
      return recusar(res, 422, 'pickedUp so vale para pedido de retirada (TAKEOUT)', { orderId, verbo });
    }
    let enviado = {};
    if (corpo) {
      try { enviado = JSON.parse(corpo); } catch (e) { return recusar(res, 400, verbo + ' com corpo ilegivel', { orderId }); }
    }
    if (verbo === 'requestCancellation') {
      if (!enviado.reason) return recusar(res, 400, 'cancelamento exige reason', { orderId });
      if (!CODIGOS_CANCELAMENTO.includes(enviado.code)) {
        return recusar(res, 400, 'cancelamento exige code da lista', { orderId, recebido: enviado.code });
      }
      if (!['AUTO', 'MANUAL'].includes(enviado.mode)) {
        return recusar(res, 400, 'cancelamento exige mode AUTO ou MANUAL', { orderId, recebido: enviado.mode });
      }
      // A especificacao espera o evento de cancelamento depois desta acao.
      emitir(alvo.shop, orderId, 'CANCELLED', { reason: enviado.reason, code: enviado.code });
    }
    if (verbo === 'denyCancellation') {
      if (!enviado.reason || !CODIGOS_NEGATIVA.includes(enviado.code)) {
        return recusar(res, 400, 'negativa exige reason e code DISH_ALREADY_DONE ou OUT_FOR_DELIVERY', { orderId, recebido: enviado });
      }
    }
    recebidos.push({ orderId, verbo, corpo: enviado, em: new Date().toISOString() });
    log(verbo + ' <- ' + orderId + (enviado.code ? ' (' + enviado.code + ')' : ''));
    return semCorpo(res, 202);
  }

  return recusar(res, 404, 'rota nao existe no Open Delivery', { rota, metodo: req.method });
});

server.listen(PORT, () => {
  console.log('Mock da 99Food (Open Delivery v1.7.1) em http://localhost:' + PORT);
  console.log('  App ID: ' + APP_ID + '   App Secret: ' + APP_SECRET);
  console.log('  client_id esperado: ' + APP_ID + '_{app_shop_id}');
});
