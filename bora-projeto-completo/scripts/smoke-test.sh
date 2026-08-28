#!/usr/bin/env bash
# Smoke-test E2E do BoraHapp — exercita os fluxos principais contra uma API rodando.
# Uso:
#   BASE=http://localhost:8080 ADMIN_EMAIL=admin@bora.app ADMIN_SENHA=bora123 ./smoke-test.sh
# Requisitos: curl e jq. Suba a stack antes:  cd bora-fase-3-backend-java && docker compose up --build -d
set -uo pipefail

BASE="${BASE:-http://localhost:8080}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@bora.app}"
ADMIN_SENHA="${ADMIN_SENHA:-bora123}"

PASS=0; FAIL=0
ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
hr()   { echo "── $1 ─────────────────────────────────────────"; }

# jq helper
have() { command -v "$1" >/dev/null 2>&1; }
have curl || { echo "curl é obrigatório"; exit 2; }
have jq   || { echo "jq é obrigatório (apt-get install jq)"; exit 2; }

req() { # metodo url [token] [body]
  local m="$1" url="$2" tok="${3:-}" body="${4:-}"
  local args=(-s -o /tmp/sm_body -w '%{http_code}' -X "$m" "$BASE$url" -H 'Content-Type: application/json')
  [ -n "$tok" ]  && args+=(-H "Authorization: Bearer $tok")
  [ -n "$body" ] && args+=(--data "$body")
  curl "${args[@]}"
}

hr "1) Health"
code=$(req GET /actuator/health)
[ "$code" = "200" ] && ok "GET /actuator/health = 200" || bad "GET /actuator/health = $code"

hr "2) Login admin"
code=$(req POST /auth/login "" "{\"email\":\"$ADMIN_EMAIL\",\"senha\":\"$ADMIN_SENHA\"}")
TOKEN=$(jq -r '.token // empty' /tmp/sm_body 2>/dev/null)
if [ "$code" = "200" ] && [ -n "$TOKEN" ]; then ok "login ok (JWT recebido)"; else bad "login falhou ($code)"; echo "   -> sem token, abortando"; exit 1; fi

code=$(req GET /auth/me "$TOKEN")
[ "$code" = "200" ] && ok "GET /auth/me = 200 ($(jq -r '.papel // "?"' /tmp/sm_body))" || bad "GET /auth/me = $code"

hr "3) Onboarding / prontidão"
code=$(req GET /api/onboarding "$TOKEN")
if [ "$code" = "200" ]; then
  P=$(jq -r '.prontidao // "?"' /tmp/sm_body); N=$(jq -r '.passos|length' /tmp/sm_body)
  ok "GET /api/onboarding = 200 (prontidão ${P}%, ${N} passos)"
else bad "GET /api/onboarding = $code"; fi

hr "4) Defaults semeados (loja operável)"
for path in "/api/formas-pagamento|Dinheiro/PIX/Cartão" "/api/motivos|motivos" "/api/horarios|horários"; do
  url="${path%%|*}"; nome="${path##*|}"
  code=$(req GET "$url" "$TOKEN"); n=$(jq 'length' /tmp/sm_body 2>/dev/null)
  if [ "$code" = "200" ] && [ "${n:-0}" -gt 0 ]; then ok "$nome: $n itens"; else bad "$nome vazio/erro ($code, n=${n:-0})"; fi
done

hr "5) Rede & Análise"
for url in /api/rede/lojas /api/rede/balancete /api/analise/canais /api/analise/horario /api/analise/tempos; do
  code=$(req GET "$url" "$TOKEN")
  [ "$code" = "200" ] && ok "GET $url = 200" || bad "GET $url = $code"
done
# representatividade presente no balancete?
req GET /api/rede/balancete "$TOKEN" >/dev/null
if jq -e '.total.representatividade != null' /tmp/sm_body >/dev/null 2>&1; then ok "balancete traz representatividade"; else bad "balancete SEM representatividade"; fi

hr "6) Recebimento (status)"
code=$(req GET /api/recebimento "$TOKEN")
if [ "$code" = "200" ]; then
  st=$(jq -r '.status // "?"' /tmp/sm_body); cfg=$(jq -r '.configuradoPlataforma' /tmp/sm_body)
  ok "GET /api/recebimento = 200 (status=$st, plataforma configurada=$cfg)"
else bad "GET /api/recebimento = $code"; fi
# a apiKey NUNCA deve vazar em /admin-bora/lojas (se você tiver um super-admin, teste com o token dele)
req GET /admin-bora/lojas "$TOKEN" >/dev/null
if jq -e '.[]?|.asaasApiKey' /tmp/sm_body >/dev/null 2>&1; then bad "VAZAMENTO: asaasApiKey aparece em /admin-bora/lojas"; else ok "asaasApiKey não vaza em /admin-bora/lojas"; fi

hr "7) Cadastro self-service + defaults automáticos"
SUF=$RANDOM
EMAIL="qa+$SUF@bora.app"
code=$(req POST /public/signup "" "{\"nomeLoja\":\"QA Loja $SUF\",\"adminNome\":\"QA\",\"adminEmail\":\"$EMAIL\",\"adminSenha\":\"qa12345\"}")
if [ "$code" = "200" ]; then
  ok "signup criou loja ($(jq -r '.lojaId' /tmp/sm_body))"
  code=$(req POST /auth/login "" "{\"email\":\"$EMAIL\",\"senha\":\"qa12345\"}")
  T2=$(jq -r '.token // empty' /tmp/sm_body)
  if [ -n "$T2" ]; then
    req GET /api/formas-pagamento "$T2" >/dev/null; nf=$(jq 'length' /tmp/sm_body)
    [ "${nf:-0}" -ge 4 ] && ok "loja nova já nasce com $nf formas de pagamento" || bad "loja nova sem defaults (formas=${nf:-0})"
  else bad "login da loja nova falhou"; fi
else bad "signup falhou ($code)"; fi

hr "8) Webhook PIX (subconta) rejeita token inválido"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/public/pix-webhook/1"   -H 'Content-Type: application/json' -H 'asaas-access-token: token-errado'   --data '{"event":"PAYMENT_RECEIVED","payment":{"id":"pay_x"}}')
[ "$code" = "401" ] && ok "pix-webhook com token errado = 401" || bad "pix-webhook com token errado = $code (esperado 401)"

hr "9) Segurança básica"
code=$(req GET /api/rede/balancete "")   # sem token
[ "$code" = "401" ] || [ "$code" = "403" ] && ok "sem token bloqueado ($code)" || bad "endpoint protegido respondeu $code sem token"

echo
echo "════════════════════════════════════════════════"
echo "  RESULTADO:  $PASS PASS   /   $FAIL FAIL"
echo "════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
