#!/bin/bash
# Ensaio de restauracao: restaura o dump mais novo num Postgres descartavel e CONFERE o que chegou.
#
# ITEM 9.9 DA VARREDURA (23/10/2026)
#
# A varredura dizia: "no pior caso se perdem ~28 horas, e a ultima restauracao testada foi em 29/09,
# na mao". A segunda metade e o que este script resolve: backup que ninguem restaura e esperanca, nao
# backup. E restaurar na mao uma vez em setembro nao diz nada sobre o dump de hoje.
#
# O `conferir-dump.sh` (item 9.8) prova que o arquivo esta INTEIRO -- ele le todos os blocos de dados.
# Isso nao e a mesma coisa que provar que ele RESTAURA e que o conteudo faz sentido: schema que o
# Flyway mudou, extensao que falta, tabela que veio vazia porque o pg_dump rodou durante uma migracao.
# Este script faz a restauracao de verdade e conta as linhas das tabelas que importam.
#
# SEGURANCA: nada aqui toca o banco de producao. O destino e um container novo, com nome proprio, que
# e apagado no fim (inclusive se der erro). Nenhuma credencial de producao e usada na restauracao --
# o container sobe com uma senha local e descartavel.
set -u

DEST=${1:-/home/ubuntu/backups}
NOME_CT=bora-ensaio-$$
PORTA=0           # o Docker escolhe; nao disputa porta com nada
SENHA=ensaio-local-descartavel

# O `-v` NAO E DETALHE (achado medindo o disco em 27/10/2026).
#
# A imagem do Postgres declara um VOLUME para /var/lib/postgresql/data. Sem `--rm` no `docker run` e
# sem `-v` aqui, cada ensaio deixava para tras um volume anonimo de ~53 MB -- o initdb mais o banco
# restaurado. Com o ensaio rodando por cron todo domingo, isso e 53 MB por semana que ninguem ve,
# porque `docker volume ls` nao aparece em nenhum painel.
#
# MEDIDO NO SERVIDOR: 5 volumes orfaos, 260 MB no total, e o mais novo criado em 25/10 as 03:40 --
# exatamente o horario do cron deste script (40 3 * * 0).
limpar() { docker rm -f -v "$NOME_CT" >/dev/null 2>&1 || true; }
trap limpar EXIT

dizer() { printf '%s %s\n' "$(date -Is)" "$*"; }

# ---------------------------------------------------------------- o dump mais novo
ARQ=$(ls -t "$DEST"/bora-*.dump 2>/dev/null | head -1)
if [ -z "${ARQ:-}" ]; then
  dizer "ENSAIO FALHOU: nao ha nenhum dump em $DEST."
  exit 1
fi
dizer "ensaiando a restauracao de $ARQ ($(du -h "$ARQ" | cut -f1))"

# ---------------------------------------------------------------- um Postgres descartavel
if ! docker run -d --name "$NOME_CT" -e POSTGRES_PASSWORD="$SENHA" -e POSTGRES_DB=ensaio \
      -p "$PORTA":5432 postgres:16 >/dev/null; then
  dizer "ENSAIO FALHOU: nao consegui subir o Postgres de ensaio."
  exit 1
fi

for _ in $(seq 1 30); do
  docker exec "$NOME_CT" pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 2
done
if ! docker exec "$NOME_CT" pg_isready -U postgres >/dev/null 2>&1; then
  dizer "ENSAIO FALHOU: o Postgres de ensaio nao ficou pronto."
  exit 1
fi

# ---------------------------------------------------------------- a restauracao
docker cp "$ARQ" "$NOME_CT":/tmp/dump.dump >/dev/null
# `--no-owner`: o dono das tabelas na producao e o boraadmin, que nao existe aqui. Sem isto a
# restauracao enche o log de erro de permissao e mascara o que importa.
SAIDA=$(docker exec -e PGPASSWORD="$SENHA" "$NOME_CT" \
  pg_restore --no-owner --no-privileges -U postgres -d ensaio /tmp/dump.dump 2>&1) || true
ERROS=$(printf '%s' "$SAIDA" | grep -ci "error" || true)
if [ "$ERROS" -gt 0 ]; then
  dizer "ENSAIO FALHOU: a restauracao deu $ERROS erro(s):"
  printf '%s\n' "$SAIDA" | grep -i "error" | head -10
  exit 1
fi

# ---------------------------------------------------------------- o conteudo faz sentido?
# As tabelas que, vazias, querem dizer que o backup nao serve para nada. `loja` e a raiz de tudo;
# `usuario` e o que permite entrar; `pedido` e o historico; `produto` e o cardapio.
contar() {
  docker exec -e PGPASSWORD="$SENHA" "$NOME_CT" \
    psql -t -A -U postgres -d ensaio -c "select count(*) from $1" 2>/dev/null | tr -d '[:space:]'
}

FALHOU=0
for t in loja usuario produto pedido; do
  N=$(contar "$t")
  if [ -z "${N:-}" ]; then
    dizer "ENSAIO FALHOU: a tabela '$t' nao existe no dump restaurado."
    FALHOU=1
  elif [ "$N" -lt 1 ]; then
    dizer "ENSAIO FALHOU: a tabela '$t' veio VAZIA. Backup que restaura vazio nao e backup."
    FALHOU=1
  else
    dizer "ok: $t com $N linha(s)"
  fi
done

# A versao do schema tem que estar la: dump restaurado sem o historico do Flyway nao sobe a aplicacao.
VERSAO=$(docker exec -e PGPASSWORD="$SENHA" "$NOME_CT" \
  psql -t -A -U postgres -d ensaio -c \
  "select max(version::int) from flyway_schema_history where success" 2>/dev/null | tr -d '[:space:]')
if [ -z "${VERSAO:-}" ]; then
  dizer "ENSAIO FALHOU: nao achei o historico do Flyway no dump. A aplicacao nao subiria nele."
  FALHOU=1
else
  dizer "ok: schema na versao V$VERSAO"
fi

if [ "$FALHOU" -ne 0 ]; then
  dizer "!!! O BACKUP MAIS NOVO NAO SERVE. Isto precisa de mao humana AGORA."
  exit 1
fi

dizer "ENSAIO OK: $ARQ restaura e tem conteudo. (Isto nao substitui a copia para FORA da instancia:"
dizer "se esta maquina se perder, os dumps vao com ela -- ver item 9.9 da varredura.)"
