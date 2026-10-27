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
# Marcador separado: o processo pode estar vivo e o sistema fora. Sao duas historias diferentes.
MARCA_SISTEMA=/tmp/bora-sistema-fora

# O PROCESSO atende? (grupo `viva` = so o ping; nao depende de banco nem de terceiro)
saude() { curl -s -o /dev/null -w "%{http_code}" --max-time 20 https://borahapp.com.br/actuator/health/viva; }
# O SISTEMA esta inteiro? (health cheio: agrega o banco)
sistema() { curl -s -o /dev/null -w "%{http_code}" --max-time 20 https://borahapp.com.br/actuator/health; }

# ==================================================================================================
# O QUE ELE NAO OLHAVA (achado pelo QA em 26/10/2026, medido em 27/10)
#
# O vigia perguntava uma coisa so: "o site responde?". Tres coisas que matam o sistema sem o site
# parar de responder ficavam fora:
#
#   1. DISCO. Disco cheio nao derruba o site na hora: primeiro o backup falha, depois o deploy, e so
#      no fim a aplicacao. Medido em 27/10: 22% de 58 GB, com 49 imagens Docker somando 7,86 GB (cada
#      deploy deixa uma) e 232 MB de backups. Nenhum deles encolhe sozinho.
#   2. CERTIFICADO. O Caddy renova sozinho aos 30 dias restantes. Quando a renovacao falha, nada
#      avisa -- e no dia em que vence, o site inteiro fica inacessivel para todo mundo, com erro de
#      seguranca no navegador do cliente. Medido em 27/10: vence em 2 de dezembro.
#   3. A PROPRIA MORTE. Se o cron parar, ou a maquina reiniciar e nao voltar, este script simplesmente
#      para de rodar -- e um vigia calado parece um vigia satisfeito.
#
# O ponto 3 tem limite honesto: nenhum script detecta a propria ausencia de dentro. O que da e deixar
# BATIDA em arquivo e, na volta, dizer quanto tempo ficou sem rodar. Isso pega cron desligado e
# reinicio da maquina, e nao pega "a instancia morreu e nao voltou" -- esse so um alarme de fora pega,
# como o cabecalho deste arquivo ja diz desde setembro.
# ==================================================================================================

# A batida mora com os backups, e nao em /tmp, de proposito: /tmp e limpo no reinicio, e reinicio e
# exatamente um dos silencios que isto existe para contar.
BATIDA=/home/ubuntu/backups/.vigia-batida
MARCA_DISCO=/home/ubuntu/backups/.vigia-disco
MARCA_CERT=/home/ubuntu/backups/.vigia-cert

# Teto do disco: avisa com 85% usado OU menos de 5 GB livres. Os dois porque num disco de 58 GB os
# 15% que faltam ainda sao 8,7 GB, e num disco maior a porcentagem avisaria tarde.
DISCO_PCT_LIMITE=85
DISCO_LIVRE_MIN_MB=5120
# O Caddy renova aos 30 dias restantes. Abaixo de 20, a renovacao ja deveria ter acontecido e nao
# aconteceu: ha algo errado e sobram 20 dias para alguem olhar.
CERT_DIAS_LIMITE=20

# ---------------------------------------------------------------- 3. a propria morte
AGORA=$(date +%s)
if [ -f "$BATIDA" ]; then
  ANTES=$(cat "$BATIDA" 2>/dev/null || echo "$AGORA")
  MINUTOS=$(( (AGORA - ANTES) / 60 ))
  # O cron roda de 5 em 5. 15 minutos sao tres ciclos perdidos: nao e atraso, e ausencia.
  if [ "$MINUTOS" -ge 15 ]; then
    echo "$(date -Is) ATENCAO: o vigia ficou $MINUTOS minuto(s) SEM RODAR (o cron e de 5 em 5)."          "Ou a maquina reiniciou, ou o cron parou. Nesse periodo ninguem estava olhando o site."          "Confira com 'crontab -l' e 'uptime'." >> "$LOG"
  fi
fi
echo "$AGORA" > "$BATIDA"

# ---------------------------------------------------------------- 1. disco
USO=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
LIVRE_MB=$(( $(df -P / | awk 'NR==2 {print $4}') / 1024 ))
if [ "${USO:-0}" -ge "$DISCO_PCT_LIMITE" ] || [ "${LIVRE_MB:-999999}" -lt "$DISCO_LIVRE_MIN_MB" ]; then
  CICLOS_D=$(( $(cat "$MARCA_DISCO" 2>/dev/null || echo 0) + 1 ))
  echo "$CICLOS_D" > "$MARCA_DISCO"
  # Fala na primeira vez e a cada 2 horas (24 ciclos de 5 min): disco enche devagar, nao precisa
  # gritar a cada 5 minutos.
  if [ "$CICLOS_D" = "1" ] || [ "$(( CICLOS_D % 24 ))" = "0" ]; then
    echo "$(date -Is) ATENCAO: DISCO em ${USO}% usado, ${LIVRE_MB} MB livres."          "Disco cheio nao derruba o site na hora: primeiro o backup falha, depois o deploy."          "Os tres que mais crescem aqui:" >> "$LOG"
    echo "   imagens docker: $(docker images -q | wc -l) imagem(ns), $(docker system df --format '{{.Size}}' 2>/dev/null | head -1)" >> "$LOG"
    echo "   backups: $(du -sh /home/ubuntu/backups 2>/dev/null | cut -f1) em $(ls /home/ubuntu/backups/*.dump 2>/dev/null | wc -l) dump(s)" >> "$LOG"
    echo "   a pasta do ubuntu: $(du -sh /home/ubuntu 2>/dev/null | cut -f1)" >> "$LOG"
    # Log de container NAO entra nesta lista, e por um motivo: desde 27/10/2026 os dois containers
    # (api e caddy) tem `--log-opt max-size=20m max-file=5`, teto de 100 MB cada. Antes disso o log
    # do Caddy estava com 303 MB num arquivo so. Hoje eles sao os unicos aqui que NAO crescem sem
    # limite -- e a primeira versao desta linha ainda tentava medi-los, com `sudo du` num glob que
    # so expande como root e devolvia 0 rodando como ubuntu. Medir errado e pior que nao medir.
    echo "   imagem antiga do deploy sai com: docker image rm bora-api:vNNN (NAO apague :latest nem a do container de pe)" >> "$LOG"
  fi
else
  if [ -f "$MARCA_DISCO" ]; then
    echo "$(date -Is) o disco voltou ao normal: ${USO}% usado, ${LIVRE_MB} MB livres." >> "$LOG"
    rm -f "$MARCA_DISCO"
  fi
fi

# ---------------------------------------------------------------- 2. certificado
# Uma vez por dia basta: certificado nao vence de surpresa, e a consulta e uma conexao TLS a mais.
CERT_ONTEM=$(cat "$MARCA_CERT" 2>/dev/null || echo 0)
if [ "$(( AGORA - CERT_ONTEM ))" -ge 86400 ]; then
  echo "$AGORA" > "$MARCA_CERT"
  FIM=$(echo | openssl s_client -connect borahapp.com.br:443 -servername borahapp.com.br 2>/dev/null         | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  if [ -z "${FIM:-}" ]; then
    echo "$(date -Is) ATENCAO: nao consegui ler o certificado de borahapp.com.br."          "Pode ser rede, mas tambem pode ser o Caddy fora do ar com o site atendendo em cache." >> "$LOG"
  else
    DIAS=$(( ( $(date -d "$FIM" +%s) - AGORA ) / 86400 ))
    if [ "$DIAS" -le "$CERT_DIAS_LIMITE" ]; then
      echo "$(date -Is) ATENCAO: o certificado vence em $DIAS dia(s) ($FIM)."            "O Caddy renova sozinho aos 30 dias restantes; abaixo de $CERT_DIAS_LIMITE a renovacao ja"            "deveria ter acontecido. Olhe 'docker logs caddy | grep -i acme'. No dia em que vencer, o"            "site fica inacessivel para TODO mundo, com erro de seguranca no navegador." >> "$LOG"
    fi
  fi
fi

CODE=$(saude)
if [ "$CODE" = "200" ]; then
  if [ -f "$MARCA" ]; then
    echo "$(date -Is) VOLTOU (HTTP 200) depois de $(cat "$MARCA" 2>/dev/null) tentativa(s)" >> "$LOG"
  fi
  rm -f "$MARCA"

  # O processo esta de pe. Isso NAO quer dizer que o sistema esta inteiro -- e era exatamente aqui
  # que o vigia ficava mudo. Ele saia neste ponto sem nunca perguntar pelo health cheio, e a frase
  # "o problema e DEPOIS da API" so existia la embaixo, num ramo que so e alcancado DEPOIS de uma
  # tentativa de reinicio. Com o banco fora e a JVM viva, nada era escrito: o vigia acertava em nao
  # reiniciar e errava em nao contar. De madrugada isso e silencio, que e o que ele existe para evitar.
  SIST=$(sistema)
  if [ "$SIST" = "200" ]; then
    if [ -f "$MARCA_SISTEMA" ]; then
      echo "$(date -Is) o SISTEMA voltou (health cheio 200) depois de $(cat "$MARCA_SISTEMA" 2>/dev/null) ciclo(s) fora." >> "$LOG"
      rm -f "$MARCA_SISTEMA"
    fi
  else
    CICLOS=$(( $(cat "$MARCA_SISTEMA" 2>/dev/null || echo 0) + 1 ))
    echo "$CICLOS" > "$MARCA_SISTEMA"
    # Fala alto na primeira vez e a cada 30 min (6 ciclos de 5). Nem inundar o log, nem sumir dele.
    if [ "$CICLOS" = "1" ] || [ "$(( CICLOS % 6 ))" = "0" ]; then
      echo "$(date -Is) ATENCAO: a API esta de pe (viva 200) e o health CHEIO responde HTTP $SIST."            "Ha $CICLOS ciclo(s) de 5 min. O que esta fora e DEPOIS da API -- quase sempre o banco."            "NAO vou reiniciar: reiniciar a API nao levanta o RDS, e so mata as requisicoes em voo." >> "$LOG"
      # Quem esta DOWN, para ninguem ter de adivinhar qual peca e.
      docker exec api curl -s --max-time 10 localhost:8080/actuator/health >> "$LOG" 2>&1 || true
      echo "" >> "$LOG"
    fi
  fi
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
