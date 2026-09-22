#!/usr/bin/env bash
# Checklist de homologacao da 99Food (pag. 27 do roteiro) contra o mock-99food.js, que foi escrito
# a partir da especificacao Open Delivery v1.7.1 e do roteiro da 99 — nao a partir do nosso codigo.
#
# Criterio que manda: no fim, a lista de RECUSAS do mock tem que estar vazia. Um PASS nosso com a
# "99" recusando o que mandamos nao vale nada.
#
# Pre-requisitos: mock em :9199 e API em :8080 apontada para ele
#   BORA_OPENDELIVERY_BASE_URL=http://host.docker.internal:9199
#   BORA_OPENDELIVERY_CLIENT_ID=mock-app  BORA_OPENDELIVERY_CLIENT_SECRET=mock-secret
API=http://localhost:8080
MOCK=http://localhost:9199
SHOP=loja-teste-1
ok=0; fail=0

checa()  { if [ "$2" = "$3" ]; then echo "  PASS  $1"; ok=$((ok+1)); else echo "  FALHA $1 — esperado [$2], veio [$3]"; fail=$((fail+1)); fi; }
contem() { if printf '%s' "$3" | grep -qF -- "$2"; then echo "  PASS  $1"; ok=$((ok+1)); else echo "  FALHA $1 — [$2] nao aparece em: ${3:0:300}"; fail=$((fail+1)); fi; }
nao_contem() { if printf '%s' "$3" | grep -qF -- "$2"; then echo "  FALHA $1 — [$2] nao devia aparecer em: ${3:0:300}"; fail=$((fail+1)); else echo "  PASS  $1"; ok=$((ok+1)); fi; }
mesmo_valor() { python -c "import sys; a,b=sys.argv[1],sys.argv[2]; print('sim' if a and b and abs(float(a)-float(b))<0.005 else 'nao')" "$1" "$2"; }

T=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" -d '{"email":"admin@bora.app","senha":"bora123"}' \
  | python -c "import sys,json;print(json.load(sys.stdin)['token'])")
[ -z "$T" ] && { echo "sem token da API"; exit 1; }
AUTH="Authorization: Bearer $T"; JSON="Content-Type: application/json"
SUPER=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" -d '{"email":"super@local.test","senha":"local-teste-1234"}' | python -c "import sys,json;print(json.load(sys.stdin).get('token',''))")
acessar() { curl -s -X POST "$API/admin-bora/lojas/$1/acessar" -H "Authorization: Bearer $SUPER" | python -c "import sys,json;print(json.load(sys.stdin).get('token',''))"; }
PLAT=$(acessar 1)
[ -z "$PLAT" ] && { echo "sem token da plataforma — suba a API com SUPERADMIN_EMAIL/SENHA"; exit 1; }

# pedido do painel pelo id que a 99 deu (espera o polling por ate 60s)
pedido_local() {
  for n in $(seq 1 20); do
    R=$(curl -s "$API/api/pedidos" -H "$AUTH" | python -c "
import sys,json
ps=[p for p in json.load(sys.stdin, parse_float=str) if p.get('idExterno')==sys.argv[1]]
print(json.dumps(ps[0]) if ps else '')" "$1")
    [ -n "$R" ] && { echo "$R"; return; }
    sleep 3
  done
}
campo() { printf '%s' "$1" | python -c "import sys,json;d=json.load(sys.stdin, parse_float=str) if sys.stdin else {};v=d.get(sys.argv[1]);print('' if v is None else v)" "$2" 2>/dev/null; }
novo_pedido() { curl -s "$MOCK/_mock/novo-pedido?shop=$SHOP&entrega=$1&pagamento=$2" | python -c "import sys,json;print(json.load(sys.stdin)['orderId'])"; }
verbos_do() { curl -s "$MOCK/_mock/status" | python -c "
import sys,json
print(' '.join(r['verbo'] for r in json.load(sys.stdin)['recebidos'] if r.get('orderId')==sys.argv[1]))" "$1"; }
mudar_status() { curl -s -o /dev/null -X PATCH "$API/api/pedidos/$1/status?status=$2&motivo=$3" -H "$AUTH"; }

card99() { curl -s $API/api/integracoes -H "$AUTH" | python -c "
import sys,json
for c in json.load(sys.stdin):
    if c['canal']=='NOVE_NOVE': print(c['status'], c.get('recebendo'))"; }

echo "== 0. o card nao diz conectado sem a 99 ter aceitado a loja =="
curl -s -o /dev/null -X PUT $API/api/integracoes/NOVE_NOVE -H "$JSON" -H "Authorization: Bearer $PLAT" -d "{\"merchantId\":\"$SHOP\",\"ativo\":true}"
checa "chave ligada, sem conectar" "PRONTO False" "$(card99)"
WH=$(curl -s $API/api/integracoes -H "$AUTH" | python -c "
import sys,json
print([c for c in json.load(sys.stdin) if c['canal']=='NOVE_NOVE'][0]['webhookPath'])")
curl -s -o /dev/null -X POST "$API$WH" -H "$JSON" -d '{"id":"simulado-1","displayId":"9001","customer":{"name":"Teste"},"total":{"orderAmount":{"value":10}},"items":[{"name":"X","quantity":1,"totalPrice":{"value":10}}]}'
checa "pedido simulado nao vira conectado" "PRONTO False" "$(card99)"

echo "== 1. vinculo: token por loja em form-urlencoded, client_id = app_id + app shop id =="
curl -s -o /dev/null -X POST $API/api/integracoes/NOVE_NOVE/vincular -H "$AUTH"
checa "conexao com a 99 validada" "CONECTADO True" "$(card99)"

echo "== 1b. o codigo da loja na 99 e definido pela plataforma =="
checa "lojista NAO troca o App Shop ID" "403" "$(curl -s -o /dev/null -w '%{http_code}' -X PUT $API/api/integracoes/NOVE_NOVE -H "$JSON" -H "$AUTH" -d '{"merchantId":"loja-de-outro","ativo":true}')"
checa "lojista salva o card sem trocar o codigo" "200" "$(curl -s -o /dev/null -w '%{http_code}' -X PUT $API/api/integracoes/NOVE_NOVE -H "$JSON" -H "$AUTH" -d "{\"merchantId\":\"$SHOP\",\"ativo\":true}")"
checa "e a loja CONTINUA conectada" "CONECTADO True" "$(card99)"
L2=$(curl -s -X POST $API/admin-bora/lojas -H "$JSON" -H "Authorization: Bearer $SUPER" -d "{\"nomeLoja\":\"Outra Loja $RANDOM\",\"adminEmail\":\"outra-$RANDOM@local.test\",\"adminSenha\":\"senha123\"}" | python -c "import sys,json;print(json.load(sys.stdin).get('lojaId',''))")
PL2=$(acessar $L2)
checa "mesmo codigo em OUTRA loja: recusado" "409" "$(curl -s -o /dev/null -w '%{http_code}' -X PUT $API/api/integracoes/NOVE_NOVE -H "$JSON" -H "Authorization: Bearer $PL2" -d "{\"merchantId\":\"$SHOP\",\"ativo\":true}")"

echo "== 2. pedido com entrega da LOJA e pagamento em DINHEIRO =="
O1=$(novo_pedido MERCHANT CASH)
P1=$(pedido_local "$O1")
checa "pedido importado pelo polling (eventId + CREATED)" "sim" "$([ -n "$P1" ] && echo sim || echo nao)"
ID1=$(campo "$P1" id)
checa "numero do pedido e o displayId, nao o UUID" "sim" "$(campo "$P1" codigo | grep -qE '^4[0-9]{3}$' && echo sim || echo nao)"
checa "total = itens 47 + taxa 7 - desconto 5" "sim" "$(mesmo_valor "$(campo "$P1" valorTotal)" 49)"
checa "taxa de entrega gravada no pedido" "sim" "$(mesmo_valor "$(campo "$P1" taxaEntrega)" 7)"
contem "pagamento em dinheiro, com troco" 'troco para R$ 100,00' "$(campo "$P1" formaPagamento)"
OBS1=$(campo "$P1" observacao)
contem "observacao: numero do pedido" 'Pedido 99 #' "$OBS1"
contem "observacao: quem entrega" 'Entrega pela loja' "$OBS1"
contem "observacao: texto do cliente" 'Tocar a campainha duas vezes' "$OBS1"
contem "observacao: desconto e quem pagou" 'Desconto R$ 5,00 (pago pela 99)' "$OBS1"
contem "observacao: falta pagar" 'falta pagar R$ 49,00' "$OBS1"
ITENS=$(curl -s "$API/api/pedidos/$ID1/itens" -H "$AUTH")
contem "item com opcional" 'Leite em po' "$ITENS"
contem "item com observacao do cliente" 'sem granola' "$ITENS"
CLI=$(curl -s "$API/api/clientes" -H "$AUTH")
contem "cliente com complemento" "Ap $(( $(campo "$P1" codigo) - 4200 ))" "$CLI"
contem "cliente com ponto de referencia" 'em frente a praca' "$CLI"
contem "aceite automatico enviado" 'confirm' "$(verbos_do "$O1")"

echo "== 3. entrega da LOJA: preparing > readyForPickup > dispatch > delivered =="
mudar_status "$ID1" EM_PREPARO; mudar_status "$ID1" PRONTO
mudar_status "$ID1" SAIU_PARA_ENTREGA; mudar_status "$ID1" ENTREGUE
sleep 2
checa "verbos na ordem certa" "confirm preparing readyForPickup dispatch delivered" "$(verbos_do "$O1")"

echo "== 4. entrega da 99: sempre pago, e a loja para em readyForPickup =="
O2=$(novo_pedido MARKETPLACE CASH)
P2=$(pedido_local "$O2")
ID2=$(campo "$P2" id)
contem "entrega da 99 conta como pago" 'Pago online (99Food)' "$(campo "$P2" formaPagamento)"
contem "observacao: entrega pela 99" 'Entrega pela 99' "$(campo "$P2" observacao)"
contem "falta pagar zero" 'falta pagar R$ 0,00' "$(campo "$P2" observacao)"
mudar_status "$ID2" PRONTO; mudar_status "$ID2" SAIU_PARA_ENTREGA; mudar_status "$ID2" ENTREGUE
sleep 2
checa "dispatch e delivered nao enviados" "confirm readyForPickup" "$(verbos_do "$O2")"

echo "== 4b. RETIRADA no balcao (aviso da 99 de 22/09): sem entrega, e o fim e pickedUp =="
O8=$(novo_pedido TAKEOUT ONLINE)
P8=$(pedido_local "$O8")
ID8=$(campo "$P8" id)
checa "pedido de retirada entrou" "sim" "$([ -n "$ID8" ] && echo sim || echo nao)"
contem "card avisa que e retirada" 'RETIRADA NO BALCÃO' "$(campo "$P8" observacao)"
contem "hora que o cliente vem buscar" 'cliente vem buscar' "$(campo "$P8" observacao)"
nao_contem "nao manda a loja entregar" 'Entrega pela loja' "$(campo "$P8" observacao)"
checa "total sem taxa de entrega (47 - 5)" "sim" "$(mesmo_valor "$(campo "$P8" valorTotal)" 42)"
mudar_status "$ID8" EM_PREPARO; mudar_status "$ID8" PRONTO
mudar_status "$ID8" SAIU_PARA_ENTREGA; mudar_status "$ID8" ENTREGUE
sleep 2
checa "retirada: sem dispatch/delivered, fecha com pickedUp" "confirm preparing readyForPickup pickedUp" "$(verbos_do "$O8")"

echo "== 5. cancelamento pela LOJA: reason + code da lista + mode =="
O3=$(novo_pedido MERCHANT ONLINE)
P3=$(pedido_local "$O3"); ID3=$(campo "$P3" id)
mudar_status "$ID3" CANCELADO "acabou%20o%20item%20no%20estoque"
sleep 2
CANC=$(curl -s "$MOCK/_mock/status" | python -c "
import sys,json
c=[r for r in json.load(sys.stdin)['recebidos'] if r.get('orderId')==sys.argv[1] and r.get('verbo')=='requestCancellation']
print((c[-1]['corpo'].get('code') or '')+'|'+(c[-1]['corpo'].get('mode') or '') if c else 'nenhum')" "$O3")
checa "cancelamento com codigo e modo" "UNAVAILABLE_ITEM|MANUAL" "$CANC"
sleep 8
checa "o CANCELLED que volta nao quebra nada" "CANCELADO" "$(campo "$(pedido_local "$O3")" status)"

echo "== 6. o cliente cancelou no app da 99 =="
O4=$(novo_pedido MERCHANT ONLINE)
P4=$(pedido_local "$O4")
curl -s -o /dev/null "$MOCK/_mock/cliente-cancelou?pedido=$O4"
for n in $(seq 1 10); do P4=$(pedido_local "$O4"); [ "$(campo "$P4" status)" = "CANCELADO" ] && break; sleep 3; done
checa "pedido cancelado no painel" "CANCELADO" "$(campo "$P4" status)"
contem "motivo do cliente aparece" 'Cliente desistiu' "$(campo "$P4" motivoCancelamento)"

echo "== 7. o cliente PEDE para cancelar e a loja responde =="
O5=$(novo_pedido MERCHANT ONLINE)
P5=$(pedido_local "$O5")
curl -s -o /dev/null "$MOCK/_mock/cliente-pede-cancelamento?pedido=$O5"
for n in $(seq 1 10); do verbos_do "$O5" | grep -q acceptCancellation && break; sleep 3; done
contem "pedido ainda nao preparado: aceita" 'acceptCancellation' "$(verbos_do "$O5")"
checa "e cancela no painel" "CANCELADO" "$(campo "$(pedido_local "$O5")" status)"

O7=$(novo_pedido MERCHANT ONLINE)
P7=$(pedido_local "$O7"); ID7=$(campo "$P7" id)
mudar_status "$ID7" PRONTO
curl -s -o /dev/null "$MOCK/_mock/cliente-pede-cancelamento?pedido=$O7"
for n in $(seq 1 10); do verbos_do "$O7" | grep -q denyCancellation && break; sleep 3; done
NEG=$(curl -s "$MOCK/_mock/status" | python -c "
import sys,json
c=[r for r in json.load(sys.stdin)['recebidos'] if r.get('orderId')==sys.argv[1] and r.get('verbo')=='denyCancellation']
print(c[-1]['corpo'].get('code') if c else 'nenhuma')" "$O7")
checa "pedido ja pronto: nega com o motivo certo" "DISH_ALREADY_DONE" "$NEG"
checa "e continua pronto no painel" "PRONTO" "$(campo "$(pedido_local "$O7")" status)"

echo "== 8. webhook POST /v1/newEvent com assinatura HMAC-SHA256 =="
O6=$(novo_pedido MERCHANT ONLINE)
DEST="$API/public/opendelivery/v1/newEvent"
st() { python -c "import sys,json;print(json.load(sys.stdin).get('status'))"; }
checa "assinatura certa: processado" "204" "$(curl -s -X POST "$MOCK/_mock/webhook?destino=$DEST&pedido=$O6" | st)"
checa "assinatura errada: recusado"  "403" "$(curl -s -X POST "$MOCK/_mock/webhook?destino=$DEST&pedido=$O6&assinatura=errada" | st)"
checa "loja desconhecida"            "404" "$(curl -s -X POST "$MOCK/_mock/webhook?destino=$DEST&pedido=$O6&shop=loja-que-nao-existe" | st)"

echo "== 9. o que a 99 recusou do que mandamos =="
sleep 7
FIM=$(curl -s "$MOCK/_mock/status")
checa "todos os eventos confirmados (acknowledgment aceito)" "0" "$(printf '%s' "$FIM" | python -c "import sys,json;print(json.load(sys.stdin)['eventosPendentes'])")"
NREC=$(printf '%s' "$FIM" | python -c "import sys,json;print(len(json.load(sys.stdin)['recusas']))")
checa "nenhuma recusa da 99" "0" "$NREC"
printf '%s' "$FIM" | python -c "
import sys,json
for x in json.load(sys.stdin)['recusas']:
    print('     ->', x['code'], x['motivo'], {k:v for k,v in x.items() if k not in ('code','motivo','em')})"

echo
echo "RESULTADO: $ok PASS / $fail FALHA"
exit $([ $fail -eq 0 ] && echo 0 || echo 1)
