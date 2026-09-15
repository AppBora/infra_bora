#!/usr/bin/env bash
# Excluir pedido de teste: some da lista, leva itens e historico junto e desconta o contador do card
# do marketplace. Roda contra a API local (docker compose), sem precisar de mock.
API=http://localhost:8080
ok=0; fail=0
checa() { if [ "$2" = "$3" ]; then echo "  PASS  $1"; ok=$((ok+1)); else echo "  FALHA $1 — esperado [$2], veio [$3]"; fail=$((fail+1)); fi; }

T=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" -d '{"email":"admin@bora.app","senha":"bora123"}' \
  | python -c "import sys,json;print(json.load(sys.stdin)['token'])")
AUTH="Authorization: Bearer $T"; JSON="Content-Type: application/json"

contador() { curl -s $API/api/integracoes -H "$AUTH" | python -c "
import sys,json
print([c for c in json.load(sys.stdin) if c['canal']=='NOVE_NOVE'][0]['pedidosRecebidos'])"; }

echo "== dois pedidos de teste pelo Simular pedido da 99 =="
curl -s -o /dev/null -X PUT $API/api/integracoes/NOVE_NOVE -H "$JSON" -H "$AUTH" -d '{"merchantId":"loja-excluir","ativo":true}'
WH=$(curl -s $API/api/integracoes -H "$AUTH" | python -c "
import sys,json
print([c for c in json.load(sys.stdin) if c['canal']=='NOVE_NOVE'][0]['webhookPath'])")
ANTES=$(contador)
for n in 1 2; do
  curl -s -o /dev/null -X POST "$API$WH" -H "$JSON" -d "{\"id\":\"teste-excluir-$n-$RANDOM\",\"displayId\":\"77$n\",\"customer\":{\"name\":\"Teste\"},\"total\":{\"orderAmount\":{\"value\":10}},\"items\":[{\"name\":\"X\",\"quantity\":1,\"totalPrice\":{\"value\":10}}]}"
done
checa "contador subiu 2" "$((ANTES+2))" "$(contador)"
ID=$(curl -s "$API/api/pedidos" -H "$AUTH" | python -c "
import sys,json
ps=[p for p in json.load(sys.stdin) if p.get('codigo')=='771']
print(ps[0]['id'] if ps else '')")
checa "pedido de teste esta na lista" "sim" "$([ -n "$ID" ] && echo sim || echo nao)"
curl -s -o /dev/null -X PATCH "$API/api/pedidos/$ID/status?status=EM_PREPARO" -H "$AUTH"

echo "== exclui =="
checa "exclusao aceita" "200" "$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$API/api/pedidos/$ID" -H "$AUTH")"
checa "sumiu da lista" "0" "$(curl -s "$API/api/pedidos" -H "$AUTH" | python -c "
import sys,json;print(len([p for p in json.load(sys.stdin) if p['id']==$ID]))")"
checa "itens nao ficam para tras (pedido nao existe)" "404" "$(curl -s -o /dev/null -w '%{http_code}' "$API/api/pedidos/$ID/itens" -H "$AUTH")"
checa "contador desceu 1" "$((ANTES+1))" "$(contador)"
checa "excluir de novo: nao existe" "404" "$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$API/api/pedidos/$ID" -H "$AUTH")"
checa "sem login: recusado" "401" "$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$API/api/pedidos/1")"

echo "== itens e historico apagados no banco =="
ORFAOS=$(docker exec bora99-postgres-1 psql -U bora -d bora -tAc "select (select count(*) from pedido_item where pedido_id=$ID) + (select count(*) from log_status where pedido_id=$ID)")
checa "nenhum item ou historico orfao" "0" "$ORFAOS"

echo
echo "RESULTADO: $ok PASS / $fail FALHA"
exit $([ $fail -eq 0 ] && echo 0 || echo 1)
