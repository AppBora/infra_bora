#!/usr/bin/env bash
#
# Liga a cifragem em repouso: gera a chave BORA_SEGREDO_COLUNAS, guarda no api.env e reinicia a API.
#
# QUEM RODA ISTO E O DONO, pelo SSH dele. Nao e o assistente: a chave aparece UMA vez na tela de
# quem executa, e quem a ve passa a poder ler as credenciais de todos os lojistas. Essa custodia e
# de uma pessoa so.
#
# EM 30/10/2026 A CHAVE JA FOI GERADA, e de um jeito que este script nao previa: o dono mandou
# "liga a cifragem", e o assistente gerou a chave NO SERVIDOR escrevendo direto no api.env, sem
# nunca exibir o valor -- nem para ele mesmo. A custodia continua sendo de uma pessoa so, mas o
# PASSO DE GUARDAR ficou pendente, e esse passo nao e opcional: nenhum backup do servidor contem
# o api.env (conferido em 30/10). Para ler a chave uma vez e guardar no gerenciador de senhas:
#
#   ssh -i ~/.ssh/bora-lightsail.pem ubuntu@18.230.57.33 \
#     "grep '^BORA_SEGREDO_COLUNAS=' /home/ubuntu/bora/api.env"
#
# Rodar este script de novo nao gera outra chave: ele ve que ja existe e para.
#
#   ssh -i ~/.ssh/bora-lightsail.pem ubuntu@18.230.57.33
#   bash /home/ubuntu/ligar-cifragem.sh
#
# O QUE A CIFRA PROTEGE (medido em 23/10/2026, CifragemEmRepousoService.ALVOS):
#   loja.asaas_api_key
#   config_plataforma.valor
#   integracao_canal.client_secret, access_token, refresh_token, webhook_token
#
# Hoje as 4 credenciais de marketplace estao em TEXTO PURO no banco -- e, portanto, em todos os
# dumps. Quem puser a mao num backup poe a mao no client-secret do iFood.
#
# SE A CHAVE SE PERDER: nenhuma venda, pedido ou cliente se perde -- nada disso e cifrado. O que
# fica ilegivel e credencial, e credencial se pega de volta com o provedor. O preco e refazer o
# vinculo do iFood de cada loja e recadastrar a chave do Asaas. Chato, nao fatal. Mas evite: guarde
# a chave no gerenciador de senhas ANTES de clicar no botao de cifrar.
#
# A ORDEM IMPORTA:
#   1) este script  -> a chave passa a existir e protege o que for gravado DAQUI PARA FRENTE
#   2) voce guarda a chave no gerenciador de senhas
#   3) so entao: painel -> Configuracoes -> Plataforma -> "Cifrar o que ja esta gravado"
# Inverter 2 e 3 e o unico jeito de isto dar errado.
set -euo pipefail

ENV=/home/ubuntu/bora/api.env
VAR=BORA_SEGREDO_COLUNAS

[ -f "$ENV" ] || { echo "nao achei $ENV"; exit 1; }

if grep -q "^${VAR}=.\+" "$ENV"; then
  echo "A chave JA esta definida no $ENV. Nao vou gerar outra."
  echo
  echo "Trocar a chave depois de ter cifrado deixa o que ja foi cifrado ilegivel -- nao e um"
  echo "'girar a chave', e um 'perder a chave'. Se e isso mesmo que voce quer, apague a linha"
  echo "${VAR}= na mao e rode de novo, sabendo que as credenciais cifradas terao de ser"
  echo "recadastradas."
  exit 0
fi

# 32 bytes de aleatorio do sistema. Nao e digitada por ninguem, e nao passa por lugar nenhum
# alem desta tela e do arquivo.
CHAVE=$(openssl rand -base64 32)

cat <<AVISO

====================================================================
  GUARDE ESTA CHAVE AGORA, no seu gerenciador de senhas.
  Ela aparece UMA vez. Depois disto, ninguem consegue le-la de volta.

  ${VAR}=${CHAVE}

====================================================================
AVISO

printf 'Ja guardou? Digite GUARDEI para continuar: '
read -r RESP
if [ "$RESP" != "GUARDEI" ]; then
  echo "Nada foi alterado. O $ENV continua sem a chave."
  exit 1
fi

cp -p "$ENV" "${ENV}.antes-cifragem"
printf '\n# Cifragem em repouso das credenciais (ver SegredoGuardado.java). Gerada em %s.\n' "$(date -Is)" >> "$ENV"
printf '%s=%s\n' "$VAR" "$CHAVE" >> "$ENV"
unset CHAVE

echo
echo "Guardado no $ENV (copia do anterior em ${ENV}.antes-cifragem)."

# AQUI MORAVA UM DEFEITO, encontrado usando isto em 30/10/2026: o passo era
# `docker restart api`, e docker restart NAO rele o --env-file. O container carrega as
# variaveis de quando foi CRIADO; reiniciar devolve exatamente as mesmas. A API subia e
# continuava avisando que a chave nao existia -- o script detectava e saia com erro, mas nao
# tinha como resolver, e quem rodasse ficaria com a chave no arquivo e a cifra desligada.
#
# Para a variavel entrar, o container tem de ser RECRIADO. E o mesmo comando do passo 8 do
# deploy-api.sh, com a MESMA imagem que ja esta de pe (nao e deploy: nao troca versao), e com
# o mesmo rollback, porque recriar container em producao pode falhar.
echo "Recriando o container da API para ela LER a chave (restart nao basta)..."

sadio() {
  for i in $(seq 1 25); do
    docker exec api curl -fs localhost:8080/actuator/health 2>/dev/null | grep -q UP && return 0
    sleep 3
  done
  return 1
}
voltar_atras() {
  echo "ROLLBACK: devolvendo o container anterior." >&2
  docker logs --tail 25 api 2>&1 | tail -25 >&2 || true
  docker rm -f api >/dev/null 2>&1 || true
  docker rename api-antes-cifragem api 2>/dev/null || true
  docker start api >/dev/null 2>&1 || true
  if sadio; then echo "rollback feito: o anterior esta de volta e SADIO." >&2
  else echo "!!! O ROLLBACK NAO FICOU SADIO. A API PODE ESTAR FORA DO AR." >&2; fi
  exit 1
}

docker rm -f api-antes-cifragem >/dev/null 2>&1 || true
docker stop -t 30 api >/dev/null
docker rename api api-antes-cifragem
docker run -d --name api --restart unless-stopped --network bora \
  --env-file /home/ubuntu/bora/api.env \
  --log-opt max-size=20m --log-opt max-file=5 \
  bora-api:latest >/dev/null || voltar_atras
sadio || voltar_atras
docker rm -f api-antes-cifragem >/dev/null 2>&1 || true

echo
if docker logs --since 2m api 2>&1 | grep -q "SEGREDO_COLUNAS nao definido\|SEGREDO_COLUNAS não definido"; then
  echo "ATENCAO: a API subiu e CONTINUA avisando que a chave nao esta definida."
  echo "Confira o $ENV e se o container esta usando esse arquivo (--env-file)."
  exit 1
fi
if ! docker logs --since 2m api 2>&1 | grep -q "cifradas em repouso: LIGADO"; then
  echo "ATENCAO: a API nao avisou que falta chave, mas TAMBEM nao disse LIGADO."
  echo "Nao conclua que ligou: procure a linha do SegredoGuardado em 'docker logs api'."
  exit 1
fi
echo "Pronto: a API subiu e diz 'cifradas em repouso: LIGADO (AES-256/GCM)'."
echo
echo "FALTA O PASSO 3, e e no painel:"
echo "  Configuracoes -> Plataforma -> 'Credenciais no banco' -> 'Cifrar o que ja esta gravado'"
echo "O bloco estava vermelho; agora deve estar amarelo, com a contagem do que falta cifrar."
echo "Rodar o botao duas vezes nao estraga nada."
