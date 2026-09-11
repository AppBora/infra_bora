#!/usr/bin/env bash
# Prova que o @Scheduled vira o status SOZINHO - ninguem abre tela, ninguem chama endpoint.
# O agendador dispara 120s depois do boot, entao o teste espera de verdade.
API=http://localhost:8080
MOCK=http://localhost:8099
cd "C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java"
SPD="/c/Users/user/AppData/Local/Temp/claude/C--Users-user-OneDrive-Desktop-Bora/7baa071c-be99-425b-b6de-3dd423c94538/scratchpad"

echo "1) banco zerado e stack de pe"
docker compose -f docker-compose.yml -f "$SPD/override-asaas.yml" down -v >/dev/null 2>&1
SUPERADMIN_EMAIL=super@local.test SUPERADMIN_SENHA=local-teste-1234 \
  docker compose -f docker-compose.yml -f "$SPD/override-asaas.yml" up -d >/dev/null 2>&1
curl -s --retry 30 --retry-delay 4 --retry-all-errors -m 240 $API/actuator/health >/dev/null

T=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" -d '{"email":"admin@bora.app","senha":"bora123"}' | python -c "import sys,json;print(json.load(sys.stdin)['token'])")
echo "2) ativa o recebimento (KYC pendente no mock)"
curl -s -o /dev/null -X POST $API/api/recebimento/ativar -H "Content-Type: application/json" -H "Authorization: Bearer $T" \
  -d '{"cpfCnpj":"53953786000128","mobilePhone":"15981034318","postalCode":"18074760","address":"Rua Teste","addressNumber":"1","province":"Centro","companyType":"MEI","incomeValue":3000}'
echo "   cardapio agora: $(curl -s $API/public/loja/1/cardapio | python -c 'import sys,json;print(json.load(sys.stdin)["pixDisponivel"])')"

echo "3) o Asaas aprova o KYC - e NINGUEM abre tela nenhuma daqui em diante"
curl -s -o /dev/null -X POST $MOCK/__aprovar

echo "4) esperando o agendador (120s de initialDelay + folga)..."
sleep 150

PIX=$(curl -s $API/public/loja/1/cardapio | python -c 'import sys,json;print(json.load(sys.stdin)["pixDisponivel"])')
echo "5) cardapio publico agora: $PIX   (nenhuma chamada a /api/recebimento foi feita apos a aprovacao)"
docker compose logs api --since 4m 2>&1 | grep -i "aprovada no KYC" | tail -2
if [ "$PIX" = "True" ]; then echo "RESULTADO: PASS - o reconciliador virou sozinho"; exit 0
else echo "RESULTADO: FALHA - continuou $PIX"; exit 1; fi
