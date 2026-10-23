#!/bin/bash
# Vigia do Bora (29/09/2026): a revisao apontou que se o sistema cair de madrugada ninguem fica
# sabendo. Isto nao substitui um alarme externo (UptimeRobot) — ele so age DE DENTRO: se o site nao
# responder em duas checagens seguidas, reinicia o container e registra. Se o servidor inteiro cair,
# este script cai junto; por isso o alarme externo continua necessario.
#
# ITEM 9.2 DA VARREDURA, segunda metade (medido em 22/10/2026)
#
# Dois defeitos juntos, e eles se somavam:
#
#   1. `docker restart api` nao resolve o caso em que NAO EXISTE container chamado `api`. E esse e
#      justamente o estado que o deploy deixava quando o passo 8 falhava: o antigo renomeado para
#      `api-anterior` e o novo sem subir. O restart falhava.
#
#   2. E o marcador `/tmp/bora-falhou` era apagado DE QUALQUER JEITO, inclusive quando o restart
#      falhava. Resultado: o ciclo seguinte achava que era "a primeira falha", criava o marcador de
#      novo, e no outro tentava reiniciar outra vez. O vigia alternava para sempre entre "primeira
#      falha" e "reiniciando", sem nunca escalar e sem nunca consertar -- e o log parecia atividade.
#
# Agora: ele tenta devolver o `api-anterior` quando o `api` nao existe, e so apaga o marcador quando o
# site VOLTA. Enquanto nao voltar, cada ciclo escreve que continua fora, com o numero de tentativas.
#
# ITEM 9.7 DA VARREDURA (medido em 23/10/2026)
#
# Este vigia olhava o `/actuator/health`, que AGREGA os indicadores do Spring -- e um deles e o do
# banco. Medido num teste contra a aplicacao de verdade: o health cheio tem o componente `db`. Entao
# quando o RDS piscava, o vigia lia DOWN e REINICIAVA A API.
#
# Reiniciar nao conserta banco. A API nova sobe, acha o banco fora do ar, e o ciclo se repete -- e a
# cada reinicio as requisicoes em voo morrem. O vigia virava o problema.
#
# Agora ele pergunta ao grupo `viva`, que olha SO o processo (`ping`): "a JVM esta de pe e
# atendendo?". E essa a pergunta que justifica um reinicio. Quando o processo esta vivo mas o sistema
# esta DOWN, ele NAO reinicia: escreve que o problema e DEPOIS da API -- e aí quem le o log sabe
# olhar o banco em vez de ficar esperando o reinicio resolver.
LOG=/home/ubuntu/backups/vigia.log
MARCA=/tmp/bora-falhou

# O PROCESSO atende? (grupo `viva` = so o ping; nao depende de banco nem de terceiro)
saude() { curl -s -o /dev/null -w "%{http_code}" --max-time 20 https://borahapp.com.br/actuator/health/viva; }
# O SISTEMA esta inteiro? (health cheio: agrega o banco)
sistema() { curl -s -o /dev/null -w "%{http_code}" --max-time 20 https://borahapp.com.br/actuator/health; }

CODE=$(saude)
if [ "$CODE" = "200" ]; then
  if [ -f "$MARCA" ]; then
    echo "$(date -Is) VOLTOU (HTTP 200) depois de $(cat "$MARCA" 2>/dev/null) tentativa(s)" >> "$LOG"
  fi
  rm -f "$MARCA"
  exit 0
fi

if [ ! -f "$MARCA" ]; then
  echo "$(date -Is) primeira falha (HTTP $CODE) — vou conferir de novo no proximo ciclo" >> "$LOG"
  echo 0 > "$MARCA"
  exit 0
fi

TENTATIVAS=$(( $(cat "$MARCA" 2>/dev/null || echo 0) + 1 ))
echo "$TENTATIVAS" > "$MARCA"
echo "$(date -Is) FORA DO AR (HTTP $CODE) — tentativa $TENTATIVAS" >> "$LOG"

# Item 9.7: o processo nao respondeu. Antes de reiniciar, confere se a API esta de pe por dentro --
# se ela responde no container e o que falha e so a rota publica, o problema e o Caddy ou a rede, e
# reiniciar a API tampouco resolve.
DENTRO=$(docker exec api curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
  localhost:8080/actuator/health/viva 2>/dev/null)
if [ "$DENTRO" = "200" ]; then
  echo "$(date -Is) a API responde DENTRO do container (HTTP $DENTRO) e nao responde de fora." \
       "O problema esta no Caddy, no DNS ou na rede -- NAO vou reiniciar a API, que esta sadia." >> "$LOG"
  docker ps --format "{{.Names}}  {{.Status}}" >> "$LOG" 2>&1 || true
  exit 0
fi

# O container `api` existe? Se nao, o caso mais provavel e um deploy que falhou no meio e deixou o
# anterior renomeado. Devolver ele e melhor que ficar tentando reiniciar o que nao existe.
if ! docker inspect api >/dev/null 2>&1; then
  echo "$(date -Is) NAO EXISTE container 'api'. Tentando devolver o 'api-anterior'." >> "$LOG"
  if docker inspect api-anterior >/dev/null 2>&1; then
    docker rename api-anterior api >> "$LOG" 2>&1 || true
    docker start api >> "$LOG" 2>&1 || true
  else
    echo "$(date -Is) nao ha 'api-anterior' para devolver. ISTO PRECISA DE MAO HUMANA:" >> "$LOG"
    docker ps -a --format "{{.Names}}  {{.Status}}" >> "$LOG" 2>&1 || true
  fi
else
  docker restart api >> "$LOG" 2>&1 || echo "$(date -Is) o restart FALHOU" >> "$LOG"
fi

sleep 45
DEPOIS=$(saude)
echo "$(date -Is) depois da tentativa $TENTATIVAS: HTTP $DEPOIS" >> "$LOG"

# O marcador SO sai quando o site volta. Enquanto nao voltar, o contador sobe e o log diz que
# continua fora -- em vez de reiniciar o ciclo e parecer que foi a primeira vez.
if [ "$DEPOIS" = "200" ]; then
  echo "$(date -Is) VOLTOU depois de $TENTATIVAS tentativa(s)" >> "$LOG"
  rm -f "$MARCA"
  # Item 9.7: o processo voltou. Mas o SISTEMA pode continuar quebrado -- e aí o reinicio nao era a
  # cura e ninguem fica sabendo. Esta linha e a diferenca entre "resolvido" e "parece resolvido".
  SIST=$(sistema)
  if [ "$SIST" != "200" ]; then
    echo "$(date -Is) ATENCAO: o processo voltou, mas o health CHEIO continua em HTTP $SIST." \
         "O que esta fora e DEPOIS da API -- provavelmente o banco. Reiniciar a API nao resolve" \
         "isto: olhe o RDS." >> "$LOG"
  fi
elif [ "$TENTATIVAS" -ge 3 ]; then
  echo "$(date -Is) !!! $TENTATIVAS tentativas e o site continua fora (HTTP $DEPOIS). O vigia nao" \
       "consegue resolver sozinho -- precisa de mao humana." >> "$LOG"
fi
