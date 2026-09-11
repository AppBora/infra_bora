#!/usr/bin/env node
/**
 * Mock do Asaas para provar o envio de documento da subconta SEM tocar na conta real do cliente.
 *
 * Existe porque a unica subconta de verdade e a de um lojista: mandar um arquivo de teste para ela
 * sujaria o KYC dele e queimaria as 48h de analise. Aqui o fluxo roda inteiro contra este processo.
 *
 *   node mock-asaas.js               # sobe em http://localhost:8099
 *   ASAAS_BASE_URL=http://host.docker.internal:8099 ASAAS_API_KEY=mock docker compose up -d
 *
 * Implementa so o que o Bora chama: criar subconta, webhook, status e documentos.
 */
const http = require('http');

const PORTA = process.env.PORT || 8099;
const recebidos = [];

const DOCS = [
  { id: 'doc-identificacao', type: 'IDENTIFICATION', status: 'NOT_SENT', onboardingUrl: null,
    title: 'Documentos de identificação', description: 'Para enviar esse documento acesse nosso aplicativo.',
    responsible: { name: '53.953.786 FULANO DE TESTE', type: 'MEI' }, documents: [] },
  { id: 'doc-selfie', type: 'IDENTIFICATION_SELFIE', status: 'NOT_SENT', onboardingUrl: null,
    title: 'Selfie de identificação', description: 'Para enviar esse documento acesse nosso aplicativo.',
    responsible: { name: '53.953.786 FULANO DE TESTE', type: 'MEI' }, documents: [] }
];

function json(res, code, corpo) {
  const txt = JSON.stringify(corpo);
  res.writeHead(code, { 'Content-Type': 'application/json' });
  res.end(txt);
}

const servidor = http.createServer((req, res) => {
  const url = req.url.split('?')[0];
  const pedacos = [];
  req.on('data', d => pedacos.push(d));
  req.on('end', () => {
    const bruto = Buffer.concat(pedacos);
    console.log(`${req.method} ${url}  (${bruto.length} bytes)`);

    if (req.method === 'POST' && url === '/accounts') {
      return json(res, 200, { id: 'sub-mock-1', walletId: 'wallet-mock-1', apiKey: 'chave-da-subconta-mock' });
    }
    if (req.method === 'POST' && url === '/webhooks') {
      return json(res, 200, { id: 'webhook-mock-1' });
    }
    if (req.method === 'GET' && url === '/myAccount/status') {
      return json(res, 200, { id: 'sub-mock-1', commercialInfo: 'APPROVED', bankAccountInfo: 'PENDING',
                              documentation: 'PENDING', general: 'PENDING' });
    }
    if (req.method === 'GET' && url === '/myAccount/documents') {
      return json(res, 200, { data: DOCS, rejectReasons: null });
    }
    if (req.method === 'POST' && url.startsWith('/myAccount/documents/')) {
      const id = url.split('/').pop();
      const tipoConteudo = req.headers['content-type'] || '';
      const texto = bruto.toString('latin1');
      const achado = {
        documentoId: id,
        multipart: tipoConteudo.startsWith('multipart/form-data') && tipoConteudo.includes('boundary='),
        temCampoArquivo: /name="documentFile"/.test(texto),
        temCampoTipo: /name="type"/.test(texto),
        nomeDoArquivo: (texto.match(/filename="([^"]*)"/) || [])[1] || null,
        bytes: bruto.length
      };
      recebidos.push(achado);
      console.log('  -> ' + JSON.stringify(achado));
      const doc = DOCS.find(d => d.id === id);
      if (doc) doc.status = 'PENDING';
      return json(res, 200, { id, status: 'PENDING' });
    }
    // Espelho para o teste conferir o que chegou de verdade.
    if (req.method === 'GET' && url === '/__recebidos') return json(res, 200, recebidos);

    json(res, 404, { errors: [{ description: 'rota nao mockada: ' + req.method + ' ' + url }] });
  });
});

servidor.listen(PORTA, () => console.log('mock do Asaas em http://localhost:' + PORTA));
