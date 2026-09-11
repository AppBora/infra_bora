#!/usr/bin/env bash
# Prova a corrente inteira: KYC aprovado no Asaas -> asaasStatus ATIVO -> PIX visivel no cardapio.
# Sem isto, a promessa "o PIX aparece sozinho quando aprovar" era so teoria minha.
API=http://localhost:8080
MOCK=http://localhost:8099
ok=0; fail=0
checa() { if [ "$2" = "$3" ]; then echo "  PASS  $1 ($3)"; ok=$((ok+1)); else echo "  FALHA $1 — esperado $2, veio $3"; fail=$((fail+1)); fi; }
pix() { curl -s "$API/public/loja/1/cardapio" | python -c "import sys,json;print(json.load(sys.stdin)['pixDisponivel'])"; }
status() { curl -s "$API/api/recebimento" -H "Authorization: Bearer $1" | python -c "import sys,json;print(json.load(sys.stdin)['status'])"; }

T=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" -d '{"email":"admin@bora.app","senha":"bora123"}' | python -c "import sys,json;print(json.load(sys.stdin)['token'])")
[ -z "$T" ] && { echo "sem token"; exit 1; }

echo "== antes de ativar o recebimento =="
checa "cardapio NAO oferece PIX"            "False" "$(pix)"

echo "== ativa o recebimento (cria a subconta) =="
curl -s -o /dev/null -X POST $API/api/recebimento/ativar -H "Content-Type: application/json" -H "Authorization: Bearer $T" \
  -d '{"cpfCnpj":"53953786000128","mobilePhone":"15981034318","postalCode":"18074760","address":"Rua Teste","addressNumber":"1","province":"Centro","companyType":"MEI","incomeValue":3000}'
checa "conta criada, mas KYC pendente"      "PENDENTE" "$(status $T)"
checa "cardapio SEGUE sem PIX (KYC pendente)" "False" "$(pix)"

echo "== o Asaas aprova o KYC =="
curl -s -o /dev/null -X POST $MOCK/__aprovar
checa "a tela de recebimento ve a aprovacao" "ATIVO" "$(status $T)"
checa "o cardapio passa a oferecer PIX"      "True"  "$(pix)"

echo
echo "RESULTADO: $ok PASS / $fail FALHA"
exit $([ $fail -eq 0 ] && echo 0 || echo 1)
