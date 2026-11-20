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

# ==================================================================================================
# DE ONDE VEM A URL DO ALARME (20/11/2026)
#
# O dono escolheu Telegram. A URL de um bot do Telegram CARREGA o token dentro dela
# (https://api.telegram.org/bot<TOKEN>/sendMessage): ela e SEGREDO, nao configuracao.
#
# Por isso ela NAO entra no crontab, onde 'crontab -l' a mostraria, nem na linha de comando, onde
# 'ps' a mostraria. Ela mora num arquivo so do dono, modo 600, lido com 'grep | cut' -- NUNCA com
# 'source'. Em 30/10/2026 um 'source' num arquivo de segredo imprimiu a chave de producao do Asaas
# no meio de uma tarefa. Aqui isso nao tem como acontecer: nada deste arquivo e executado, so lido.
#
# A variavel de ambiente, quando existe, GANHA do arquivo -- e assim da para testar o envio sem
# tocar no arquivo do dono.
ARQ_ALARME=/home/ubuntu/.bora-alarme
le_segredo() { [ -r "$ARQ_ALARME" ] && grep -m1 "^$1=" "$ARQ_ALARME" 2>/dev/null | cut -d= -f2- ; }
: "${BORA_ALARME_WEBHOOK:=$(le_segredo BORA_ALARME_WEBHOOK)}"
: "${BORA_ALARME_CHAT:=$(le_segredo BORA_ALARME_CHAT)}"
MARCA=/tmp/bora-falhou
# Marcador separado: o processo pode estar vivo e o sistema fora. Sao duas historias diferentes.
MARCA_SISTEMA=/tmp/bora-sistema-fora

# O PROCESSO atende? (grupo `viva` = so o ping; nao depende de banco nem de terceiro)
saude() { curl -s -o /dev/null -w "%{http_code}" --max-time 20 https://borahapp.com.br/actuator/health/viva; }
# O SISTEMA esta inteiro? (health cheio: agrega o banco)
sistema() { curl -s -o /dev/null -w "%{http_code}" --max-time 20 https://borahapp.com.br/actuator/health; }

# ==================================================================================================
# O ALARME QUE SAI DAQUI (item 3.6 da varredura de 18/11/2026)
#
# O DEFEITO: este vigia nao tinha NENHUM caminho de aviso. Nem curl, nem e-mail, nem webhook --
# tudo ia para `vigia.log`, um arquivo que alguem precisa abrir. A prova esta no proprio log, em
# 08/11: "o vigia ficou 2940 minuto(s) SEM RODAR (o cron e de 5 em 5)... Nesse periodo ninguem
# estava olhando o site." Sao 49 HORAS. Ele registrou o proprio silencio, e o registro tambem ficou
# em silencio.
#
# COMO FUNCIONA: `avisar "texto"` manda para a URL em BORA_ALARME_WEBHOOK, que o dono define. Pode
# ser ntfy.sh, Discord, Slack, um bot de WhatsApp -- a decisao e dele, e nenhuma credencial precisa
# ficar neste arquivo.
#
# POR QUE WEBHOOK E NAO O WHATSAPP QUE O SISTEMA JA TEM: o WhatsAppSender mora DENTRO da API. O
# alarme que mais importa e justamente o da API fora do ar -- pedir para a API avisar que a API caiu
# nao funciona. O webhook e de fora e nao depende de nada nosso estar de pe.
#
# E SE NAO ESTIVER CONFIGURADO: o log diz isso, toda vez que um alarme deixa de sair. Mesmo padrao
# do `backup-bora.sh` com o BORA_BACKUP_S3 -- a ausencia fica VISIVEL em vez de silenciosa. Um aviso
# que nao sai e pior que nenhum, porque da a impressao de que alguem foi avisado.
# ==================================================================================================
avisar() {
  local texto="$1"
  echo "$(date -Is) ALARME: $texto" >> "$LOG"
  if [ -z "${BORA_ALARME_WEBHOOK:-}" ]; then
    echo "$(date -Is) ATENCAO: o alarme acima NAO foi enviado a ninguem (BORA_ALARME_WEBHOOK nao" \
         "definido). Enquanto essa variavel nao existir, este log e o unico lugar onde a queda" \
         "aparece -- e e um arquivo que alguem precisa abrir." >> "$LOG"
    return 0
  fi
  # O texto e nosso, mas escapar e barato: aspa ou barra invertida solta quebraria o JSON e o aviso
  # sumiria calado, que e exatamente o modo de falha que este bloco existe para impedir.
  #
  # E e expansao do proprio bash, nao `sed`: a primeira versao disto usava
  # `sed -e 's/\/\\/g'` e chegou ao arquivo com uma barra invertida de menos. O sed recusava a
  # expressao, `$seguro` saia VAZIO, e o webhook recebia `{"message":""}` -- um alarme que chega sem
  # dizer o que aconteceu. Medido com um recebedor local em 19/11/2026. Aqui nao ha nivel de escape
  # para errar.
  local seguro="$texto"
  seguro=${seguro//\\/\\\\}      # barra invertida -> duas
  seguro=${seguro//\"/\\\"}      # aspa -> aspa escapada
  seguro=${seguro//$'\n'/ }      # quebra de linha -> espaco
  seguro=${seguro//$'\r'/ }
  seguro=${seguro//$'\t'/ }
  # O CORPO DEPENDE DE QUEM RECEBE, e isto NAO e detalhe de estilo: o Telegram RECUSA o corpo
  # generico. Ele quer {"chat_id":...,"text":...}; Discord e ntfy aceitam o {"title","message"}.
  local corpo
  case "$BORA_ALARME_WEBHOOK" in
    *api.telegram.org*)
      if [ -z "${BORA_ALARME_CHAT:-}" ]; then
        echo "$(date -Is) ATENCAO: a URL e do Telegram mas BORA_ALARME_CHAT nao esta definido --" \
             "o alarme acima NAO foi enviado. Falta a linha BORA_ALARME_CHAT= em $ARQ_ALARME." >> "$LOG"
        return 0
      fi
      corpo="{\"chat_id\":\"$BORA_ALARME_CHAT\",\"text\":\"BoraHapp: $seguro\"}" ;;
    *)
      corpo="{\"title\":\"BoraHapp\",\"message\":\"$seguro\"}" ;;
  esac

  # CONFERE O CODIGO HTTP, e nao so o exit do curl. E a diferenca que importa com o Telegram: corpo
  # errado devolve 400, mas o curl TERMINA BEM -- ele entregou a requisicao. Com o teste antigo
  # ("if curl ...") o log escreveria "alarme enviado" para um alarme que o Telegram jogou fora. Um
  # aviso que o log JURA ter mandado e pior que um que ele admite ter perdido.
  local http
  http=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 -X POST \
       -H 'Content-Type: application/json' \
       --data-binary "$corpo" \
       "$BORA_ALARME_WEBHOOK" 2>>"$LOG")
  if [ "${http:-000}" -ge 200 ] && [ "${http:-000}" -lt 300 ]; then
    echo "$(date -Is) alarme enviado (HTTP $http)" >> "$LOG"
  else
    echo "$(date -Is) O ENVIO DO ALARME FALHOU (HTTP ${http:-000}). O texto esta na linha de cima" \
         "deste log." >> "$LOG"
  fi
}

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
    avisar "O vigia ficou $MINUTOS minuto(s) SEM RODAR. Nesse periodo ninguem estava olhando o site. Ou a maquina reiniciou, ou o cron parou -- confira com 'crontab -l' e 'uptime'."
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
    avisar "DISCO em ${USO}% usado, ${LIVRE_MB} MB livres. Disco cheio nao derruba o site na hora: primeiro o backup falha, depois o deploy. Os maiores ocupantes estao no vigia.log."
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
      avisar "O certificado do site vence em $DIAS dia(s) ($FIM) e a renovacao automatica do Caddy ja deveria ter acontecido. No dia em que vencer, o site fica inacessivel para TODO mundo, com erro de seguranca no navegador."
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
  # ITEM 3.7 DA VARREDURA (18/11/2026): ATE AQUI ELE PARAVA, E ISSO ERA O DEFEITO.
  #
  # Ele escrevia "o problema esta no Caddy, no DNS ou na rede" e dava `exit 0` -- SEM NUNCA OLHAR O
  # CONTAINER `caddy`. O log tem 13 linhas desse caso. Com o Caddy travado, o site fica fora para
  # todo mundo e o vigia so repetia a frase, de cinco em cinco minutos, para sempre.
  #
  # Nomear tres culpados possiveis e nao conferir nenhum nao e diagnostico: e desistir com
  # vocabulario tecnico. Dois dos tres (Caddy e rede) este script PODE medir daqui.
  ESTADO_CADDY=$(docker inspect caddy --format '{{.State.Status}}' 2>/dev/null || echo "NAO_EXISTE")
  echo "$(date -Is) estado do container caddy: $ESTADO_CADDY" >> "$LOG"

  if [ "$ESTADO_CADDY" = "NAO_EXISTE" ]; then
    avisar "O site esta FORA. A API esta sadia por dentro, e NAO EXISTE container 'caddy' neste servidor. Isto precisa de mao humana."
    exit 0
  fi

  if [ "$ESTADO_CADDY" != "running" ]; then
    # Aqui a causa esta MEDIDA, nao suposta -- e reiniciar e o mesmo mandato que este vigia ja tem
    # para o container `api`.
    echo "$(date -Is) o caddy esta '$ESTADO_CADDY'. Reiniciando o CADDY (e nao a API)." >> "$LOG"
    docker restart caddy >> "$LOG" 2>&1 || echo "$(date -Is) o restart do caddy FALHOU" >> "$LOG"
    sleep 20
    VOLTOU=$(saude)
    if [ "$VOLTOU" = "200" ]; then
      echo "$(date -Is) VOLTOU: o caddy estava '$ESTADO_CADDY' e o restart resolveu." >> "$LOG"
      rm -f "$MARCA"
      avisar "O site caiu porque o Caddy estava '$ESTADO_CADDY'. Eu reiniciei o Caddy e o site VOLTOU. A API nunca ficou doente."
    else
      avisar "O site esta FORA. A API esta sadia por dentro, o Caddy estava '$ESTADO_CADDY', eu reiniciei e o site AINDA nao voltou (HTTP $VOLTOU). Isto precisa de mao humana."
    fi
    exit 0
  fi

  # Caddy rodando e site fora: sobrou configuracao do Caddy, DNS ou rede. Essas tres este script nao
  # resolve -- mas agora ele diz QUAL sobrou, em vez de listar as tres sem conferir nenhuma.
  echo "$(date -Is) o caddy esta RODANDO e o site continua fora. Sobrou configuracao do Caddy, DNS ou rede." >> "$LOG"
  docker logs --tail 20 caddy >> "$LOG" 2>&1 || true
  avisar "O site esta FORA. A API esta sadia por dentro e o Caddy esta RODANDO -- entao o que sobrou e a configuracao do Caddy, o DNS ou a rede. As ultimas 20 linhas do log do Caddy estao no vigia.log. Isto precisa de mao humana."
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
    avisar "O site esta FORA e nao existe container 'api' nem 'api-anterior' neste servidor. O deploy provavelmente falhou no meio. Isto precisa de mao humana AGORA."
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
  avisar "O site esta FORA ha $TENTATIVAS tentativas de reinicio (HTTP $DEPOIS). O vigia nao consegue resolver sozinho. Isto precisa de mao humana."
fi
