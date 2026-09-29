#!/usr/bin/env bash
# Uma loja nao pode ver nem mexer no que e de outra, e o webhook de pagamento nao aceita token errado.
# O isolamento existe no codigo (findByIdAndLojaId em toda parte), mas nada provava que continua
# existindo — e e o tipo de coisa que quebra em silencio num refactor. Criado em 29/09/2026.
#
# Pre-requisito: API em :8080 com SUPERADMIN_EMAIL/SENHA (a loja nova nasce pelo painel da plataforma).
API=http://localhost:8080
ok=0; fail=0
checa() { if [ "$2" = "$3" ]; then echo "  PASS  $1"; ok=$((ok+1)); else echo "  FALHA $1 — esperado [$2], veio [$3]"; fail=$((fail+1)); fi; }
codigo() { curl -s -o /dev/null -w "%{http_code}" "$@"; }
json() { python -c "import sys,json;d=json.load(sys.stdin);print(d.get(sys.argv[1],''))" "$1"; }

SUPER=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" \
  -d '{"email":"super@local.test","senha":"local-teste-1234"}' | json token)
[ -z "$SUPER" ] && { echo "sem token do superadmin — suba a API com SUPERADMIN_EMAIL/SENHA"; exit 1; }

A=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" \
  -d '{"email":"admin@bora.app","senha":"bora123"}' | json token)
[ -z "$A" ] && { echo "sem token da loja 1"; exit 1; }
AUTH_A="Authorization: Bearer $A"

# ---- loja B, com dono proprio (o painel da plataforma cria loja + administrador juntos) ----
EMAIL_B="dono.lojab@teste.local"
curl -s -o /dev/null -X POST $API/admin-bora/lojas -H "Authorization: Bearer $SUPER" -H "Content-Type: application/json" \
  -d "{\"nomeLoja\":\"Loja B do teste\",\"documento\":\"11222333000199\",\"adminNome\":\"Dono B\",\"adminEmail\":\"$EMAIL_B\",\"adminSenha\":\"teste12345\"}"
B=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL_B\",\"senha\":\"teste12345\"}" | json token)
[ -z "$B" ] && { echo "nao consegui criar/entrar na loja B"; exit 1; }
AUTH_B="Authorization: Bearer $B"

echo "== cada loja enxerga so o que e dela =="
PROD_A=$(curl -s -X POST $API/api/produtos -H "$AUTH_A" -H "Content-Type: application/json" \
  -d '{"nome":"Produto so da loja A","preco":10.5,"categoria":"Teste"}' | json id)
CLI_A=$(curl -s -X POST $API/api/clientes -H "$AUTH_A" -H "Content-Type: application/json" \
  -d '{"nome":"Cliente so da loja A","telefone":"62911110000","bairro":"Centro"}' | json id)
PED_A=$(curl -s -X POST $API/api/pedidos -H "$AUTH_A" -H "Content-Type: application/json" \
  -d "{\"codigo\":\"ISO-1\",\"formaPagamento\":\"Dinheiro\",\"origem\":\"Balcao\",\"itens\":[{\"produtoId\":$PROD_A,\"quantidade\":1}]}" | json id)
checa "loja A criou produto, cliente e pedido" "sim" "$([ -n "$PROD_A" ] && [ -n "$CLI_A" ] && [ -n "$PED_A" ] && echo sim || echo nao)"

echo "== loja B tentando alcancar os dados da loja A =="
checa "B NAO ve os itens do pedido de A" "404" "$(codigo "$API/api/pedidos/$PED_A/itens" -H "$AUTH_B")"
checa "B NAO muda o status do pedido de A" "404" "$(codigo -X PATCH "$API/api/pedidos/$PED_A/status?status=EM_PREPARO" -H "$AUTH_B")"
checa "B NAO exclui o pedido de A"      "404" "$(codigo -X DELETE "$API/api/pedidos/$PED_A" -H "$AUTH_B")"
checa "B NAO edita o produto de A"      "404" "$(codigo -X PUT "$API/api/produtos/$PROD_A" -H "$AUTH_B" -H "Content-Type: application/json" -d '{"nome":"invadido","preco":1}')"
checa "B NAO exclui o cliente de A"     "404" "$(codigo -X DELETE "$API/api/clientes/$CLI_A" -H "$AUTH_B")"

echo "== a lista de cada loja nao vaza a outra =="
VAZOU=$(curl -s "$API/api/clientes" -H "$AUTH_B" | python -c "
import sys,json
print('sim' if any('loja A' in (c.get('nome') or '') for c in json.load(sys.stdin)) else 'nao')")
checa "cliente de A nao aparece na lista de B" "nao" "$VAZOU"
VAZOU2=$(curl -s "$API/api/pedidos/board" -H "$AUTH_B" | python -c "
import sys,json
d=json.load(sys.stdin)
ps=d if isinstance(d,list) else d.get('pedidos',[])
print('sim' if any(str(p.get('codigo'))=='ISO-1' for p in ps) else 'nao')" 2>/dev/null || echo nao)
checa "pedido de A nao aparece no quadro de B" "nao" "$VAZOU2"

echo "== o pedido de A continua intacto depois das tentativas =="
checa "pedido de A ainda existe para A" "200" "$(codigo "$API/api/pedidos/$PED_A/itens" -H "$AUTH_A")"

echo "== webhook de pagamento nao aceita token errado =="
checa "sem token"        "401" "$(codigo -X POST "$API/public/pix-webhook/1" -H "Content-Type: application/json" -d '{"event":"PAYMENT_RECEIVED"}')"
checa "token inventado"  "401" "$(codigo -X POST "$API/public/pix-webhook/1" -H "asaas-access-token: token-de-mentira" -H "Content-Type: application/json" -d '{"event":"PAYMENT_RECEIVED"}')"
checa "loja inexistente" "404" "$(codigo -X POST "$API/public/pix-webhook/999999" -H "asaas-access-token: x" -H "Content-Type: application/json" -d '{"event":"PAYMENT_RECEIVED"}')"

echo
echo "RESULTADO: $ok PASS / $fail FALHA"
exit $([ $fail -eq 0 ] && echo 0 || echo 1)
