#!/usr/bin/env bash
# O que um funcionario comum (OPERADOR) NAO pode fazer. A revisao de 24/09 mostrou que o relatorio
# financeiro (faturamento, CMV, margem, lucro) estava aberto para qualquer usuario da loja — as telas
# irmas (desempenho, balancete) ja barravam. Este teste tranca isso.
API=http://localhost:8080
ok=0; fail=0
checa() { if [ "$2" = "$3" ]; then echo "  PASS  $1"; ok=$((ok+1)); else echo "  FALHA $1 — esperado [$2], veio [$3]"; fail=$((fail+1)); fi; }
codigo() { curl -s -o /dev/null -w "%{http_code}" "$@"; }

T=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" -d '{"email":"admin@bora.app","senha":"bora123"}' \
  | python -c "import sys,json;print(json.load(sys.stdin)['token'])")
[ -z "$T" ] && { echo "sem token do admin da loja"; exit 1; }

# cria (ou reaproveita) o funcionario comum
curl -s -o /dev/null -X POST $API/api/usuarios -H "Authorization: Bearer $T" -H "Content-Type: application/json" \
  -d '{"nome":"Atendente do teste","email":"atendente.teste@bora.local","senha":"teste12345","papel":"OPERADOR"}'
TA=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" \
  -d '{"email":"atendente.teste@bora.local","senha":"teste12345"}' | python -c "import sys,json;print(json.load(sys.stdin).get('token',''))")
[ -z "$TA" ] && { echo "sem token do atendente"; exit 1; }
AT="Authorization: Bearer $TA"; AD="Authorization: Bearer $T"

echo "== numeros do dono: so administrador da loja e gerente =="
checa "atendente NAO ve o relatorio financeiro" "403" "$(codigo "$API/api/relatorios?dias=30" -H "$AT")"
checa "administrador da loja ve"                "200" "$(codigo "$API/api/relatorios?dias=30" -H "$AD")"
checa "atendente NAO ve o desempenho"           "403" "$(codigo "$API/api/desempenho" -H "$AT")"

echo "== cadastro e equipe =="
checa "atendente NAO cria produto" "403" "$(codigo -X POST $API/api/produtos -H "$AT" -H "Content-Type: application/json" -d '{"nome":"X","preco":1}')"
checa "atendente NAO lista equipe" "403" "$(codigo "$API/api/usuarios" -H "$AT")"
checa "atendente NAO cria usuario" "403" "$(codigo -X POST $API/api/usuarios -H "$AT" -H "Content-Type: application/json" -d '{"nome":"Y","email":"y@t.local","senha":"12345678","papel":"OPERADOR"}')"

echo "== o que e da plataforma continua fechado para a loja inteira =="
checa "admin da loja NAO entra no painel da plataforma" "403" "$(codigo "$API/admin-bora/clientes" -H "$AD")"
checa "atendente NAO entra no painel da plataforma"     "403" "$(codigo "$API/admin-bora/clientes" -H "$AT")"
checa "atendente NAO ve credencial de marketplace"      "403" "$(codigo "$API/admin-bora/credenciais" -H "$AT")"

echo
echo "RESULTADO: $ok PASS / $fail FALHA"
exit $([ $fail -eq 0 ] && echo 0 || echo 1)
