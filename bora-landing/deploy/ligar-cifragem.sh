#!/usr/bin/env bash
#
# Liga a cifragem em repouso: gera a chave BORA_SEGREDO_COLUNAS, guarda no api.env e reinicia a API.
#
# QUEM RODA ISTO E O DONO, pelo SSH dele. Nao e o assistente: a chave aparece UMA vez na tela de
# quem executa, e quem a ve passa a poder ler as credenciais de todos os lojistas. Essa custodia e
# de uma pessoa so.
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
echo "Reiniciando a API para ela ler a chave..."
docker restart api >/dev/null

for i in $(seq 1 40); do
  if [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 https://borahapp.com.br/actuator/health)" = "200" ]; then
    break
  fi
  sleep 3
done

echo
if docker logs --since 2m api 2>&1 | grep -q "SEGREDO_COLUNAS nao definido\|SEGREDO_COLUNAS não definido"; then
  echo "ATENCAO: a API subiu e CONTINUA avisando que a chave nao esta definida."
  echo "Confira o $ENV e se o container esta usando esse arquivo (--env-file)."
  exit 1
fi
echo "Pronto: a API subiu e parou de avisar que a chave falta."
echo
echo "FALTA O PASSO 3, e e no painel:"
echo "  Configuracoes -> Plataforma -> 'Credenciais no banco' -> 'Cifrar o que ja esta gravado'"
echo "O bloco estava vermelho; agora deve estar amarelo, com a contagem do que falta cifrar."
echo "Rodar o botao duas vezes nao estraga nada."
