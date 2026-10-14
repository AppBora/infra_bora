#!/bin/bash
# Backup diario do banco do Bora. Criado em 29/09/2026 depois da revisao dos agentes: o backup
# automatico da AWS existe mas nunca foi testado; este aqui ja foi (restaurado e conferido).
# Guarda 14 dias. O arquivo tem dado de cliente, entao fica 600. Tudo roda dentro do container
# (o arquivo nasce como root; limpar e proteger de fora daria erro de permissao).
set -e
DEST=/home/ubuntu/backups
mkdir -p "$DEST"
docker run --rm --network bora --env-file /home/ubuntu/bora/api.env -v "$DEST":/bkp postgres:16 sh -c \
  "H=\$(echo \"\$SPRING_DATASOURCE_URL\" | sed \"s#jdbc:postgresql://##; s#/.*##\"); \
   PGPASSWORD=\"\$SPRING_DATASOURCE_PASSWORD\" pg_dump -h \"\${H%%:*}\" -p 5432 -U \"\$SPRING_DATASOURCE_USERNAME\" -d bora -Fc -f /bkp/bora-\$(date +%Y%m%d-%H%M).dump && \
   chmod 600 /bkp/*.dump && chown $(id -u):$(id -g) /bkp/*.dump && find /bkp -name \"bora-*.dump\" -mtime +14 -delete"
ULTIMO=$(ls -t "$DEST"/bora-*.dump | head -1)
echo "$(date -Is) backup ok: $ULTIMO ($(du -h "$ULTIMO" | cut -f1))"

# O dump nasce root (o container roda como root) e ninguem de fora conseguia nem copiar:
# na pratica isso impedia qualquer copia para fora da maquina, que e o ponto do backup.
# A linha acima ja entrega o arquivo ao usuario ubuntu; esta aqui garante os antigos.
chown ubuntu:ubuntu "$DEST"/*.dump 2>/dev/null || true

# COPIA PARA FORA DA MAQUINA (ainda nao ligada: precisa de credencial da AWS).
# Hoje os backups vivem no MESMO disco do servidor: se a instancia se perder, eles vao junto.
# Para ligar, crie um usuario IAM so com permissao de gravar neste bucket e descomente:
#   aws s3 cp "$ARQ" s3://SEU-BUCKET/bora/ --storage-class STANDARD_IA
