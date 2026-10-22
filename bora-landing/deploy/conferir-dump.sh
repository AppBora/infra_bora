#!/bin/bash
# Confere se um dump do Postgres (-Fc) presta. Usado pelo backup-bora.sh e chamavel a mao.
#
#   ./conferir-dump.sh /home/ubuntu/backups/bora-20261022-0615.dump
#
# Sai 0 quando o arquivo esta bom, 1 quando nao -- e DIZ o motivo.
#
# ITEM 9.8 DA VARREDURA. Esta conferencia mora num script separado de proposito: enquanto ela estava
# dentro do backup, provar que ela REPROVA um dump ruim exigia desligar o pg_dump no meio do script, e
# a primeira tentativa de fazer isso falhou calada -- o pg_dump rodou de novo e regravou o arquivo que
# eu tinha cortado, e o teste "passou" medindo um dump bom. Separado, o teste e uma linha.
#
# AS DUAS CONFERENCIAS, E POR QUE SAO ESTAS (medido em 22/10/2026)
#
#   1. `pg_restore -f /dev/null` -- descompacta e le TODOS os blocos de dados, jogando o SQL no lixo.
#      E o unico que pega truncamento. Medido num dump de 3,3 MB: o bom passa em 0,46s; cortado em 90%
#      reprova com "could not read from input file: end of file".
#
#      O que NAO serve, e eu testei antes de confiar:
#        - `pg_restore --list`: o indice do formato custom nao fica no fim do arquivo. O dump cortado
#          em 90% devolveu as MESMAS 280 entradas e saiu com sucesso.
#        - a assinatura `PGDMP`: esta nos primeiros 5 bytes e sobrevive a qualquer corte.
#
#   2. `pg_restore --list | grep -c` -- quantas entradas o dump tem. Um dump VAZIO e bem formado passa
#      na primeira conferencia; esta pega isso.
#
# Nenhuma das duas toca em banco nenhum: as duas so leem o arquivo.
set -e

ARQ="$1"
MINIMO="${2:-50}"   # o dump deste banco tinha 280 entradas em 22/10/2026

if [ -z "$ARQ" ]; then
  echo "uso: $0 <arquivo.dump> [minimo-de-entradas]" >&2
  exit 2
fi
if [ ! -f "$ARQ" ]; then
  echo "CONFERENCIA REPROVADA: $ARQ nao existe" >&2
  exit 1
fi

DIR=$(cd "$(dirname "$ARQ")" && pwd)
NOME=$(basename "$ARQ")

# 1) da para ler o arquivo inteiro?
ERRO=$(docker run --rm -v "$DIR":/bkp postgres:16 \
         pg_restore -f /dev/null "/bkp/$NOME" 2>&1 >/dev/null) && LEU=1 || LEU=0
if [ "$LEU" = "0" ]; then
  echo "CONFERENCIA REPROVADA: $NOME nao pode ser lido inteiro -- $(echo "$ERRO" | head -1)" >&2
  exit 1
fi

# 2) tem conteudo?
ENTRADAS=$(docker run --rm -v "$DIR":/bkp postgres:16 \
             pg_restore --list "/bkp/$NOME" 2>/dev/null | grep -c "^[0-9]" || true)
if [ -z "$ENTRADAS" ] || [ "$ENTRADAS" -lt "$MINIMO" ]; then
  echo "CONFERENCIA REPROVADA: $NOME tem $ENTRADAS entrada(s), esperado ao menos $MINIMO" >&2
  exit 1
fi

echo "$ENTRADAS"
