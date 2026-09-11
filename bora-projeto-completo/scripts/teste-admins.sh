#!/usr/bin/env bash
# Matriz de teste dos endpoints de administrador da plataforma (instancia LOCAL descartavel).
API=http://localhost:8080
ok=0; fail=0
checa() { # nome, esperado, obtido
  if [ "$2" = "$3" ]; then echo "  PASS  $1 ($3)"; ok=$((ok+1));
  else echo "  FALHA $1 — esperado $2, veio $3"; fail=$((fail+1)); fi
}
codigo() { # metodo url token corpo
  local t=""; [ -n "$3" ] && t="-H \"Authorization: Bearer $3\""
  if [ -n "$4" ]; then
    curl -s -o /dev/null -w '%{http_code}' -X "$1" "$API$2" -H "Content-Type: application/json" ${3:+-H "Authorization: Bearer $3"} -d "$4"
  else
    curl -s -o /dev/null -w '%{http_code}' -X "$1" "$API$2" ${3:+-H "Authorization: Bearer $3"}
  fi
}
login() { curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" \
  -d "{\"email\":\"$1\",\"senha\":\"$2\"}" | python -c "import sys,json;print(json.load(sys.stdin).get('token',''))" 2>/dev/null; }

echo "== tokens =="
SUPER=$(login super@local.test local-teste-1234); echo "  super: ${SUPER:0:18}…"
LOJA=$(login admin@bora.app bora123);            echo "  admin de loja: ${LOJA:0:18}…"
[ -z "$SUPER" ] && { echo "SEM TOKEN DE SUPERADMIN — abortando"; exit 1; }

echo "== quem pode ver/criar =="
checa "GET /admins sem token (401 = nao autenticado)" 401 "$(codigo GET /admin-bora/admins '' '')"
checa "GET /admins como admin de LOJA"           403 "$(codigo GET /admin-bora/admins "$LOJA" '')"
checa "POST /admins como admin de LOJA"          403 "$(codigo POST /admin-bora/admins "$LOJA" '{"nome":"X","email":"x@x.com","senha":"12345678"}')"
checa "GET /admins como superadmin"              200 "$(codigo GET /admin-bora/admins "$SUPER" '')"

echo "== validacao de entrada =="
checa "senha curta"                              400 "$(codigo POST /admin-bora/admins "$SUPER" '{"nome":"A","email":"novo1@t.com","senha":"1234567"}')"
checa "email invalido"                           400 "$(codigo POST /admin-bora/admins "$SUPER" '{"nome":"A","email":"semarroba","senha":"12345678"}')"
checa "nome vazio"                               400 "$(codigo POST /admin-bora/admins "$SUPER" '{"nome":"","email":"novo2@t.com","senha":"12345678"}')"
checa "corpo vazio"                              400 "$(codigo POST /admin-bora/admins "$SUPER" '{}')"
checa "e-mail que ja existe (anti-promocao)"     409 "$(codigo POST /admin-bora/admins "$SUPER" '{"nome":"A","email":"admin@bora.app","senha":"12345678"}')"

echo "== criacao =="
NOVO_EMAIL="socio$RANDOM@t.com"
RESP=$(curl -s -X POST "$API/admin-bora/admins" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $SUPER" -d "{\"nome\":\"Socio Teste\",\"email\":\"$NOVO_EMAIL\",\"senha\":\"senha-boa-123\"}")
echo "  resposta: $RESP"
NOVO_ID=$(echo "$RESP" | python -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
checa "criou e devolveu id"                      "sim" "$([ -n "$NOVO_ID" ] && echo sim || echo nao)"
checa "resposta NAO traz hash de senha"          "sim" "$(echo "$RESP" | grep -qi 'senhaHash\|\$2a\$\|\$2b\$' && echo nao || echo sim)"
TOKEN_NOVO=$(login "$NOVO_EMAIL" senha-boa-123)
checa "o novo admin consegue logar"              "sim" "$([ -n "$TOKEN_NOVO" ] && echo sim || echo nao)"
PERFIL=$(curl -s "$API/auth/me" -H "Authorization: Bearer $TOKEN_NOVO")
echo "  /auth/me do novo: $PERFIL"
checa "papel do novo e ADMINISTRADOR_BORA"       "sim" "$(echo "$PERFIL" | grep -q ADMINISTRADOR_BORA && echo sim || echo nao)"
checa "novo enxerga os clientes (cross-tenant)"  200 "$(codigo GET /admin-bora/clientes "$TOKEN_NOVO" '')"

echo "== travas do desativar =="
MEU_ID=$(curl -s "$API/admin-bora/admins" -H "Authorization: Bearer $SUPER" \
  | python -c "import sys,json;print([a['id'] for a in json.load(sys.stdin) if a['euMesmo']][0])" 2>/dev/null)
checa "nao desativa a PROPRIA conta"             400 "$(codigo PUT /admin-bora/admins/$MEU_ID/ativo "$SUPER" '{"ativo":false}')"
ID_LOJA=$(curl -s "$API/admin-bora/admins" -H "Authorization: Bearer $SUPER" | python -c "import sys,json;ids=[a[\"id\"] for a in json.load(sys.stdin)];print(next(i for i in range(1,50) if i not in ids))" 2>/dev/null)
checa "alvo que e admin de LOJA → 404"           404 "$(codigo PUT /admin-bora/admins/$ID_LOJA/ativo "$SUPER" '{"ativo":false}')"
checa "alvo inexistente → 404"                   404 "$(codigo PUT /admin-bora/admins/9999/ativo "$SUPER" '{"ativo":false}')"
checa "desativa o novo admin"                    200 "$(codigo PUT /admin-bora/admins/$NOVO_ID/ativo "$SUPER" '{"ativo":false}')"
checa "desativado nao loga mais"                 "sim" "$([ -z "$(login "$NOVO_EMAIL" senha-boa-123)" ] && echo sim || echo nao)"
checa "token antigo do desativado morre (401)"  401 "$(codigo GET /admin-bora/clientes "$TOKEN_NOVO" '')"
checa "nao desativa o ULTIMO ativo"              400 "$(codigo PUT /admin-bora/admins/$MEU_ID/ativo "$SUPER" '{"ativo":false}')"
checa "reativa o novo admin"                     200 "$(codigo PUT /admin-bora/admins/$NOVO_ID/ativo "$SUPER" '{"ativo":true}')"
checa "reativado volta a logar"                  "sim" "$([ -n "$(login "$NOVO_EMAIL" senha-boa-123)" ] && echo sim || echo nao)"

echo
echo "RESULTADO: $ok PASS / $fail FALHA"
exit $([ $fail -eq 0 ] && echo 0 || echo 1)
