#!/usr/bin/env bash
#
# Publica o painel (bora-fase-2-frontend) e confere, arquivo por arquivo, que o servidor ficou
# igual ao repositorio.
#
# POR QUE ISTO EXISTE
# A API tinha deploy-api.sh; o frontend subia na mao, por scp dos arquivos que alguem lembrava de
# ter mexido. Em 28/10/2026, antes dos testes manuais do dono, eu comparei o repositorio INTEIRO
# com o servidor e achei QUATRO arquivos de JavaScript com dois dias de atraso -- app.js,
# cardapio.js, integracoes.js e promocoes.js, todos sem o commit a83c104 de 26/10.
#
# Nao estava no ar, por causa disso:
#   - o cliente deixar de ficar preso no checkout;
#   - o cupom enviado ser o aplicado, e nao o texto digitado no campo;
#   - a confirmacao antes de salvar credencial da plataforma -- que no 99Food faz o servidor
#     ESQUECER os tokens de todas as lojas daquele canal.
#
# O commit mexeu em 4 JS e 2 HTML. Os 2 HTML estavam no ar; os 4 JS nao. Foi um scp parcial, e
# scp parcial nao reclama: o deploy "deu certo" e ficou dois dias mentindo.
#
# COMO USAR
#   ./deploy-frontend.sh --ensaio    # diz o que faria, e o que esta diferente hoje. Nao envia nada.
#   ./deploy-frontend.sh             # envia e confere
# De dentro de bora-landing/deploy, com a chave em ~/.ssh/bora-lightsail.pem.
#
# O QUE ELE NAO FAZ
# Nao sobe a landing (bora-landing/ e outro repositorio, publicado a parte) e nao mexe na API.

set -euo pipefail

ENSAIO=0
[ "${1:-}" = "--ensaio" ] && ENSAIO=1

SRV="ubuntu@18.230.57.33"
KEY="$HOME/.ssh/bora-lightsail.pem"
# A pasta de destino sai por variavel para o proprio script poder ser EXERCITADO contra uma pasta
# de teste no servidor antes de encostar em producao. Um script de deploy cujo caminho de envio
# nunca rodou e uma promessa, nao uma ferramenta:
#   BORA_FRONT_REMOTO=/tmp/ensaio-frontend ./deploy-frontend.sh
REMOTO="${BORA_FRONT_REMOTO:-/home/ubuntu/bora/frontend}"
FRONT="$(cd "$(dirname "$0")/../../bora-fase-2-frontend" && pwd)"
TGZ="/tmp/bora-frontend-$(date +%Y%m%d-%H%M%S).tgz"

dizer() { printf '\n=== %s\n' "$*"; }
cd "$FRONT"

# --------------------------------------------------------------------------------- 1
dizer "1/6 a arvore do frontend esta limpa?"
if [ -n "$(git status --porcelain)" ]; then
  echo "ABORTADO: ha mudanca nao commitada no frontend." >&2
  echo "Este script publica o que esta no disco; subir o que nao esta no Git deixa producao" >&2
  echo "com codigo que ninguem consegue achar depois." >&2
  git status --short >&2
  exit 1
fi
echo "ok: $(git log -1 --format='%h %ad %s' --date=short | cut -c1-80)"

# --------------------------------------------------------------------------------- 2
dizer "2/6 que arquivos vao"
# A fonte e `git ls-files`, nao a pasta. Isto NAO e detalhe: a pasta tem backups locais
# (cardapio.js.bak-*, planos.js.bak-*) que o git ignora e que o Caddy SERVIRIA como texto, com o
# codigo antigo exposto em /assets/js/cardapio.js.bak-20261001.
LISTA=$(mktemp)
git ls-files \
  | grep -vE '^(testes|dev|docs)/' \
  | grep -vE '^(\.gitignore|README\.md)$' \
  | grep -vE '\.bak' \
  > "$LISTA"

# E respeita a marca que o proprio arquivo carrega. Hoje so o index.html a tem: os dois
# repositorios publicam na MESMA pasta e os dois tem um index.html -- quem copia por ultimo vence.
# Em 27/10 venceu o do painel, e quem digitava borahapp.com.br caia na tela de login em vez da
# pagina de vendas. A marca e por CONTEUDO, e nao pelo nome, para valer para o proximo arquivo que
# precisar dela sem ninguem lembrar de mexer aqui.
MARCA='ESTE ARQUIVO NAO VAI PARA O SERVIDOR'
MARCADOS=$(grep -lF "$MARCA" $(cat "$LISTA") 2>/dev/null || true)
if [ -n "$MARCADOS" ]; then
  echo "fora, por marca no proprio arquivo:"
  echo "$MARCADOS" | sed 's/^/   /'
  TMP=$(mktemp); grep -vxF -f <(echo "$MARCADOS") "$LISTA" > "$TMP"; mv "$TMP" "$LISTA"
fi
QUANTOS=$(wc -l < "$LISTA")
echo "vao $QUANTOS arquivo(s)"

# --------------------------------------------------------------------------------- 3
dizer "3/6 o que esta diferente hoje"
AQUI=$(mktemp)
while IFS= read -r f; do printf '%s|%s\n' "$f" "$(sha256sum "$f" | cut -c1-16)"; done < "$LISTA" | sort > "$AQUI"
LA=$(mktemp)
ssh -i "$KEY" -o StrictHostKeyChecking=no "$SRV" \
  "cd $REMOTO && while IFS= read -r f; do if [ -f \"\$f\" ]; then printf '%s|%s\n' \"\$f\" \"\$(sha256sum \"\$f\" | cut -c1-16)\"; else printf '%s|AUSENTE\n' \"\$f\"; fi; done | sort" \
  < "$LISTA" > "$LA"
DIFERENTES=$(join -t'|' "$AQUI" "$LA" | awk -F'|' '$2!=$3 {print $1}')
if [ -z "$DIFERENTES" ]; then
  echo "nenhum: o servidor ja esta igual ao repositorio"
else
  echo "$DIFERENTES" | sed 's/^/   /'
  echo "($(echo "$DIFERENTES" | wc -l) de $QUANTOS)"
fi

if [ "$ENSAIO" = "1" ]; then
  dizer "ENSAIO: nada foi enviado"
  rm -f "$LISTA" "$AQUI" "$LA"
  exit 0
fi
if [ -z "$DIFERENTES" ]; then
  dizer "nada a fazer"
  rm -f "$LISTA" "$AQUI" "$LA"
  exit 0
fi

# --------------------------------------------------------------------------------- 4
dizer "4/6 BACKUP do que esta no servidor, antes de sobrescrever"
# O backup vai para /home/ubuntu/backups, FORA da pasta servida. Guardar copia dentro de
# $REMOTO ja aconteceu neste projeto e o Caddy serviu o backup: qualquer um baixava a versao
# anterior do painel inteiro pela URL.
ssh -i "$KEY" -o StrictHostKeyChecking=no "$SRV" \
  "mkdir -p /home/ubuntu/backups && tar czf /home/ubuntu/backups/frontend-\$(date +%Y%m%d-%H%M%S).tgz -C $REMOTO . && ls -lh /home/ubuntu/backups/frontend-*.tgz | tail -1"

# --------------------------------------------------------------------------------- 5
dizer "5/6 envio"
tar czf "$TGZ" -T "$LISTA"
echo "pacote: $(du -h "$TGZ" | cut -f1)"
scp -q -i "$KEY" -o StrictHostKeyChecking=no "$TGZ" "$SRV:/tmp/"
# -m: carimba a hora da extracao. Sem isso o Last-Modified ficaria com a data do arquivo no disco
# do Windows, e o navegador revalidaria contra um carimbo mais velho que o conteudo.
ssh -i "$KEY" -o StrictHostKeyChecking=no "$SRV" \
  "tar xzf /tmp/$(basename "$TGZ") -C $REMOTO -m && rm -f /tmp/$(basename "$TGZ")"
rm -f "$TGZ"
echo "extraido em $REMOTO"

# --------------------------------------------------------------------------------- 6
dizer "6/6 conferencia: o servidor ficou igual?"
# Confere TODOS os arquivos da lista, nao so os que mudaram. O defeito de 26/10 foi exatamente um
# envio parcial que ninguem conferiu -- conferir so o que eu acho que mandei repete o erro.
LA2=$(mktemp)
ssh -i "$KEY" -o StrictHostKeyChecking=no "$SRV" \
  "cd $REMOTO && while IFS= read -r f; do if [ -f \"\$f\" ]; then printf '%s|%s\n' \"\$f\" \"\$(sha256sum \"\$f\" | cut -c1-16)\"; else printf '%s|AUSENTE\n' \"\$f\"; fi; done | sort" \
  < "$LISTA" > "$LA2"
SOBROU=$(join -t'|' "$AQUI" "$LA2" | awk -F'|' '$2!=$3 {printf "   %s  (aqui %s, la %s)\n", $1, $2, $3}')
rm -f "$LISTA" "$AQUI" "$LA" "$LA2"
if [ -n "$SOBROU" ]; then
  echo "FALHOU: o servidor NAO ficou igual ao repositorio:" >&2
  echo "$SOBROU" >&2
  echo "O backup do estado anterior esta em /home/ubuntu/backups/frontend-*.tgz" >&2
  exit 1
fi
echo "ok: os $QUANTOS arquivos tem o mesmo sha256 aqui e no servidor"

dizer "pronto"
echo "O Caddy serve estes arquivos com Cache-Control: no-cache, entao o navegador revalida e pega"
echo "o conteudo novo sem ninguem precisar limpar cache."
