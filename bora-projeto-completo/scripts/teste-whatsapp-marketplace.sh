#!/usr/bin/env bash
# O aviso de WhatsApp ao cliente (Operacao Assistida) NAO vai para pedido de marketplace: o telefone ali
# e a central do marketplace. Pedido feito no proprio Bora continua avisando.
# Roda DEPOIS do teste-ifood.sh (loja 1 ja conectada ao mock do iFood), com superadmin e mock em :9099.
# Prova pelos logs da API: cada tentativa de envio deixa "WhatsApp loja 1" (o token e falso, a Meta recusa).
API=http://localhost:8080
MOCK=http://localhost:9099
CONTAINER=bora99-api-1
ok=0; fail=0
checa() { if [ "$2" = "$3" ]; then echo "  PASS  $1"; ok=$((ok+1)); else echo "  FALHA $1 — esperado [$2], veio [$3]"; fail=$((fail+1)); fi; }
JSON="Content-Type: application/json"
token() { curl -s -X POST "$API/auth/login" -H "$JSON" -d "{\"email\":\"$1\",\"senha\":\"$2\"}" | python -c "import sys,json;print(json.load(sys.stdin).get('token',''))"; }
T=$(token admin@bora.app bora123); S=$(token super@local.test local-teste-1234)
AUTH="Authorization: Bearer $T"
tentativas() { docker logs $CONTAINER 2>&1 | grep -c "WhatsApp loja 1"; }
campo() { python -c "import sys,json;print(json.load(sys.stdin).get(sys.argv[1],''))" "$1"; }

echo "== liga a Operacao Assistida na loja 1 (Modulo IA + WhatsApp) =="
curl -s -o /dev/null -X PUT $API/admin-bora/lojas/1/modulo-ia -H "$JSON" -H "Authorization: Bearer $S" -d '{"habilitado":true}'
curl -s -o /dev/null -X PUT $API/api/integracoes/WHATSAPP -H "$JSON" -H "$AUTH" -d '{"clientId":"123456789012345","clientSecret":"token-falso","ativo":true}'

echo "== controle: pedido feito no Bora avisa o cliente =="
CLI=$(curl -s -X POST $API/api/clientes -H "$JSON" -H "$AUTH" -d '{"nome":"Cliente Zap","telefone":"15999990000"}' | campo id)
PROD=$(curl -s -X POST $API/api/produtos -H "$JSON" -H "$AUTH" -d '{"nome":"Item Zap","preco":10,"ativo":true}' | campo id)
PED=$(curl -s -X POST $API/api/pedidos -H "$JSON" -H "$AUTH" -d "{\"clienteId\":$CLI,\"formaPagamento\":\"Dinheiro\",\"origem\":\"Balcao\",\"itens\":[{\"produtoId\":$PROD,\"quantidade\":1}]}" | campo id)
checa "pedido do Bora criado" "sim" "$([ -n "$PED" ] && echo sim || echo nao)"
ANTES=$(tentativas)
curl -s -o /dev/null -X PATCH "$API/api/pedidos/$PED/status?status=EM_PREPARO" -H "$AUTH"
sleep 3
checa "pedido do Bora TENTA avisar no WhatsApp" "sim" "$([ "$(tentativas)" -gt "$ANTES" ] && echo sim || echo nao)"

echo "== pedido do iFood NAO avisa =="
OID=$(curl -s -H "Authorization: Bearer teste" "$MOCK/_mock/novo-pedido?merchant=merchant-mock-1" | campo orderId)
for n in $(seq 1 12); do
  ID=$(curl -s "$API/api/pedidos" -H "$AUTH" | python -c "
import sys,json
ps=[p for p in json.load(sys.stdin) if p.get('idExterno')==sys.argv[1]]
print(ps[0]['id'] if ps else '')" "$OID")
  [ -n "$ID" ] && break; sleep 5
done
checa "pedido do iFood importado" "sim" "$([ -n "$ID" ] && echo sim || echo nao)"
ANTES=$(tentativas)
for st in EM_PREPARO PRONTO SAIU_PARA_ENTREGA ENTREGUE; do
  curl -s -o /dev/null -X PATCH "$API/api/pedidos/$ID/status?status=$st" -H "$AUTH"
done
sleep 3
checa "nenhuma tentativa de WhatsApp no pedido do iFood" "$ANTES" "$(tentativas)"

echo
echo "RESULTADO: $ok PASS / $fail FALHA"
exit $([ $fail -eq 0 ] && echo 0 || echo 1)
