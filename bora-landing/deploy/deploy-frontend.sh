#!/usr/bin/env bash
#
# Publica o PAINEL (bora-fase-2-frontend) e a LANDING (bora-landing) e confere, arquivo por arquivo,
# que o servidor ficou igual aos repositorios.
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
# POR QUE A LANDING ENTROU AQUI (30/10/2026)
# Ela era publicada "a parte", que na pratica queria dizer: na mao, quando alguem lembrava. Em
# 29/10 a paleta dela mudou para o roxo da marca e ficou um dia inteiro fora do ar sem ninguem
# notar -- o mesmo tipo de silencio que este script existe para acabar. Os dois repositorios
# publicam na MESMA pasta do servidor, entao eles precisam subir pela mesma porta, com a mesma
# conferencia e com a mesma deteccao de conflito.
#
# COMO USAR
#   ./deploy-frontend.sh --ensaio      # diz o que faria, e o que esta diferente hoje. Nao envia.
#   ./deploy-frontend.sh               # envia os dois e confere
#   ./deploy-frontend.sh --so-painel   # so o painel
#   ./deploy-frontend.sh --so-landing  # so a landing
# De dentro de bora-landing/deploy, com a chave em ~/.ssh/bora-lightsail.pem.
#
# O QUE ELE NAO FAZ
# Nao mexe na API (e o deploy-api.sh) e NAO APAGA nada do servidor -- so acrescenta e sobrescreve.
# Arquivo que esta la e nao esta em repositorio nenhum ele REPORTA, no passo 4, e deixa para uma
# pessoa decidir. Apagar por conta propria levaria junto o que foi posto la de proposito.

set -euo pipefail

ENSAIO=0
QUAIS="painel landing"
for arg in "$@"; do
  case "$arg" in
    --ensaio)     ENSAIO=1 ;;
    --so-painel)  QUAIS="painel" ;;
    --so-landing) QUAIS="landing" ;;
    *) echo "uso: $0 [--ensaio] [--so-painel|--so-landing]" >&2; exit 1 ;;
  esac
done

SRV="ubuntu@56.126.177.18"
KEY="$HOME/.ssh/bora-lightsail.pem"
# A pasta de destino sai por variavel para o proprio script poder ser EXERCITADO contra uma pasta
# de teste no servidor antes de encostar em producao. Um script de deploy cujo caminho de envio
# nunca rodou e uma promessa, nao uma ferramenta:
#   BORA_FRONT_REMOTO=/tmp/ensaio-frontend ./deploy-frontend.sh
REMOTO="${BORA_FRONT_REMOTO:-/home/ubuntu/bora/frontend}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ_painel="$(cd "$AQUI/../../bora-fase-2-frontend" && pwd)"
RAIZ_landing="$(cd "$AQUI/.." && pwd)"

# O que o servidor tem de proposito e nao vem de repositorio nenhum. So para o passo 4 nao gritar
# sobre eles todo dia.
NAO_E_SOBRA='^(ROTEIRO-DE-TESTE\.html|guia-zira\.html|manifest\.webmanifest)$'

dizer() { printf '\n=== %s\n' "$*"; }
raiz_de() { local n="$1"; eval "echo \"\$RAIZ_$n\""; }

TEMPORARIOS=()
limpar() { for t in "${TEMPORARIOS[@]:-}"; do [ -n "$t" ] && rm -f "$t"; done; }
trap limpar EXIT
novo_temp() { local t; t=$(mktemp); TEMPORARIOS+=("$t"); echo "$t"; }

# --------------------------------------------------------------------------------- 1
dizer "1/6 que arquivos vao"
# A fonte e `git ls-files`, nao a pasta. Isto NAO e detalhe: a pasta tem backups locais
# (cardapio.js.bak-*, planos.js.bak-*) que o git ignora e que o Caddy SERVIRIA como texto, com o
# codigo antigo exposto em /assets/js/cardapio.js.bak-20261001.
#
# E respeita a marca que o proprio arquivo carrega: os dois repositorios tem um index.html e os
# dois publicam na MESMA pasta -- quem copia por ultimo vence. Em 27/10 venceu o do painel, e quem
# digitava borahapp.com.br caia na tela de login em vez da pagina de vendas. A marca e por
# CONTEUDO, e nao pelo nome, para valer para o proximo arquivo que precisar dela sem ninguem
# lembrar de mexer aqui.
MARCA='ESTE ARQUIVO NAO VAI PARA O SERVIDOR'
# A lista e SEMPRE dos DOIS repositorios, mesmo com --so-painel ou --so-landing. O $QUAIS decide o
# que SOBE, nao o que o script CONHECE.
#
# Isto nasceu de um alarme falso no primeiro uso: publicando so a landing, o passo 4 comparou a
# pasta servida com os 12 arquivos dela e acusou 101 "sobras" -- que eram o painel inteiro. Passo
# que grita 101 vezes sem motivo e passo que todo mundo aprende a pular, e ai ele nao serve para
# nada no dia em que a sobra for de verdade.
UNIAO=$(novo_temp)
TODOS="painel landing"

for repo in $TODOS; do
  dir="$(raiz_de "$repo")"
  lista="$(novo_temp)"
  eval "LISTA_$repo=\"\$lista\""
  (
    cd "$dir"
    git ls-files \
      | grep -vE '^(testes|dev|docs|deploy)/' \
      | grep -vE '^(\.gitignore|README\.md)$' \
      | grep -vE '\.bak'
  ) > "$lista"

  marcados=$(cd "$dir" && grep -lF "$MARCA" $(cat "$lista") 2>/dev/null || true)
  if [ -n "$marcados" ]; then
    echo "fora de $repo, por marca no proprio arquivo:"
    echo "$marcados" | sed 's/^/   /'
    tmp=$(novo_temp); grep -vxF -f <(echo "$marcados") "$lista" > "$tmp"; cp "$tmp" "$lista"
  fi
  if echo " $QUAIS " | grep -q " $repo "; then
    echo "$repo: $(wc -l < "$lista") arquivo(s)"
  else
    echo "$repo: $(wc -l < "$lista") arquivo(s) -- NAO sobe agora, mas conta para a conferencia"
  fi
  sed "s|^|$repo\t|" "$lista" >> "$UNIAO"
done

# --------------------------------------------------------------------------------- 2b
# MESMO CAMINHO NOS DOIS REPOSITORIOS = um apaga o outro, e o resultado depende da ORDEM.
#
# Hoje isso acontece com `assets/img/icone-bora.svg` e `assets/img/logo-bora.svg`, que estao nos
# dois e sao IDENTICOS byte a byte -- entao nao da estrago, e o script segue dizendo que existem.
# No dia em que alguem trocar o logo de um lado so, o publicado passa a depender de qual repo subiu
# por ultimo, e ninguem teria como adivinhar isso olhando a tela. Ai ele ABORTA.
# Sempre, e nao so quando os dois sobem: o conflito existe no disco, independente do que vai hoje.
if true; then
  REPETIDOS=$(cut -f2 "$UNIAO" | sort | uniq -d || true)
  if [ -n "$REPETIDOS" ]; then
    conflito=0
    echo "nos DOIS repositorios:"
    while IFS= read -r f; do
      a=$(sha256sum "$RAIZ_painel/$f" | cut -c1-16)
      b=$(sha256sum "$RAIZ_landing/$f" | cut -c1-16)
      if [ "$a" = "$b" ]; then
        echo "   $f (identicos)"
      else
        echo "   $f  *** DIFERENTES: painel $a, landing $b ***" >&2
        conflito=1
      fi
    done <<< "$REPETIDOS"
    if [ "$conflito" = "1" ]; then
      echo "ABORTADO: o mesmo caminho tem conteudo diferente nos dois repositorios." >&2
      echo "Publicar assim faria o que esta no ar depender da ordem do envio. Deixe os dois iguais," >&2
      echo "ou tire o arquivo de um dos lados." >&2
      exit 1
    fi
  fi
fi

# Duas listas, de propositos diferentes:
#   TODOS_CAMINHOS = o que o servidor DEVERIA ter, dos dois repositorios. E com ela que o passo 4
#                    decide o que e sobra.
#   SO_CAMINHOS    = o que sobe AGORA. E com ela que os passos 3 e 6 medem e conferem.
TODOS_CAMINHOS=$(novo_temp)
cut -f2 "$UNIAO" | sort -u > "$TODOS_CAMINHOS"
SO_CAMINHOS=$(novo_temp)
for repo in $QUAIS; do cat "$(eval "echo \"\$LISTA_$repo\"")"; done | sort -u > "$SO_CAMINHOS"
QUANTOS=$(wc -l < "$SO_CAMINHOS")
echo "sobem agora $QUANTOS arquivo(s)"

# --------------------------------------------------------------------------------- 2
dizer "2/6 os arquivos que vao estao commitados?"
# LIMITADO AO QUE VAI SUBIR, e nao a arvore inteira -- a primeira versao disto abortava o deploy
# da landing porque o PROPRIO deploy-frontend.sh estava sendo editado. Barrar a publicacao por
# causa de um arquivo que nunca e publicado ensina a contornar o script, e script que se contorna
# nao protege nada.
#
# O que esta sujo FORA da lista vira aviso: rodar um deploy com o script sendo editado nao impede
# nada, mas deixa de dar para repetir exatamente o que rodou -- e isso merece aparecer.
for repo in $QUAIS; do
  dir="$(raiz_de "$repo")"
  lista="$(eval "echo \"\$LISTA_$repo\"")"
  sujos=$(git -C "$dir" status --porcelain -- . | awk '{print $NF}')
  [ -z "$sujos" ] && { echo "ok $repo: $(git -C "$dir" log -1 --format='%h %ad %s' --date=short -- . | cut -c1-70)"; continue; }
  vao_sujos=$(echo "$sujos" | grep -xF -f "$lista" || true)
  if [ -n "$vao_sujos" ]; then
    echo "ABORTADO: estes arquivos VAO SUBIR e nao estao commitados em $repo:" >&2
    echo "$vao_sujos" | sed 's/^/   /' >&2
    echo "Subir o que nao esta no Git deixa producao com codigo que ninguem acha depois." >&2
    exit 1
  fi
  fora=$(echo "$sujos" | grep -vxF -f "$lista" || true)
  echo "ok $repo: $(git -C "$dir" log -1 --format='%h %ad %s' --date=short -- . | cut -c1-70)"
  [ -n "$fora" ] && { echo "   aviso: ha mudanca nao commitada FORA do que sobe ($(echo "$fora" | wc -l) arquivo(s)):"; echo "$fora" | sed 's/^/      /'; }
done

# --------------------------------------------------------------------------------- 3
dizer "3/6 o que esta diferente hoje"
# So dos repositorios que sobem agora: medir diferenca de um arquivo que nao vai ser enviado faria o
# passo 3 listar trabalho que este comando nao vai fazer.
AQUI_HASH=$(novo_temp)
grep -E "^($(echo $QUAIS | tr ' ' '|'))	" "$UNIAO" | while IFS=$'\t' read -r repo f; do
  printf '%s|%s\n' "$f" "$(sha256sum "$(raiz_de "$repo")/$f" | cut -c1-16)"
done | sort -u > "$AQUI_HASH"
LA=$(novo_temp)
ssh -i "$KEY" -o StrictHostKeyChecking=no "$SRV" \
  "cd $REMOTO && while IFS= read -r f; do if [ -f \"\$f\" ]; then printf '%s|%s\n' \"\$f\" \"\$(sha256sum \"\$f\" | cut -c1-16)\"; else printf '%s|AUSENTE\n' \"\$f\"; fi; done | sort" \
  < "$SO_CAMINHOS" > "$LA"
DIFERENTES=$(join -t'|' "$AQUI_HASH" "$LA" | awk -F'|' '$2!=$3 {print $1}')
if [ -z "$DIFERENTES" ]; then
  echo "nenhum: o servidor ja esta igual aos repositorios"
else
  echo "$DIFERENTES" | sed 's/^/   /'
  echo "($(echo "$DIFERENTES" | wc -l) de $QUANTOS)"
fi

# --------------------------------------------------------------------------------- 4
dizer "4/6 o que esta no servidor e NAO vem de repositorio nenhum"
# Este passo nasceu em 30/10/2026, estendendo o script para a landing: olhando a pasta servida
# achei QUATRO copias antigas de tela -- configuracoes.html.antes-papeis, .antes-sanfona,
# login.html.antes-senha-no-login e pdv.html.antes-cashback --, todas respondendo 200 na internet.
# E o mesmo tipo de sobra que o `.git` era: ninguem poe de proposito, ninguem lembra que esta la, e
# o Caddy serve.
#
# O script REPORTA e nao apaga. Apagar por conta propria levaria junto o ROTEIRO-DE-TESTE.html e o
# guia-zira.html, que foram postos la de proposito e nao estao em repositorio nenhum.
SOBRAS=$(ssh -i "$KEY" -o StrictHostKeyChecking=no "$SRV" \
  "cd $REMOTO && find . -type f -printf '%P\n' | sort" \
  | grep -vxF -f "$TODOS_CAMINHOS" | grep -vE "$NAO_E_SOBRA" || true)
if [ -z "$SOBRAS" ]; then
  echo "nenhuma"
else
  echo "$SOBRAS" | sed 's/^/   /'
  echo "($(echo "$SOBRAS" | wc -l) arquivo(s)). Confira se alguma delas e copia antiga de tela: o"
  echo "Caddy serve tudo o que esta nessa pasta, inclusive o que ninguem lembra de ter deixado."
fi

if [ "$ENSAIO" = "1" ]; then
  dizer "ENSAIO: nada foi enviado"
  exit 0
fi
if [ -z "$DIFERENTES" ]; then
  dizer "nada a fazer"
  exit 0
fi

# --------------------------------------------------------------------------------- 5
dizer "5/6 BACKUP do que esta no servidor, antes de sobrescrever"
# O backup vai para /home/ubuntu/backups, FORA da pasta servida. Guardar copia dentro de
# $REMOTO ja aconteceu neste projeto e o Caddy serviu o backup: qualquer um baixava a versao
# anterior do painel inteiro pela URL.
ssh -i "$KEY" -o StrictHostKeyChecking=no "$SRV" \
  "mkdir -p /home/ubuntu/backups && tar czf /home/ubuntu/backups/frontend-\$(date +%Y%m%d-%H%M%S).tgz -C $REMOTO . && ls -lh /home/ubuntu/backups/frontend-*.tgz | tail -1"

# --------------------------------------------------------------------------------- 6
dizer "6/6 envio"
# Um pacote POR REPOSITORIO, e nao uma pasta de montagem com os dois juntos: assim cada arquivo sai
# da raiz dele, com o caminho dele, e nao ha copia intermediaria onde um lado possa sobrescrever o
# outro sem ninguem ver. A ordem e a do $QUAIS -- e, por causa do passo 2b, ela nao muda o
# resultado: caminho repetido ou e identico nos dois, ou o script ja abortou.
for repo in $QUAIS; do
  lista="$(eval "echo \"\$LISTA_$repo\"")"
  [ -s "$lista" ] || continue
  tgz="/tmp/bora-$repo-$(date +%Y%m%d-%H%M%S).tgz"
  tar czf "$tgz" -C "$(raiz_de "$repo")" -T "$lista"
  echo "$repo: $(du -h "$tgz" | cut -f1)"
  scp -q -i "$KEY" -o StrictHostKeyChecking=no "$tgz" "$SRV:/tmp/"
  # -m: carimba a hora da extracao. Sem isso o Last-Modified ficaria com a data do arquivo no disco
  # do Windows, e o navegador revalidaria contra um carimbo mais velho que o conteudo.
  ssh -i "$KEY" -o StrictHostKeyChecking=no "$SRV" \
    "tar xzf /tmp/$(basename "$tgz") -C $REMOTO -m && rm -f /tmp/$(basename "$tgz")"
  rm -f "$tgz"
done
echo "extraido em $REMOTO"

dizer "conferencia: o servidor ficou igual?"
# Confere TODOS os arquivos da uniao, nao so os que mudaram. O defeito de 26/10 foi exatamente um
# envio parcial que ninguem conferiu -- conferir so o que eu acho que mandei repete o erro.
LA2=$(novo_temp)
ssh -i "$KEY" -o StrictHostKeyChecking=no "$SRV" \
  "cd $REMOTO && while IFS= read -r f; do if [ -f \"\$f\" ]; then printf '%s|%s\n' \"\$f\" \"\$(sha256sum \"\$f\" | cut -c1-16)\"; else printf '%s|AUSENTE\n' \"\$f\"; fi; done | sort" \
  < "$SO_CAMINHOS" > "$LA2"
SOBROU=$(join -t'|' "$AQUI_HASH" "$LA2" | awk -F'|' '$2!=$3 {printf "   %s  (aqui %s, la %s)\n", $1, $2, $3}')
if [ -n "$SOBROU" ]; then
  echo "FALHOU: o servidor NAO ficou igual aos repositorios:" >&2
  echo "$SOBROU" >&2
  echo "O backup do estado anterior esta em /home/ubuntu/backups/frontend-*.tgz" >&2
  exit 1
fi
echo "ok: os $(wc -l < "$SO_CAMINHOS") arquivos tem o mesmo sha256 aqui e no servidor"

dizer "pronto"
echo "O Caddy serve estes arquivos com Cache-Control: no-cache, entao o navegador revalida e pega"
echo "o conteudo novo sem ninguem precisar limpar cache."
