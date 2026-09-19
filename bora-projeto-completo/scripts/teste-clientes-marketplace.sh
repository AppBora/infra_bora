#!/usr/bin/env bash
# Cadastro de cliente em pedido do iFood: o telefone do iFood e a CENTRAL dele (0800 + codigo), igual
# para todos. Clientes diferentes nao podem virar um so; o mesmo cliente que volta e reconhecido pelo
# id do iFood; a central nao vira telefone do cliente; nao gera cashback (nunca daria para usar).
# Roda DEPOIS do teste-ifood.sh (loja 1 ja conectada ao mock do iFood em :9099).
API=http://localhost:8080
MOCK=http://localhost:9099
ok=0; fail=0
checa() { if [ "$2" = "$3" ]; then echo "  PASS  $1"; ok=$((ok+1)); else echo "  FALHA $1 — esperado [$2], veio [$3]"; fail=$((fail+1)); fi; }
T=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" -d '{"email":"admin@bora.app","senha":"bora123"}' | python -c "import sys,json;print(json.load(sys.stdin)['token'])")
AUTH="Authorization: Bearer $T"

pedido_do_ifood() { # cliente -> id do pedido no Bora
  local oid; oid=$(curl -s -H "Authorization: Bearer teste" "$MOCK/_mock/novo-pedido?merchant=merchant-mock-1&cliente=$1" | python -c "import sys,json;print(json.load(sys.stdin)['orderId'])")
  for n in $(seq 1 12); do
    local id; id=$(curl -s "$API/api/pedidos" -H "$AUTH" | python -c "
import sys,json
ps=[p for p in json.load(sys.stdin) if p.get('idExterno')==sys.argv[1]]
print(ps[0]['id'] if ps else '')" "$oid")
    [ -n "$id" ] && { echo "$id"; return; }; sleep 5
  done
}
cliente_do() { curl -s "$API/api/pedidos" -H "$AUTH" | python -c "
import sys,json
print([p for p in json.load(sys.stdin) if p['id']==int(sys.argv[1])][0].get('clienteId'))" "$1"; }
ficha() { curl -s "$API/api/clientes" -H "$AUTH" | python -c "
import sys,json
c=[x for x in json.load(sys.stdin) if x['id']==int(sys.argv[1])][0]
print(repr(c.get('telefone')), c.get('qtdPedidos'), float(c.get('cashback') or 0))" "$1"; }

SUF=$RANDOM
echo "== dois clientes diferentes do iFood, mesma central 0800 =="
A1=$(pedido_do_ifood "ana-$SUF"); B1=$(pedido_do_ifood "bia-$SUF")
CA=$(cliente_do $A1); CB=$(cliente_do $B1)
checa "pedidos importados" "sim sim" "$([ -n "$A1" ] && echo sim) $([ -n "$B1" ] && echo sim)"
checa "viraram DOIS clientes, nao um" "sim" "$([ -n "$CA" ] && [ "$CA" != "$CB" ] && echo sim || echo nao)"

echo "== a mesma cliente volta e e reconhecida =="
A2=$(pedido_do_ifood "ana-$SUF")
checa "mesmo cliente no 2o pedido" "$CA" "$(cliente_do $A2)"

echo "== cadastro sem a central e sem cashback =="
checa "central do iFood NAO vira telefone; 2 pedidos; cashback 0" "None 2 0.0" "$(ficha $CA)"

echo "== o quadro mostra a central com o codigo (o entregador precisa) =="
FONE=$(curl -s "$API/api/pedidos/board" -H "$AUTH" | python -c "
import sys,json
c=[x for x in json.load(sys.stdin) if x['id']==int(sys.argv[1])]
print(c[0].get('clienteTelefone') if c else '')" "$A2")
checa "telefone do card tem 0800 e codigo" "sim" "$(echo "$FONE" | grep -q '0800' && echo "$FONE" | grep -q 'código' && echo sim || echo nao)"

echo
echo "RESULTADO: $ok PASS / $fail FALHA"
exit $([ $fail -eq 0 ] && echo 0 || echo 1)
