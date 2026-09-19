#!/usr/bin/env bash
# Credenciais dos marketplaces coladas pela tela da plataforma (Configuracoes -> Plataforma).
# Uso: teste-credenciais.sh salvar   -> confere regras e salva as credenciais dos mocks (iFood e 99)
#      teste-credenciais.sh apagar   -> apaga e confere que o app volta a ficar sem credencial
# Instancia LOCAL descartavel com superadmin e SEM credencial no ambiente:
#   SUPERADMIN_EMAIL=super@local.test SUPERADMIN_SENHA=local-teste-1234
API=http://localhost:8080
ok=0; fail=0
checa() { if [ "$2" = "$3" ]; then echo "  PASS  $1"; ok=$((ok+1)); else echo "  FALHA $1 — esperado [$2], veio [$3]"; fail=$((fail+1)); fi; }
JSON="Content-Type: application/json"
token() { curl -s -X POST "$API/auth/login" -H "$JSON" -d "{\"email\":\"$1\",\"senha\":\"$2\"}" \
  | python -c "import sys,json;print(json.load(sys.stdin).get('token',''))" 2>/dev/null; }
S=$(token super@local.test local-teste-1234); L=$(token admin@bora.app bora123)
[ -z "$S" ] && { echo "SEM TOKEN DE SUPERADMIN"; exit 1; }
cod() { curl -s -o /dev/null -w '%{http_code}' -X "$1" "$API$2" -H "$JSON" ${3:+-H "Authorization: Bearer $3"} ${4:+-d "$4"}; }
app_da_loja() { curl -s "$API/api/integracoes" -H "Authorization: Bearer $L" | python -c "
import sys,json
print(' '.join(str(c.get('appConfigurado')) for c in json.load(sys.stdin) if c['canal'] in ('IFOOD','NOVE_NOVE')))"; }
lista() { curl -s "$API/admin-bora/credenciais" -H "Authorization: Bearer $S"; }

if [ "$1" = "salvar" ]; then
  echo "== sem credencial nenhuma =="
  checa "iFood e 99 sem app na tela da loja" "False False" "$(app_da_loja)"
  checa "lista mostra 'nao configurado'" "None None" "$(lista | python -c "import sys,json;print(' '.join(str(c['origem']) for c in json.load(sys.stdin)))")"

  echo "== quem pode =="
  checa "sem login"               "401" "$(cod PUT /admin-bora/credenciais/IFOOD '' '{"clientId":"x","clientSecret":"y"}')"
  checa "admin de LOJA nao pode"  "403" "$(cod PUT /admin-bora/credenciais/IFOOD "$L" '{"clientId":"x","clientSecret":"y"}')"
  checa "admin de LOJA nao lista" "403" "$(cod GET /admin-bora/credenciais "$L")"

  echo "== validacao =="
  checa "marketplace sem credencial de plataforma" "400" "$(cod PUT /admin-bora/credenciais/RAPPI "$S" '{"clientId":"x","clientSecret":"y"}')"
  checa "sem Client ID"                           "400" "$(cod PUT /admin-bora/credenciais/IFOOD "$S" '{"clientSecret":"y"}')"
  checa "1a vez sem segredo"                      "400" "$(cod PUT /admin-bora/credenciais/IFOOD "$S" '{"clientId":"x"}')"

  echo "== salvar =="
  checa "iFood salvo" "200" "$(cod PUT /admin-bora/credenciais/IFOOD "$S" '{"clientId":"mock-client","clientSecret":"mock-secret"}')"
  checa "99 salvo"    "200" "$(cod PUT /admin-bora/credenciais/NOVE_NOVE "$S" '{"clientId":"mock-app","clientSecret":"mock-secret"}')"
  checa "sem segredo agora mantem o salvo" "200" "$(cod PUT /admin-bora/credenciais/IFOOD "$S" '{"clientId":"mock-client","clientSecret":""}')"
  checa "lista: salvas pela tela" "TELA:True TELA:True" "$(lista | python -c "import sys,json;print(' '.join(str(c['origem'])+':'+str(c['temSecret']) for c in json.load(sys.stdin)))")"
  checa "o SEGREDO nunca volta na lista"          "0" "$(lista | grep -c mock-secret)"
  checa "nem na lista geral de configuracoes"     "0" "$(curl -s $API/admin-bora/config -H "Authorization: Bearer $S" | grep -c mock-secret)"
  checa "nem na tela de integracoes da loja"      "0" "$(curl -s $API/api/integracoes -H "Authorization: Bearer $L" | grep -c mock-secret)"
  checa "tela da loja passa a ver o app"          "True True" "$(app_da_loja)"
fi

if [ "$1" = "apagar" ]; then
  echo "== remover =="
  checa "iFood removido" "200" "$(cod DELETE /admin-bora/credenciais/IFOOD "$S")"
  checa "99 removido"    "200" "$(cod DELETE /admin-bora/credenciais/NOVE_NOVE "$S")"
  checa "sem servidor, volta a ficar sem app" "False False" "$(app_da_loja)"
  checa "lista: nao configurado" "None None" "$(lista | python -c "import sys,json;print(' '.join(str(c['origem']) for c in json.load(sys.stdin)))")"
fi

echo
echo "RESULTADO: $ok PASS / $fail FALHA"
exit $([ $fail -eq 0 ] && echo 0 || echo 1)
