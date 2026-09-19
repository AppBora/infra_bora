#!/usr/bin/env node
/**
 * Mock da Merchant API do iFood — permite provar o ciclo completo da integração
 * (vínculo -> polling -> detalhe do pedido -> acknowledgment -> push de status)
 * sem depender das credenciais reais, que só saem depois da homologação.
 *
 * Implementa o contrato oficial: campos em camelCase, header x-polling-merchants,
 * e o fluxo de aplicativo distribuído (userCode -> authorization_code -> refresh_token).
 *
 * Uso:
 *   node mock-ifood.js                # sobe em :9099
 *   PORT=9099 node mock-ifood.js
 *
 * Depois aponte a API para ele:
 *   BORA_IFOOD_BASE_URL=http://host.docker.internal:9099
 *   BORA_IFOOD_CLIENT_ID=mock-client
 *   BORA_IFOOD_CLIENT_SECRET=mock-secret
 */
const http = require('http');

const PORT = Number(process.env.PORT || 9099);
const CODIGO_USUARIO = 'ABCD-1234';
const AUTORIZACAO_ESPERADA = 'AUTORIZA-OK';

// Estado em memória: eventos pendentes e pedidos que o "iFood" conhece.
const pedidos = new Map();
let eventos = [];
let seq = 0;
const statusRecebidos = [];

// Formato copiado de um pedido REAL da loja de teste (19/09/2026): total em numero, totalPrice do item
// com complementos, card.brand, prepaid/pending. Variantes (pagamento, cupom, retirada, agendado,
// entrega pelo iFood) seguem a documentacao do iFood ate serem vistas em pedido real.
function novoPedido(merchantId, clienteId, op) {
  op = op || {};
  seq += 1;
  const id = 'MOCK-ORDER-' + seq;
  const agora = Date.now();
  const iso = ms => new Date(ms).toISOString();
  const retirada = op.tipo === 'TAKEOUT';
  const itens = [
    { index: 1, id: 'it-a-' + seq, name: 'Pizza Margherita', quantity: 1, unit: 'UN', unitPrice: 45.9, optionsPrice: 4,
      totalPrice: 49.9, price: 45.9, observations: 'sem cebola',
      options: [{ index: 2, name: 'Borda catupiry', groupName: 'Borda', quantity: 1, unitPrice: 4, price: 4 }] },
    { index: 3, id: 'it-b-' + seq, name: 'Refrigerante 2L', quantity: 2, unit: 'UN', unitPrice: 12, optionsPrice: 0,
      totalPrice: 24, price: 24, observations: '', options: [] }
  ];
  const subTotal = 73.9;
  const deliveryFee = retirada ? 0 : 7;
  const desconto = op.cupom ? 10 : 0;
  const orderAmount = Math.round((subTotal + deliveryFee - desconto) * 100) / 100;
  const pedido = {
    id, displayId: String(1000 + seq), createdAt: iso(agora), category: 'FOOD',
    orderTiming: op.agendado ? 'SCHEDULED' : 'IMMEDIATE',
    orderType: retirada ? 'TAKEOUT' : 'DELIVERY',
    merchant: { id: merchantId || 'merchant-teste-123' },
    // Como o iFood real: o telefone e a CENTRAL do iFood (igual para todos) + localizador;
    // quem identifica o cliente e o customer.id.
    customer: { id: clienteId || ('cust-' + seq), name: 'Cliente Mock ' + seq,
      phone: { number: '0800 705 1020', localizer: String(12345670 + seq), localizerExpiration: iso(agora + 3 * 3600e3) } },
    items: itens,
    total: { additionalFees: 0, subTotal, deliveryFee, benefits: desconto, orderAmount },
    observations: 'Pedido de teste do mock'
  };
  if (!retirada) {
    pedido.delivery = {
      mode: 'DEFAULT', deliveredBy: op.entrega === 'IFOOD' ? 'IFOOD' : 'MERCHANT', deliveryDateTime: iso(agora + 45 * 60e3),
      // Criterio de homologacao do iFood: esta observacao TEM que aparecer na tela de quem recebe
      // o pedido. E campo do delivery, nao do pedido - sao dois "observations" diferentes.
      observations: 'Interfone quebrado, ligar ao chegar',
      deliveryAddress: {
        streetName: 'Rua da Integração', streetNumber: String(100 + seq), neighborhood: 'Centro',
        complement: 'apto ' + seq, reference: 'portao azul, ao lado da padaria'
      },
      pickupCode: '4321'
    };
  } else {
    pedido.takeout = { mode: 'DEFAULT', takeoutDateTime: iso(agora + 30 * 60e3) };
  }
  if (op.agendado) pedido.schedule = { deliveryDateTimeStart: iso(agora + 2 * 3600e3), deliveryDateTimeEnd: iso(agora + 2.5 * 3600e3) };
  if (desconto) {
    pedido.benefits = [{ value: desconto, target: 'CART',
      sponsorshipValues: [{ name: op.cupom, value: desconto, description: 'Cupom de teste' }] }];
  }
  if (op.pagamento === 'CASH') {
    pedido.payments = { prepaid: 0, pending: orderAmount, methods: [{ value: orderAmount, currency: 'BRL', method: 'CASH',
      prepaid: false, type: 'OFFLINE', cash: { changeFor: Number(op.troco || 0) } }] };
  } else if (op.pagamento === 'CARD_OFFLINE') {
    pedido.payments = { prepaid: 0, pending: orderAmount, methods: [{ value: orderAmount, currency: 'BRL', method: 'DEBIT',
      prepaid: false, type: 'OFFLINE', card: { brand: 'Elo' } }] };
  } else {
    pedido.payments = { prepaid: orderAmount, pending: 0, methods: [{ value: orderAmount, currency: 'BRL', method: 'CREDIT',
      prepaid: true, type: 'ONLINE', card: { brand: 'Visa' } }] };
  }
  pedidos.set(id, pedido);
  eventos.push({ id: 'EV-' + seq, code: 'PLC', fullCode: 'PLACED', orderId: id, createdAt: iso(agora) });
  return id;
}

function json(res, code, body) {
  const txt = JSON.stringify(body);
  res.writeHead(code, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(txt) });
  res.end(txt);
}

function lerCorpo(req) {
  return new Promise(resolve => {
    let b = '';
    req.on('data', c => (b += c));
    req.on('end', () => resolve(b));
  });
}

function form(txt) {
  const out = {};
  new URLSearchParams(txt).forEach((v, k) => (out[k] = v));
  return out;
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const rota = url.pathname;
  const corpo = await lerCorpo(req);
  const log = (...a) => console.log('  [mock]', ...a);

  // ---- autenticação ----
  if (rota === '/authentication/v1.0/oauth/userCode' && req.method === 'POST') {
    const f = form(corpo);
    log('userCode pedido por clientId=' + f.clientId);
    return json(res, 200, {
      userCode: CODIGO_USUARIO,
      authorizationCodeVerifier: 'verifier-mock-xyz',
      verificationUrl: 'https://portal.ifood.com.br/apps/code',
      verificationUrlComplete: 'https://portal.ifood.com.br/apps/code?c=' + CODIGO_USUARIO,
      expiresIn: 600
    });
  }

  if (rota === '/authentication/v1.0/oauth/token' && req.method === 'POST') {
    const f = form(corpo);
    log('token grantType=' + f.grantType);
    if (f.grantType === 'authorization_code') {
      if (f.authorizationCode !== AUTORIZACAO_ESPERADA) {
        return json(res, 400, { error: 'invalid_grant', message: 'Código de autorização inválido' });
      }
      if (!f.authorizationCodeVerifier) {
        return json(res, 400, { error: 'invalid_request', message: 'authorizationCodeVerifier ausente' });
      }
    } else if (f.grantType === 'refresh_token') {
      if (!f.refreshToken) return json(res, 400, { error: 'invalid_request' });
    } else {
      return json(res, 400, { error: 'unsupported_grant_type', recebido: f.grantType });
    }
    return json(res, 200, {
      accessToken: 'access-mock-' + Date.now(),
      refreshToken: 'refresh-mock-fixo',
      expiresIn: 21600,
      type: 'bearer'
    });
  }

  // ---- daqui pra baixo exige Bearer ----
  const auth = req.headers['authorization'] || '';
  if (!auth.startsWith('Bearer ')) return json(res, 401, { error: 'unauthorized' });

  if (rota === '/events/v1.0/events:polling' && req.method === 'GET') {
    const merchants = req.headers['x-polling-merchants'];
    if (!merchants) return json(res, 400, { error: 'x-polling-merchants ausente' });
    if (eventos.length) log('polling -> devolvendo ' + eventos.length + ' evento(s) para ' + merchants);
    return json(res, 200, eventos);
  }

  if (rota === '/events/v1.0/events/acknowledgment' && req.method === 'POST') {
    let ids = [];
    try { ids = JSON.parse(corpo || '[]').map(e => e.id); } catch (e) { /* corpo inválido */ }
    eventos = eventos.filter(e => !ids.includes(e.id));
    log('ack de ' + ids.length + ' evento(s); pendentes agora: ' + eventos.length);
    return json(res, 202, {});
  }

  const detalhe = rota.match(/^\/order\/v1\.0\/orders\/([^/]+)$/);
  if (detalhe && req.method === 'GET') {
    const p = pedidos.get(detalhe[1]);
    if (!p) return json(res, 404, { error: 'not found' });
    log('detalhe do pedido ' + p.id);
    return json(res, 200, p);
  }

  // O iFood devolve a lista de motivos VALIDOS para aquele pedido; a doc dele proibe lista fixa no
  // parceiro. O mock antes aceitava requestCancellation sem corpo nenhum - e foi assim que passou
  // despercebido que a gente cancelava sem motivo.
  const motivos = rota.match(/^\/order\/v1\.0\/orders\/([^/]+)\/cancellationReasons$/);
  if (motivos && req.method === 'GET') {
    // Como o iFood real: pedido que ja chegou em "pronto" nao aceita cancelamento pela loja (lista vazia).
    if (statusRecebidos.some(s => s.orderId === motivos[1] && ['readyToPickup', 'dispatch'].includes(s.verbo))) {
      return json(res, 200, []);
    }
    return json(res, 200, [
      { cancelCodeId: '501', description: 'PROBLEMAS DE SISTEMA' },
      { cancelCodeId: '502', description: 'PEDIDO EM DUPLICIDADE' },
      { cancelCodeId: '506', description: 'ITEM INDISPONIVEL' }
    ]);
  }

  const acao = rota.match(/^\/order\/v1\.0\/orders\/([^/]+)\/(confirm|startPreparation|readyToPickup|dispatch|requestCancellation)$/);
  if (acao && req.method === 'POST') {
    // Cancelamento sem codigo de motivo o iFood recusa. O mock passa a recusar tambem: mock que
    // aceita o que o real recusa nao prova nada - foi assim que o furo do cancelamento sobreviveu.
    if (acao[2] === 'requestCancellation') {
      let enviado = {};
      try { enviado = JSON.parse(corpo || '{}'); } catch (e) { enviado = {}; }
      // O iFood real exige o codigo no campo cancellationCode (o mock aceitava "reason" e escondeu
      // que mandavamos o campo errado ate o 1o cancelamento real, 19/09).
      const codigo = enviado.cancellationCode;
      if (!codigo) {
        log('CANCELAMENTO RECUSADO: sem cancellationCode');
        return json(res, 400, { error: { code: 'InvalidParameter', message: "Invalid cancellation request: Field 'cancellationCode' is required" } });
      }
      statusRecebidos.push({ orderId: acao[1], verbo: acao[2], motivo: codigo, em: new Date().toISOString() });
      log('CANCELAMENTO ACEITO: ' + acao[1] + ' motivo ' + codigo);
      // Como o iFood real: aceitar o pedido de cancelamento gera, em seguida, o evento CANCELLED (code CAN).
      eventos.push({ id: 'EV-CAN-' + acao[1], code: 'CAN', fullCode: 'CANCELLED', orderId: acao[1], createdAt: new Date().toISOString() });
      return json(res, 202, {});
    }
    statusRecebidos.push({ orderId: acao[1], verbo: acao[2], em: new Date().toISOString() });
    // Como o iFood real: confirmar gera o evento CONFIRMED (code CFM) para o mesmo pedido.
    if (acao[2] === 'confirm') {
      eventos.push({ id: 'EV-CFM-' + acao[1], code: 'CFM', fullCode: 'CONFIRMED', orderId: acao[1], createdAt: new Date().toISOString() });
    }
    log('STATUS RECEBIDO: ' + acao[1] + ' -> ' + acao[2]);
    return json(res, 202, {});
  }

  // ---- utilitários do teste (fora do contrato do iFood) ----
  if (rota === '/_mock/novo-pedido') {
    const q = k => url.searchParams.get(k);
    const id = novoPedido(q('merchant'), q('cliente'), { pagamento: q('pagamento'), troco: q('troco'),
      cupom: q('cupom'), tipo: q('tipo'), agendado: q('agendado'), entrega: q('entrega') });
    log('pedido criado para o proximo polling: ' + id);
    return json(res, 200, { orderId: id, eventosPendentes: eventos.length });
  }
  if (rota === '/_mock/status') {
    return json(res, 200, { eventosPendentes: eventos.length, statusRecebidos });
  }

  json(res, 404, { error: 'rota não mapeada no mock', rota, metodo: req.method });
});

server.listen(PORT, () => {
  console.log('Mock da Merchant API do iFood em http://localhost:' + PORT);
  console.log('  userCode fixo:      ' + CODIGO_USUARIO);
  console.log('  autorização válida: ' + AUTORIZACAO_ESPERADA);
  console.log('  criar pedido:       GET /_mock/novo-pedido');
  console.log('  conferir:           GET /_mock/status');
});
