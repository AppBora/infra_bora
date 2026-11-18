#!/usr/bin/env bash
# Prova a decisao do rollback do deploy-api.sh, nos QUATRO pontos em que o passo 8 pode falhar.
#
# POR QUE ESTE SCRIPT EXISTE
# ---------------------------------------------------------------------------------------------
# O rollback comecava SEMPRE com `docker rm -f api`. Isso esta certo em UM dos quatro casos; nos
# outros tres o `api` que esta no servidor E O CONTAINER BOM, e o rollback o destruia -- deixando a
# producao sem nenhum container `api`, sem `api-anterior` para devolver, e com o vigia-bora.sh
# escrevendo "ISTO PRECISA DE MAO HUMANA". Uma falha num passo inofensivo (um nome de tag errado)
# derrubava o site ate alguem entrar no servidor a mao.
#
# Nao da para ensaiar um deploy de verdade sem derrubar o site. Mas a decisao do rollback e logica
# pura sobre o estado do docker -- e isso da para provar. Este script:
#   1. EXTRAI a logica real do deploy-api.sh, entre os marcadores (nao uma copia que envelhece);
#   2. monta cada um dos quatro estados com containers de mentira no docker local;
#   3. roda a logica e confere o que sobrou.
#
# Rode depois de qualquer mexida no rollback:
#   bash deploy/teste-do-rollback.sh
set -u

AQUI="$(cd "$(dirname "$0")" && pwd)"
DEPLOY="$AQUI/deploy-api.sh"
IMAGEM="${IMAGEM_DE_TESTE:-postgres:16}"
FALHAS=0

vermelho() { printf '   REPROVOU: %s\n' "$*" >&2; FALHAS=$((FALHAS + 1)); }
verde()    { printf '   ok: %s\n' "$*"; }

# ------------------------------------------------------------------ 0) nao mexer no que nao e meu
if ! docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
  echo "ABORTADO: o docker nao responde. Suba o Docker Desktop." >&2
  exit 1
fi
# A logica testada mexe em containers chamados exatamente `api` e `api-anterior`. Se existir um
# desses nesta maquina, ele pode ser de verdade -- e este teste o apagaria. Recusa e diz qual e.
for N in api api-anterior; do
  if docker inspect "$N" >/dev/null 2>&1; then
    echo "ABORTADO: ja existe um container chamado '$N' nesta maquina." >&2
    echo "Este teste apaga e renomeia containers com esses nomes exatos, e nao vou" >&2
    echo "mexer num que pode ser seu. Veja o que e e tire do caminho:" >&2
    docker ps -a --filter "name=^${N}$" --format '   {{.Names}}  {{.Status}}  {{.Image}}' >&2
    exit 1
  fi
done

# ------------------------------------------------------------------ 1) extrair a logica de verdade
LOGICA="$(mktemp)"
trap 'rm -f "$LOGICA"; docker rm -f api api-anterior >/dev/null 2>&1 || true' EXIT

awk '/>>>>> INICIO DA LOGICA DO ROLLBACK/{p=1; next} /<<<<< FIM DA LOGICA DO ROLLBACK/{p=0} p' \
  "$DEPLOY" > "$LOGICA"

if [ ! -s "$LOGICA" ]; then
  echo "ABORTADO: nao achei a logica do rollback entre os marcadores em $DEPLOY." >&2
  echo "Se os marcadores foram renomeados, este teste passaria a medir NADA -- por isso ele" >&2
  echo "recusa em vez de ficar verde." >&2
  exit 1
fi
# A premissa do teste: a logica extraida tem de ser a que decide. Sem o `api-anterior` no texto, ela
# nao e a versao nova, e os testes abaixo estariam medindo outra coisa.
grep -q 'api-anterior' "$LOGICA" || {
  echo "ABORTADO: a logica extraida nao menciona api-anterior. Nao e a versao que decide por fato." >&2
  exit 1
}
echo "logica extraida de deploy-api.sh ($(wc -l < "$LOGICA") linhas)"

limpar()  { docker rm -f api api-anterior >/dev/null 2>&1 || true; }
subir()   { docker run -d --name "$1" "$IMAGEM" sleep 3600 >/dev/null; }
idDe()    { docker inspect "$1" --format '{{.Id}}' 2>/dev/null || echo "NAO-EXISTE"; }
rodando() { [ "$(docker inspect "$1" --format '{{.State.Running}}' 2>/dev/null || echo false)" = "true" ]; }

rodarLogica() { bash "$LOGICA" >/dev/null 2>&1 || true; }

# ------------------------------------------------------------------ caso A: o `docker tag` falhou
# Estado: `api` RODANDO e sadio, servindo o site. `api-anterior` nunca existiu.
# Exigencia: o container tem de ser O MESMO e continuar de pe. Apagar aqui derruba o site.
echo
echo "=== caso A: falha no 'docker tag' (api rodando, sem api-anterior)"
limpar; subir api
ANTES="$(idDe api)"
rodarLogica
if [ "$(idDe api)" != "$ANTES" ]; then
  vermelho "o container SADIO foi destruido (id mudou). E o site no chao."
elif ! rodando api; then
  vermelho "o container sadio ficou parado."
else
  verde "o container sadio continua de pe, mesmo id"
fi

# ------------------------------------------------------------------ caso B: o `docker stop` falhou
# Mesmo estado do A na pratica: `api` existe, `api-anterior` nao.
echo
echo "=== caso B: falha no 'docker stop' (api existe, sem api-anterior)"
limpar; subir api
ANTES="$(idDe api)"
rodarLogica
if [ "$(idDe api)" != "$ANTES" ]; then
  vermelho "o container foi destruido (id mudou)."
elif ! rodando api; then
  vermelho "o container ficou parado."
else
  verde "o container continua de pe, mesmo id"
fi

# ------------------------------------------------------------------ caso C: o `rename` falhou
# Estado: o `stop` passou, o rename nao. `api` existe PARADO, com a imagem boa. Sem `api-anterior`.
# Exigencia: NAO apagar, e RELIGAR -- o site esta fora enquanto ele estiver parado.
echo
echo "=== caso C: falha no 'docker rename' (api existe PARADO, sem api-anterior)"
limpar; subir api; docker stop -t 1 api >/dev/null
ANTES="$(idDe api)"
rodarLogica
if [ "$(idDe api)" != "$ANTES" ]; then
  vermelho "o container bom foi destruido (id mudou), e nao havia api-anterior para devolver."
elif ! rodando api; then
  vermelho "o container ficou PARADO: o rollback nao religou, e o site continua fora."
else
  verde "o mesmo container voltou a rodar"
fi

# ------------------------------------------------------------------ caso D: o `docker run` falhou
# Estado: o rename ACONTECEU e o run falhou. `api` nao existe; `api-anterior` e o bom, parado.
# Exigencia: devolver o `api-anterior` rodando. E o unico caso que o rollback antigo tratava.
echo
echo "=== caso D: falha no 'docker run' (sem api, api-anterior e o bom)"
limpar; subir api-anterior; docker stop -t 1 api-anterior >/dev/null
ANTERIOR="$(idDe api-anterior)"
rodarLogica
if [ "$(idDe api)" = "NAO-EXISTE" ]; then
  vermelho "nao existe container 'api' depois do rollback. Site no chao."
elif [ "$(idDe api)" != "$ANTERIOR" ]; then
  vermelho "o 'api' nao e o container que estava guardado em api-anterior."
elif ! rodando api; then
  vermelho "o anterior voltou mas esta PARADO."
else
  verde "o api-anterior voltou como 'api' e esta rodando"
fi

# ------------------------------------------------------------------ caso E: o container novo e ruim
# Estado: passo 9 -- o novo subiu mas nao ficou sadio. `api` e o NOVO, `api-anterior` e o bom.
# Exigencia: apagar o novo e devolver o anterior. E para isto que o rm -f existe.
echo
echo "=== caso E: passo 9, o novo subiu ruim (api=novo, api-anterior=bom)"
limpar; subir api-anterior; docker stop -t 1 api-anterior >/dev/null; subir api
NOVO="$(idDe api)"; BOM="$(idDe api-anterior)"
rodarLogica
if [ "$(idDe api)" = "$NOVO" ]; then
  vermelho "o container NOVO e ruim continuou como 'api': o rollback nao trocou nada."
elif [ "$(idDe api)" != "$BOM" ]; then
  vermelho "o 'api' nao e o container bom que estava em api-anterior."
elif ! rodando api; then
  vermelho "o bom voltou mas esta parado."
else
  verde "o novo foi removido e o bom voltou rodando"
fi

limpar
echo
if [ "$FALHAS" = "0" ]; then
  echo "VERDE: a decisao do rollback esta certa nos 5 estados."
  exit 0
fi
echo "VERMELHO: $FALHAS estado(s) reprovaram. NAO FACA DEPLOY assim." >&2
exit 1
