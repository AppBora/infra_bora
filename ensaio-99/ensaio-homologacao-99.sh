#!/usr/bin/env bash
# Ensaio da homologacao da 99Food, de ponta a ponta, sem depender da 99.
#
# Por que existe: a homologacao da 99 pede para ver o fluxo funcionando, e ate hoje nunca conseguimos
# gerar um pedido de teste de verdade (a conta de teste nao entra no aplicativo deles - chamado aberto
# em 29/09). Este ensaio poe uma "99 de mentira" no lugar e roda o Bora INTEIRO contra ela: polling,
# detalhe do pedido, pedido nascendo no banco, e os status voltando.
#
# Ele testa o que a homologacao olha:
#   1. O pedido chega sozinho pelo polling e vira pedido no Bora
#   2. Os dados chegam certos (cliente, itens, complementos, endereco, taxa, troco, observacoes)
#   3. O recebimento e confirmado (acknowledgment), para a 99 nao reenviar o mesmo pedido
#   4. O fluxo de entrega devolve confirm > readyForPickup > dispatch > delivered
#   5. O fluxo de RETIRADA devolve confirm > readyForPickup > pickedUp, e NUNCA dispatch
#
# Uso:  bash ensaio-homologacao-99.sh [tag-da-imagem]     (padrao: bora-api:latest)
# Nao toca em producao. Sobe tudo numa rede propria e derruba no fim.
set -u

# O Git Bash converte argumento que parece caminho: "-w /app" virava "C:/Program Files/Git/app" e o
# docker recusava. Desligar a conversao e o que faz este script rodar no Windows.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

IMAGEM="${1:-bora-api:latest}"
REDE="ensaio99"
PG="ensaio99-pg"
API="ensaio99-api"
FAKE="ensaio99-falsa"
# Com a conversao desligada, o docker precisa do caminho no formato do Windows (pwd -W no Git Bash);
# em Linux/Mac o pwd normal serve.
AQUI="$(cd "$(dirname "$0")" && { pwd -W 2>/dev/null || pwd; })"
FALHAS=0

ok()    { echo "  [ok]    $1"; }
falha() { echo "  [FALHA] $1"; FALHAS=$((FALHAS+1)); }
titulo(){ echo; echo "== $1"; }

limpar() {
  docker rm -f "$API" "$PG" "$FAKE" >/dev/null 2>&1
  docker network rm "$REDE" >/dev/null 2>&1
}

# MANTER=1 deixa tudo de pe NO FIM, para investigar. A limpeza do COMECO acontece sempre: sem isso o
# ensaio reaproveitava os containers da rodada anterior e media o estado velho — me custou uma caçada
# a um defeito do Bora que nao existia.
noFim() {
  [ "${MANTER:-0}" = "1" ] && { echo; echo "(containers mantidos: $API $PG $FAKE na rede $REDE)"; return; }
  limpar
}
trap noFim EXIT

echo "Ensaio da homologacao 99Food - imagem $IMAGEM"
limpar
docker network create "$REDE" >/dev/null 2>&1

titulo "Subindo a 99 de mentira"
docker run -d --name "$FAKE" --network "$REDE" -w /app python:3.12-alpine sleep 3600 >/dev/null
docker cp "$AQUI/fake99.py" "$FAKE:/app/fake99.py" >/dev/null
docker exec -d "$FAKE" python /app/fake99.py 8077
sleep 2
docker exec "$FAKE" python -c "
import urllib.request,sys
try:
    urllib.request.urlopen('http://127.0.0.1:8077/relatorio',timeout=3); print('de pe')
except Exception as e:
    print('NAO SUBIU:',e); sys.exit(1)
" || { falha "a 99 de mentira nao subiu"; exit 1; }
ok "escutando em http://$FAKE:8077"

titulo "Subindo banco e Bora"
docker run -d --name "$PG" --network "$REDE" -e POSTGRES_PASSWORD=teste -e POSTGRES_DB=bora postgres:16 >/dev/null
for i in $(seq 1 30); do docker exec "$PG" pg_isready -U postgres >/dev/null 2>&1 && break; sleep 2; done

docker run -d --name "$API" --network "$REDE" \
  -e SPRING_DATASOURCE_URL="jdbc:postgresql://$PG:5432/bora" \
  -e SPRING_DATASOURCE_USERNAME=postgres -e SPRING_DATASOURCE_PASSWORD=teste \
  -e MARKETPLACE_OPENDELIVERY_BASE_URL="http://$FAKE:8077/v4/opendelivery" \
  -e MARKETPLACE_POLLING_INTERVALO_MS=5000 \
  "$IMAGEM" >/dev/null
for i in $(seq 1 60); do
  docker logs "$API" 2>&1 | grep -q "Started BoraApplication" && break
  docker logs "$API" 2>&1 | grep -q "APPLICATION FAILED" && { falha "o Bora nao subiu"; docker logs "$API" 2>&1 | tail -20; exit 1; }
  sleep 3
done
ok "Bora de pe, apontando o polling para a 99 de mentira"

titulo "Ligando a loja 1 na 99 (como o lojista faria no painel)"
docker exec "$PG" psql -U postgres -d bora -tAc "
insert into integracao_canal (loja_id, canal, merchant_id, client_id, client_secret, status, ativo)
values (1,'NOVE_NOVE','boraloja1','app-de-ensaio','segredo-de-ensaio','CONECTADO',true);" >/dev/null
ok "integracao CONECTADO com app shop boraloja1"

titulo "Esperando os pedidos chegarem sozinhos (ate 40s)"
for i in $(seq 1 20); do
  n=$(docker exec "$PG" psql -U postgres -d bora -tAc "select count(*) from pedido where canal_externo='NOVE_NOVE';" 2>/dev/null | tr -d ' ')
  [ "${n:-0}" -ge 2 ] && break
  sleep 2
done
n=$(docker exec "$PG" psql -U postgres -d bora -tAc "select count(*) from pedido where canal_externo='NOVE_NOVE';" | tr -d ' ')
if [ "${n:-0}" -ge 2 ]; then ok "$n pedidos entraram sozinhos pelo polling"
else falha "esperava 2 pedidos da 99, chegaram ${n:-0}"; docker logs "$API" 2>&1 | grep -iE "open delivery|polling" | tail -10; fi

titulo "Conferindo o pedido de ENTREGA"
# O nome e o endereco ficam no CLIENTE, nao no pedido: o pedido guarda o telefone, o total, a taxa
# e a observacao. Foi aqui que a primeira versao deste ensaio errou e acusou 6 falhas que nao existiam.
linha=$(docker exec "$PG" psql -U postgres -d bora -tAc "
select coalesce(c.nome,'?')||'|'||coalesce(p.valor_total::text,'?')||'|'||coalesce(p.taxa_entrega::text,'?')||'|'||coalesce(c.endereco,'SEM')||'|'||coalesce(p.observacao,'')
from pedido p left join cliente c on c.id=p.cliente_id where p.id_externo='99-DELIVERY-1';")
echo "  $linha"
case "$linha" in *"Bruno"*)        ok "cliente";;              *) falha "cliente errado";; esac
# ATENCAO, e de proposito que isto nao reprova: no marketplace o valor_total do pedido NAO inclui a
# taxa de entrega (fica so em taxa_entrega), enquanto no balcao e no cardapio proprio o valor_total
# INCLUI a taxa. O faturamento soma apenas valor_total, entao o mesmo pedido de R$ 51 entra como 51
# vindo do balcao e como 44 vindo da 99. Quem decide qual e o certo e o dono, porque depende de quem
# fica com a taxa: na entrega pela loja o dinheiro e dela; na entrega pela 99, nao.
case "$linha" in *"44.00"*) ok "valor do pedido R\$ 44,00 (itens), taxa a parte";;
                         *) falha "valor do pedido errado";; esac
case "$linha" in *"44.00"*) AVISO_TAXA=1;; esac
case "$linha" in *"7.00"*)         ok "taxa de entrega R\$ 7,00";; *) falha "taxa errada";; esac
case "$linha" in *"Rua das Flores"*) ok "endereco";;            *) falha "endereco faltando";; esac
case "$linha" in *"4455"*)         ok "numero do pedido na 99";; *) falha "numero do pedido faltando";; esac
case "$linha" in *[Tt]roco*)       ok "troco avisado ao balconista";; *) falha "troco nao aparece";; esac

itens=$(docker exec "$PG" psql -U postgres -d bora -tAc "
select string_agg(descricao||' x'||quantidade, ' / ') from pedido_item
where pedido_id=(select id from pedido where id_externo='99-DELIVERY-1');")
echo "  itens: $itens"
case "$itens" in *"Acai 500ml"*)   ok "item principal";;        *) falha "item faltando";; esac
case "$itens" in *[Ll]eite*)       ok "complemento no item";;   *) falha "complemento perdido";; esac

titulo "Conferindo o pedido de RETIRADA"
linha=$(docker exec "$PG" psql -U postgres -d bora -tAc "
select coalesce(c.nome,'?')||'|'||coalesce(p.valor_total::text,'?')||'|ENDERECO='||coalesce(nullif(c.endereco,''),'NULO')||'|'||coalesce(p.observacao,'')
from pedido p left join cliente c on c.id=p.cliente_id where p.id_externo='99-TAKEOUT-1';")
echo "  $linha"
case "$linha" in *"Ana Paula"*)      ok "cliente";;                      *) falha "cliente errado";; esac
case "$linha" in *"ENDERECO=NULO"*)  ok "sem endereco, como manda a retirada";; *) falha "retirada nao pode ter endereco";; esac
case "$linha" in *RETIRADA*)         ok "avisa RETIRADA NO BALCAO";;      *) falha "nao avisa que e retirada";; esac

titulo "Confirmando o recebimento (acknowledgment)"
ack=$(docker exec "$FAKE" python -c "
import urllib.request,json
d=json.load(urllib.request.urlopen('http://127.0.0.1:8077/relatorio'))
print(len(d['ack']), ','.join(sorted(x.get('orderId','?') for x in d['ack'])))")
echo "  $ack"
case "$ack" in 2\ *99-DELIVERY-1*99-TAKEOUT-1*) ok "os 2 eventos foram confirmados; a 99 nao reenvia";;
                                             *) falha "acknowledgment faltando: $ack";; esac

titulo "Fluxo de status - ENTREGA (deve terminar em delivered)"
TOKEN=$(docker run --rm --network "$REDE" curlimages/curl:latest -s -X POST "http://$API:8080/auth/login" \
  -H "Content-Type: application/json" -d '{"email":"admin@bora.app","senha":"bora123"}' | sed -E 's/.*"token":"([^"]+)".*/\1/')
ID1=$(docker exec "$PG" psql -U postgres -d bora -tAc "select id from pedido where id_externo='99-DELIVERY-1';" | tr -d ' ')
for st in CONFIRMADO EM_PREPARO PRONTO SAIU_PARA_ENTREGA ENTREGUE; do
  docker run --rm --network "$REDE" curlimages/curl:latest -s -o /dev/null \
    -X PATCH "http://$API:8080/api/pedidos/$ID1/status?status=$st" -H "Authorization: Bearer $TOKEN"
done

titulo "Fluxo de status - RETIRADA (deve terminar em pickedUp, sem dispatch)"
ID2=$(docker exec "$PG" psql -U postgres -d bora -tAc "select id from pedido where id_externo='99-TAKEOUT-1';" | tr -d ' ')
for st in CONFIRMADO EM_PREPARO PRONTO SAIU_PARA_ENTREGA ENTREGUE; do
  docker run --rm --network "$REDE" curlimages/curl:latest -s -o /dev/null \
    -X PATCH "http://$API:8080/api/pedidos/$ID2/status?status=$st" -H "Authorization: Bearer $TOKEN"
done
sleep 2

titulo "O que a 99 recebeu de volta"
relatorio=$(docker exec "$FAKE" python -c "
import urllib.request,json
d=json.load(urllib.request.urlopen('http://127.0.0.1:8077/relatorio'))
for p in ['99-DELIVERY-1','99-TAKEOUT-1']:
    print(p+': '+' > '.join(x['verbo'] for x in d['status'] if x['pedido']==p))")
echo "$relatorio"
entrega=$(echo "$relatorio" | grep '^99-DELIVERY-1:' | cut -d: -f2-)
retira=$(echo "$relatorio" | grep '^99-TAKEOUT-1:' | cut -d: -f2-)
case "$entrega" in *confirm*readyForPickup*dispatch*delivered*) ok "entrega: fluxo completo";; *) falha "entrega: fluxo errado ->$entrega";; esac
case "$retira"  in *confirm*readyForPickup*pickedUp*)           ok "retirada: fecha em pickedUp";; *) falha "retirada: fluxo errado ->$retira";; esac
case "$retira"  in *dispatch*) falha "retirada NAO pode mandar dispatch";; *) ok "retirada: nenhum dispatch enviado";; esac

if [ "${AVISO_TAXA:-0}" = "1" ]; then
  titulo "ATENCAO - diferenca entre canais (nao reprova, mas precisa de decisao)"
  echo "  Pedido da 99 de R\$ 51,00 (R\$ 44 de itens + R\$ 7 de taxa) ficou gravado como"
  echo "  valor_total = 44,00 e taxa_entrega = 7,00."
  echo "  No balcao e no cardapio proprio, o mesmo pedido ficaria com valor_total = 51,00."
  echo "  O faturamento do dia soma SO o valor_total: pedido de marketplace entra R\$ 7 menor."
  echo "  Decisao do dono: a taxa de entrega conta como faturamento da loja? (muda conforme quem entrega)"
fi

titulo "RESULTADO"
if [ "$FALHAS" -eq 0 ]; then
  echo "  TUDO PASSOU. O ciclo completo da 99 funciona: pedido entra sozinho, dados certos,"
  echo "  recebimento confirmado, e os dois fluxos de status fecham do jeito que a 99 espera."
  exit 0
else
  echo "  $FALHAS verificacao(oes) falharam - veja acima."
  exit 1
fi
