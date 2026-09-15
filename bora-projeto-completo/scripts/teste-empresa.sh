#!/usr/bin/env bash
# Suspender / reativar / arquivar / restaurar a EMPRESA inteira (todas as lojas do mesmo CNPJ) pelo
# painel da plataforma. Instancia LOCAL descartavel, subida com superadmin:
#   SUPERADMIN_EMAIL=super@local.test SUPERADMIN_SENHA=local-teste-1234 docker compose up
API=http://localhost:8080
ok=0; fail=0
checa() { if [ "$2" = "$3" ]; then echo "  PASS  $1"; ok=$((ok+1)); else echo "  FALHA $1 — esperado [$2], veio [$3]"; fail=$((fail+1)); fi; }
JSON="Content-Type: application/json"
token() { curl -s -X POST "$API/auth/login" -H "$JSON" -d "{\"email\":\"$1\",\"senha\":\"$2\"}" \
  | python -c "import sys,json;print(json.load(sys.stdin).get('token',''))" 2>/dev/null; }
login() { curl -s -o /dev/null -w '%{http_code}' -X POST "$API/auth/login" -H "$JSON" -d "{\"email\":\"$1\",\"senha\":\"$2\"}"; }
put() { curl -s -o /dev/null -w '%{http_code}' -X PUT "$API$1" -H "$JSON" -H "Authorization: Bearer $2" -d "${3:-{\}}"; }
campo() { python -c "import sys,json;print(json.load(sys.stdin).get(sys.argv[1],''))" "$1"; }

S=$(token super@local.test local-teste-1234)
[ -z "$S" ] && { echo "SEM TOKEN DE SUPERADMIN — suba a API com SUPERADMIN_EMAIL/SENHA"; exit 1; }
AS="Authorization: Bearer $S"

# situacao de cada loja no painel (inclui arquivadas); SUMIU = nem na lixeira
situacoes() { curl -s "$API/admin-bora/clientes?incluirArquivadas=true" -H "$AS" | python -c "
import sys,json
d={c['id']:c for c in json.load(sys.stdin)}
print(' '.join(d[int(i)]['situacao'] if int(i) in d else 'SUMIU' for i in sys.argv[1:]))" "$@"; }
visiveis() { curl -s "$API/admin-bora/clientes" -H "$AS" | python -c "
import sys,json
ids={c['id'] for c in json.load(sys.stdin)}
print(' '.join('sim' if int(i) in ids else 'nao' for i in sys.argv[1:]))" "$@"; }
cardapio() { curl -s -o /dev/null -w '%{http_code}' "$API/public/loja/$1/cardapio"; }

SUF=$RANDOM
echo "== empresa A com 2 lojas (mesmo CNPJ, mesmo dono) e empresa B com 1 =="
R=$(curl -s -X POST $API/admin-bora/lojas -H "$JSON" -H "$AS" -d "{\"nomeLoja\":\"Rede A Centro $SUF\",\"documento\":\"11222333$SUF\",\"adminEmail\":\"dono-a-$SUF@local.test\",\"adminSenha\":\"senha123\"}")
A1=$(echo "$R" | campo lojaId); EA=$(echo "$R" | campo empresaId)
R=$(curl -s -X POST $API/admin-bora/lojas -H "$JSON" -H "$AS" -d "{\"nomeLoja\":\"Rede A Norte $SUF\",\"documento\":\"11222333$SUF\",\"adminEmail\":\"dono-a-$SUF@local.test\",\"adminSenha\":\"senha123\"}")
A2=$(echo "$R" | campo lojaId); EA2=$(echo "$R" | campo empresaId)
R=$(curl -s -X POST $API/admin-bora/lojas -H "$JSON" -H "$AS" -d "{\"nomeLoja\":\"Empresa B $SUF\",\"documento\":\"99888777$SUF\",\"adminEmail\":\"dono-b-$SUF@local.test\",\"adminSenha\":\"senha123\"}")
B1=$(echo "$R" | campo lojaId); EB=$(echo "$R" | campo empresaId)
checa "as 2 lojas de A na mesma empresa" "$EA" "$EA2"
checa "B em outra empresa" "sim" "$([ -n "$EB" ] && [ "$EB" != "$EA" ] && echo sim || echo nao)"
checa "painel informa a empresa de cada loja" "$EA $EA $EB" "$(curl -s "$API/admin-bora/clientes" -H "$AS" | python -c "
import sys,json
d={c['id']:c for c in json.load(sys.stdin)}
print(' '.join(str(d[int(i)]['empresaId']) for i in sys.argv[1:]))" $A1 $A2 $B1)"
checa "tudo ativo no inicio" "ATIVA ATIVA ATIVA" "$(situacoes $A1 $A2 $B1)"
checa "dono de A entra" "200" "$(login dono-a-$SUF@local.test senha123)"
TB=$(token dono-b-$SUF@local.test senha123)

echo "== quem pode =="
checa "sem login"            "401" "$(curl -s -o /dev/null -w '%{http_code}' -X PUT "$API/admin-bora/empresas/$EA/ativo" -H "$JSON" -d '{"ativo":false}')"
checa "dono de loja nao pode" "403" "$(put /admin-bora/empresas/$EA/ativo "$TB" '{"ativo":false}')"
checa "empresa que nao existe" "404" "$(put /admin-bora/empresas/999999/ativo "$S" '{"ativo":false}')"
checa "nada mudou" "ATIVA ATIVA ATIVA" "$(situacoes $A1 $A2 $B1)"

echo "== suspender a empresa A =="
checa "suspensao aceita" "200" "$(put /admin-bora/empresas/$EA/ativo "$S" '{"ativo":false,"motivo":"teste"}')"
checa "as 2 lojas de A suspensas, B intacta" "SUSPENSA SUSPENSA ATIVA" "$(situacoes $A1 $A2 $B1)"
checa "dono de A barrado no login" "403" "$(login dono-a-$SUF@local.test senha123)"
checa "dono de B segue entrando" "200" "$(login dono-b-$SUF@local.test senha123)"
checa "cardapio de A fora do ar" "404 404" "$(cardapio $A1) $(cardapio $A2)"
checa "cardapio de B no ar" "200" "$(cardapio $B1)"
checa "suspender de novo: nada a fazer" "409" "$(put /admin-bora/empresas/$EA/ativo "$S" '{"ativo":false}')"

echo "== reativar a empresa A =="
checa "reativacao aceita" "200" "$(put /admin-bora/empresas/$EA/ativo "$S" '{"ativo":true}')"
checa "as 2 lojas de A ativas" "ATIVA ATIVA ATIVA" "$(situacoes $A1 $A2 $B1)"
checa "dono de A volta a entrar" "200" "$(login dono-a-$SUF@local.test senha123)"
checa "reativar de novo: nada a fazer" "409" "$(put /admin-bora/empresas/$EA/ativo "$S" '{"ativo":true}')"

echo "== arquivar (excluir) a empresa A =="
checa "arquivamento aceito" "200" "$(put /admin-bora/empresas/$EA/arquivar "$S" '{"motivo":"encerrou o contrato"}')"
checa "A some da lista, B continua" "nao nao sim" "$(visiveis $A1 $A2 $B1)"
checa "A esta na lixeira (nada apagado)" "ARQUIVADA ARQUIVADA ATIVA" "$(situacoes $A1 $A2 $B1)"
checa "dono de A barrado" "403" "$(login dono-a-$SUF@local.test senha123)"
checa "reativar arquivada: recusado" "409" "$(put /admin-bora/empresas/$EA/ativo "$S" '{"ativo":true}')"
checa "arquivar de novo: nada a fazer" "409" "$(put /admin-bora/empresas/$EA/arquivar "$S" '{}')"

echo "== restaurar a empresa A =="
checa "restauracao aceita" "200" "$(put /admin-bora/empresas/$EA/restaurar "$S")"
checa "A volta para a lista, ainda suspensa" "SUSPENSA SUSPENSA ATIVA" "$(situacoes $A1 $A2 $B1)"
checa "A visivel de novo" "sim sim sim" "$(visiveis $A1 $A2 $B1)"
checa "dono de A ainda barrado ate reativar" "403" "$(login dono-a-$SUF@local.test senha123)"
checa "restaurar de novo: nada a fazer" "409" "$(put /admin-bora/empresas/$EA/restaurar "$S")"
put /admin-bora/empresas/$EA/ativo "$S" '{"ativo":true}' >/dev/null
checa "reativada depois de restaurar" "ATIVA ATIVA" "$(situacoes $A1 $A2)"

echo "== botoes por loja continuam funcionando =="
checa "suspender so a loja B" "200" "$(put /admin-bora/lojas/$B1/ativo "$S" '{"ativo":false,"motivo":"teste"}')"
checa "so B suspensa" "ATIVA ATIVA SUSPENSA" "$(situacoes $A1 $A2 $B1)"
checa "reativar a loja B" "200" "$(put /admin-bora/lojas/$B1/ativo "$S" '{"ativo":true}')"
checa "B ativa de novo" "ATIVA" "$(situacoes $B1)"

echo
echo "RESULTADO: $ok PASS / $fail FALHA"
exit $([ $fail -eq 0 ] && echo 0 || echo 1)
