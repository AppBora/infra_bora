#!/bin/bash
# Backup diario do banco do Bora. Criado em 29/09/2026 depois da revisao dos agentes: o backup
# automatico da AWS existe mas nunca foi testado; este aqui ja foi (restaurado e conferido).
# Guarda 14 dias. O arquivo tem dado de cliente, entao fica 600. Tudo roda dentro do container
# (o arquivo nasce como root; limpar e proteger de fora daria erro de permissao).
#
# ITEM 9.8 DA VARREDURA — O QUE MEDIR MOSTROU (21/10/2026)
#
# A varredura dizia que "um dump cortado passa pelas DUAS CONFERENCIAS e e anotado como ok", e que o
# que fecharia isso seria `pg_restore --list`. Medindo, as duas partes estavam erradas:
#
#   1. Nao havia conferencia NENHUMA. O script fazia o pg_dump, listava o arquivo mais novo com
#      `ls -t` e escrevia "backup ok" com o tamanho. Dump truncado -- disco cheio, container morto no
#      meio, conexao com o RDS caindo -- ficava la com cara de backup bom.
#
#   2. `pg_restore --list` NAO detecta truncamento, e eu testei antes de confiar: cortando um dump de
#      3,3 MB em 90%, o `--list` devolveu as MESMAS 280 entradas e saiu com sucesso. O indice do
#      formato custom nao fica no fim do arquivo; os blocos de dados ficam. Conferir a assinatura
#      PGDMP e ainda mais inutil: ela esta nos primeiros 5 bytes e sobrevive a qualquer corte.
#
# O que de fato pega: `pg_restore -f /dev/null`, que DESCOMPACTA e le todos os blocos de dados,
# escrevendo o SQL no lixo. No mesmo teste, o dump bom passou e o cortado reprovou com
# "could not read from input file: end of file". Custa 0,46s num dump de 3,3 MB -- nada.
set -e
DEST=/home/ubuntu/backups
mkdir -p "$DEST"

# O nome e decidido AQUI, nao com `ls -t` depois: com dois backups no mesmo minuto (deploy mais cron)
# o `ls -t` podia conferir um arquivo e anunciar outro.
NOME="bora-$(date +%Y%m%d-%H%M).dump"
ARQ="$DEST/$NOME"

docker run --rm --network bora --env-file /home/ubuntu/bora/api.env -v "$DEST":/bkp postgres:16 sh -c \
  "H=\$(echo \"\$SPRING_DATASOURCE_URL\" | sed \"s#jdbc:postgresql://##; s#/.*##\"); \
   PGPASSWORD=\"\$SPRING_DATASOURCE_PASSWORD\" pg_dump -h \"\${H%%:*}\" -p 5432 -U \"\$SPRING_DATASOURCE_USERNAME\" -d bora -Fc -f /bkp/$NOME && \
   chmod 600 /bkp/*.dump && chown $(id -u):$(id -g) /bkp/*.dump && find /bkp -name \"bora-*.dump\" -mtime +14 -delete"

# ---------------------------------------------------------------- a conferencia que faltava
# Mora em conferir-dump.sh, ao lado deste script: separada, da para PROVAR que ela reprova um dump
# ruim sem desligar o pg_dump no meio daqui -- e a primeira tentativa de fazer isso falhou calada.
CONFERIR="$(dirname "$0")/conferir-dump.sh"
if [ ! -x "$CONFERIR" ]; then
  echo "$(date -Is) BACKUP SEM CONFERENCIA: nao achei $CONFERIR. O dump pode estar cortado e eu nao"        "tenho como saber." >&2
  exit 1
fi

if ! ENTRADAS=$("$CONFERIR" "$ARQ"); then
  echo "$(date -Is) NAO conte com $ARQ." >&2
  mv "$ARQ" "$ARQ.RUIM" 2>/dev/null || true
  echo "$(date -Is) renomeado para $ARQ.RUIM, para nao ser confundido com backup bom." >&2
  exit 1
fi

echo "$(date -Is) backup ok: $ARQ ($(du -h "$ARQ" | cut -f1), $ENTRADAS entradas, lido inteiro pelo pg_restore)"

# O dump nasce root (o container roda como root) e ninguem de fora conseguia nem copiar:
# na pratica isso impedia qualquer copia para fora da maquina, que e o ponto do backup.
# A linha acima ja entrega o arquivo ao usuario ubuntu; esta aqui garante os antigos.
chown ubuntu:ubuntu "$DEST"/*.dump 2>/dev/null || true

# ---------------------------------------------------------------- a copia para fora, e a verdade
# ITEM 9.9 DA VARREDURA — TAMBEM CORRIGIDO POR MEDICAO (21/10/2026)
# A varredura dizia "a copia para fora as 10:00" e "19 execucoes, nenhuma falha", e calculava perda de
# ~28 horas no pior caso. Medindo o servidor: NAO EXISTE copia para fora. Nao ha script, nao ha
# `copias.log`, e o cron tem apenas este backup (06:15) e o vigia (a cada 5 min).
#
# Entao a situacao real e outra, e pior: os backups vivem SO no disco do servidor. Se a instancia se
# perder, eles vao junto -- e a perda nao e de 28 horas, e de tudo.
#
# Com BORA_BACKUP_S3 definido (ex.: s3://meu-bucket/bora), a copia acontece e o resultado fica no log.
# Sem ela, o script DIZ que nao copiou, em vez de ficar calado: backup que parece existir e pior que
# backup que se sabe que falta.
if [ -n "${BORA_BACKUP_S3:-}" ]; then
  if aws s3 cp "$ARQ" "$BORA_BACKUP_S3/" --storage-class STANDARD_IA >/dev/null 2>&1; then
    echo "$(date -Is) copia para fora ok: $BORA_BACKUP_S3/$NOME"
  else
    echo "$(date -Is) COPIA PARA FORA FALHOU ($BORA_BACKUP_S3). O backup existe SO neste disco." >&2
    exit 1
  fi
else
  echo "$(date -Is) ATENCAO: sem copia para fora (BORA_BACKUP_S3 nao definido). Os backups estao SO" \
       "no disco desta instancia -- se ela se perder, vao junto."
fi
