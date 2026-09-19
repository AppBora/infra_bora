#!/usr/bin/env bash
# O que a homologacao do iFood cobra NA TELA do pedido: total certo, complementos e observacao de cada
# item, bandeira do cartao, troco, cupom e quem paga, retirada no balcao (sem "despachado"), entrega
# pelo iFood (sem "despachado", com codigo de coleta) e pedido agendado.
# Roda DEPOIS do teste-ifood.sh (loja 1 ja conectada ao mock do iFood em :9099).
API=http://localhost:8080
MOCK=http://localhost:9099
ok=0; fail=0
checa()  { if [ "$2" = "$3" ]; then echo "  PASS  $1"; ok=$((ok+1)); else echo "  FALHA $1 — esperado [$2], veio [$3]"; fail=$((fail+1)); fi; }
contem() { if printf '%s' "$3" | grep -qF -- "$2"; then echo "  PASS  $1"; ok=$((ok+1)); else echo "  FALHA $1 — [$2] nao aparece em: ${3:0:300}"; fail=$((fail+1)); fi; }
T=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" -d '{"email":"admin@bora.app","senha":"bora123"}' | python -c "import sys,json;print(json.load(sys.stdin)['token'])")
AUTH="Authorization: Bearer $T"

# cria o pedido no mock com os parametros dados e devolve "orderId idNoBora"
pedido() {
  local oid; oid=$(curl -s -H "Authorization: Bearer teste" "$MOCK/_mock/novo-pedido?merchant=merchant-mock-1&$1" | python -c "import sys,json;print(json.load(sys.stdin)['orderId'])")
  for n in $(seq 1 12); do
    local id; id=$(curl -s "$API/api/pedidos" -H "$AUTH" | python -c "
import sys,json
ps=[p for p in json.load(sys.stdin) if p.get('idExterno')==sys.argv[1]]
print(ps[0]['id'] if ps else '')" "$oid")
    [ -n "$id" ] && { echo "$oid $id"; return; }; sleep 5
  done
  echo "$oid "
}
campo() { curl -s "$API/api/pedidos" -H "$AUTH" | python -c "
import sys,json
p=[x for x in json.load(sys.stdin, parse_float=str) if x['id']==int(sys.argv[1])][0]
v=p.get(sys.argv[2]); print('' if v is None else v)" "$1" "$2"; }
itens() { curl -s "$API/api/pedidos/$1/itens" -H "$AUTH"; }
verbos() { curl -s -H "Authorization: Bearer teste" "$MOCK/_mock/status" | python -c "
import sys,json
print(' '.join(s['verbo'] for s in json.load(sys.stdin)['statusRecebidos'] if s['orderId']==sys.argv[1]))" "$1"; }
avancar() { for st in EM_PREPARO PRONTO SAIU_PARA_ENTREGA; do curl -s -o /dev/null -X PATCH "$API/api/pedidos/$1/status?status=$st" -H "$AUTH"; done; sleep 2; }
igual() { python -c "import sys;print('sim' if sys.argv[1] and abs(float(sys.argv[1])-float(sys.argv[2]))<0.005 else 'nao')" "$1" "$2"; }

echo "== cartao online: total, itens com complementos e observacao, bandeira =="
read O1 P1 <<< "$(pedido 'pagamento=ONLINE')"
checa "total certo (itens 73,90 + entrega 7,00)" "sim" "$(igual "$(campo $P1 valorTotal)" 80.9)"
checa "taxa de entrega gravada" "sim" "$(igual "$(campo $P1 taxaEntrega)" 7)"
checa "numero do pedido e o que o cliente ve" "sim" "$(campo $P1 codigo | grep -qE '^1[0-9]{3}$' && echo sim || echo nao)"
IT=$(itens $P1)
contem "complemento do item" "Borda catupiry" "$IT"
contem "observacao do item" "obs: sem cebola" "$IT"
contem "preco do item com complemento" "49.9" "$IT"
contem "bandeira do cartao" "Pago online: Crédito Visa" "$(campo $P1 formaPagamento)"
contem "entrega pela loja" "Entrega pela loja" "$(campo $P1 observacao)"
avancar $P1
checa "entrega da loja: despacho enviado" "confirm startPreparation readyToPickup dispatch" "$(verbos $O1)"

echo "== dinheiro com troco =="
read O2 P2 <<< "$(pedido 'pagamento=CASH&troco=100')"
contem "troco para R\$ 100,00" 'Dinheiro na entrega — troco para R$ 100,00' "$(campo $P2 formaPagamento)"
contem "falta pagar o total" 'falta pagar R$ 80,90' "$(campo $P2 observacao)"

echo "== cartao na entrega (maquininha) =="
read O3 P3 <<< "$(pedido 'pagamento=CARD_OFFLINE')"
contem "cartao na entrega com bandeira" 'Na entrega: Débito Elo (maquininha)' "$(campo $P3 formaPagamento)"

echo "== cupom e quem paga =="
read O4 P4 <<< "$(pedido 'pagamento=ONLINE&cupom=IFOOD')"
contem "cupom pago pelo iFood" 'Cupom R$ 10,00 (pago pelo iFood)' "$(campo $P4 observacao)"
checa "total ja com o desconto" "sim" "$(igual "$(campo $P4 valorTotal)" 70.9)"
read O5 P5 <<< "$(pedido 'pagamento=ONLINE&cupom=MERCHANT')"
contem "cupom pago pela loja" 'Cupom R$ 10,00 (pago pela loja)' "$(campo $P5 observacao)"

echo "== retirada no balcao =="
read O6 P6 <<< "$(pedido 'pagamento=ONLINE&tipo=TAKEOUT')"
contem "card avisa que e retirada" 'RETIRADA NO BALCÃO' "$(campo $P6 observacao)"
avancar $P6
checa "retirada: sem despacho" "confirm startPreparation readyToPickup" "$(verbos $O6)"

echo "== entrega pelo iFood =="
read O7 P7 <<< "$(pedido 'pagamento=ONLINE&entrega=IFOOD')"
contem "card avisa entrega do iFood" 'Entrega pelo iFood' "$(campo $P7 observacao)"
contem "codigo de coleta para o entregador" 'Código de coleta 4321' "$(campo $P7 observacao)"
avancar $P7
checa "entrega do iFood: sem despacho" "confirm startPreparation readyToPickup" "$(verbos $O7)"

echo "== agendado =="
read O8 P8 <<< "$(pedido 'pagamento=ONLINE&agendado=1')"
contem "card avisa o agendamento" 'AGENDADO para' "$(campo $P8 observacao)"

echo
echo "RESULTADO: $ok PASS / $fail FALHA"
exit $([ $fail -eq 0 ] && echo 0 || echo 1)
