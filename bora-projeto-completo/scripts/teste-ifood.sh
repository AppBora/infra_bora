#!/usr/bin/env bash
# Prova que o cancelamento chega ao iFood COM codigo de motivo. Antes ia sem corpo nenhum e o
# iFood recusava - o pedido sumia do nosso painel e continuava aberto la.
API=http://localhost:8080
MOCK=http://localhost:9099
ok=0; fail=0
checa() { if [ "$2" = "$3" ]; then echo "  PASS  $1 ($3)"; ok=$((ok+1)); else echo "  FALHA $1 — esperado $2, veio $3"; fail=$((fail+1)); fi; }

T=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" -d '{"email":"admin@bora.app","senha":"bora123"}' | python -c "import sys,json;print(json.load(sys.stdin)['token'])")
AUTH="Authorization: Bearer $T"; JSON="Content-Type: application/json"

echo "== vincula a loja ao iFood (fluxo userCode) =="
curl -s -o /dev/null -X PUT $API/api/integracoes/IFOOD -H "$JSON" -H "$AUTH" -d '{"merchantId":"merchant-mock-1","ativo":true}'
curl -s -o /dev/null -X POST $API/api/integracoes/IFOOD/vincular -H "$AUTH"
curl -s -o /dev/null -X POST $API/api/integracoes/IFOOD/confirmar -H "$JSON" -H "$AUTH" -d '{"authorizationCode":"AUTORIZA-OK"}'
EST=$(curl -s $API/api/integracoes -H "$AUTH" | python -c "
import sys,json
for c in json.load(sys.stdin):
    if c['canal']=='IFOOD': print(c['status'])")
checa "integracao conectada"                 "CONECTADO" "$EST"

echo "== o iFood cria um pedido e o poller importa =="
PEDIDO_IFOOD=$(curl -s -H "Authorization: Bearer teste" "$MOCK/_mock/novo-pedido?merchant=merchant-mock-1" | python -c "import sys,json;print(json.load(sys.stdin)['orderId'])")
echo "  pedido no iFood: $PEDIDO_IFOOD"
for i in $(seq 1 12); do
  ID=$(curl -s "$API/api/pedidos" -H "$AUTH" | python -c "
import sys,json
ps=[p for p in json.load(sys.stdin) if p.get('idExterno')=='$PEDIDO_IFOOD']
print(ps[0]['id'] if ps else '')" 2>/dev/null)
  [ -n "$ID" ] && break
  sleep 5
done
checa "pedido importado para o painel"       "sim" "$([ -n "$ID" ] && echo sim || echo nao)"
[ -z "$ID" ] && { echo "RESULTADO: $ok PASS / $((fail+1)) FALHA"; exit 1; }

echo "== o pedido chegou com o que a homologacao exige =="
PED=$(curl -s "$API/api/pedidos" -H "$AUTH" | python -c "
import sys,json
print(json.dumps([p for p in json.load(sys.stdin) if p.get('idExterno')=='$PEDIDO_IFOOD'][0]))")
OBS=$(echo "$PED" | python -c "import sys,json;print(json.load(sys.stdin).get('observacao') or '')")
CLI=$(echo "$PED" | python -c "import sys,json;print(json.load(sys.stdin).get('clienteId') or '')")
END=$(curl -s "$API/api/clientes" -H "$AUTH" | python -c "
import sys,json
c=[x for x in json.load(sys.stdin) if str(x['id'])=='$CLI']
print(c[0].get('endereco') or '' if c else '')")
echo "  observacao: $OBS"
echo "  endereco:   $END"
checa "observacao de ENTREGA veio junto"     "sim" "$(echo "$OBS" | grep -qi 'interfone' && echo sim || echo nao)"
checa "observacao do pedido preservada"      "sim" "$(echo "$OBS" | grep -qi 'mock' && echo sim || echo nao)"
checa "complemento no endereco"              "sim" "$(echo "$END" | grep -qi 'apto' && echo sim || echo nao)"
checa "ponto de referencia no endereco"      "sim" "$(echo "$END" | grep -qi 'portao' && echo sim || echo nao)"

echo "== o lojista cancela, com motivo =="
curl -s -o /dev/null -X PATCH "$API/api/pedidos/$ID/status?status=CANCELADO&motivo=item%20indisponivel" -H "$AUTH"
sleep 3
RESP=$(curl -s -H "Authorization: Bearer teste" "$MOCK/_mock/status")
echo "  mock: $RESP"
VERBO=$(echo "$RESP" | python -c "
import sys,json
s=[x for x in json.load(sys.stdin)['statusRecebidos'] if x['verbo']=='requestCancellation']
print(s[-1]['verbo'] if s else 'nenhum')")
MOTIVO=$(echo "$RESP" | python -c "
import sys,json
s=[x for x in json.load(sys.stdin)['statusRecebidos'] if x['verbo']=='requestCancellation']
print(s[-1].get('motivo','') if s else '')")
checa "o iFood recebeu o cancelamento"       "requestCancellation" "$VERBO"
checa "veio COM codigo de motivo"            "506" "$MOTIVO"

echo
echo "RESULTADO: $ok PASS / $fail FALHA"
exit $([ $fail -eq 0 ] && echo 0 || echo 1)
