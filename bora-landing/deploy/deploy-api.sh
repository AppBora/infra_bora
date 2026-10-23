#!/usr/bin/env bash
#
# Sobe uma versao nova da API, com backup antes e rollback automatico se ela nao ficar sadia.
#
# POR QUE ISTO EXISTE
# O deploy era um roteiro de memoria: build, docker save, scp, docker load, stop, rm, run. Nada disso
# estava no repositorio, e cada passo tinha uma pegadinha que so se descobria errando:
#   - a rede chama `bora`, nao `bora_rede`
#   - o container chama `api`, nao `bora-api` (um deploy inteiro foi perdido por isso: o container novo
#     passava no health e nao recebia trafego)
#   - o `docker rm -f api` apaga os logs do que estava rodando, justo quando se investiga um defeito
#   - se o `docker run` falhasse, a API ficava FORA DO AR ate alguem notar
# E o backup antes do deploy nunca aconteceu, porque dependia de alguem lembrar.
#
# COMO USAR
#   ./deploy-api.sh v113
# De dentro de bora-landing/deploy, com a chave em ~/.ssh/bora-lightsail.pem.
#
# O QUE ELE NAO FAZ
# Nao roda os testes: quem roda e o `mvn package` dentro do Dockerfile, no build da imagem. Se um teste
# falhar, a imagem nao nasce e este script nao chega a rodar.
# Nao sobe o frontend (e `scp` da pasta, outro caminho).

set -euo pipefail

TAG="${1:-}"
[ -n "$TAG" ] || { echo "uso: $0 vNNN"; exit 1; }

SRV="ubuntu@18.230.57.33"
KEY="$HOME/.ssh/bora-lightsail.pem"
BACKEND="$(cd "$(dirname "$0")/../../bora-fase-3-backend-java" && pwd)"
TGZ="/tmp/bora-api-$TAG.tgz"

dizer() { printf '\n=== %s\n' "$*"; }

dizer "1/8 a arvore do backend esta limpa?"
if [ -n "$(git -C "$BACKEND" status --porcelain)" ]; then
  echo "ABORTADO: ha mudanca nao commitada no backend." >&2
  echo "A imagem copia o src do disco, entao subiria codigo que nao esta no Git." >&2
  git -C "$BACKEND" status --short >&2
  exit 1
fi
COMMIT="$(git -C "$BACKEND" rev-parse --short HEAD)"
echo "commit $COMMIT"

dizer "2/9 a data dos Termos no codigo bate com a pagina publicada?"
# Este teste precisa dos DOIS repositorios e, dentro do build da imagem, so existe o `src`: la ele se
# pula em silencio desde sempre. Aqui ele roda do checkout completo, que e o unico lugar onde pode
# valer de verdade. A versao gravada no aceite de cada lojista aponta para ESTE texto -- se a constante
# e a pagina divergirem, o comprovante aponta para um documento que ninguem sabe qual e.
( cd "$BACKEND" && mvn -q -o test -Dtest=VersaoDosTermosTest )   || { echo "ABORTADO: a data dos Termos no codigo nao bate com a pagina publicada." >&2; exit 1; }
echo "ok"

dizer "3/9 build da imagem (os testes rodam aqui dentro)"
docker build --label "git=$COMMIT" -t "bora-api:$TAG" "$BACKEND"

dizer "4/9 teste de subida contra banco inexistente"
# A causa raiz tem que ser "Connection refused" e nada mais. Isto pega bean quebrado, consulta JPQL
# malformada e coluna fora do lugar ANTES de o container de producao parar.
SAIDA="$(docker run --rm \
  -e SPRING_DATASOURCE_URL='jdbc:postgresql://127.0.0.1:1/naoexiste' \
  -e SPRING_DATASOURCE_USERNAME=x -e SPRING_DATASOURCE_PASSWORD=y \
  -e BORA_JWT_SECRET=um-segredo-de-teste-com-mais-de-32-bytes-aqui \
  "bora-api:$TAG" 2>&1 | grep -c 'Connection refused' || true)"
[ "$SAIDA" -gt 0 ] || { echo "ABORTADO: a aplicacao nao subiu por outro motivo que nao o banco." >&2; exit 1; }
echo "ok: a unica causa raiz foi Connection refused"

dizer "5/9 transferencia"
docker save "bora-api:$TAG" | gzip -1 > "$TGZ"
scp -i "$KEY" "$TGZ" "$SRV:/tmp/"
ssh -i "$KEY" "$SRV" "gunzip -c $TGZ | docker load && rm -f $TGZ"
rm -f "$TGZ"

dizer "6/9 a imagem que chegou e a mesma?"
# O ID da imagem muda na transferencia; a ULTIMA camada, que carrega o app.jar, nao.
CAMADA_LOCAL="$(docker inspect "bora-api:$TAG" --format '{{json .RootFS.Layers}}' | tr ',' '\n' | tail -1 | tr -d '"]')"
CAMADA_REMOTA="$(ssh -i "$KEY" "$SRV" "docker inspect bora-api:$TAG --format '{{json .RootFS.Layers}}'" | tr ',' '\n' | tail -1 | tr -d '"]')"
[ "$CAMADA_LOCAL" = "$CAMADA_REMOTA" ] || { echo "ABORTADO: a camada do app.jar difere." >&2; exit 1; }
echo "ok: $CAMADA_LOCAL"

dizer "7/9 BACKUP antes de trocar"
ssh -i "$KEY" "$SRV" '/home/ubuntu/backup-bora.sh && ls -t ~/backups/*.dump | head -1'

# ITEM 9.2 DA VARREDURA: o passo 8 nao tinha rollback.
#
# Ele ja paravam e RENOMEIA o container antigo antes de subir o novo. Se o `docker run` falhasse --
# imagem ruim, env-file faltando, porta ocupada --, o `set -e` matava o script ANTES do passo 9, e nao
# existia mais container chamado `api`: o site ficava no chao, e o rollback que o passo 9 tem nunca
# era alcancado. O proprio cabecalho deste script dizia que era isso que ele queria evitar.
#
# Agora os dois passos usam o MESMO rollback, e ele e uma funcao.
rollback() {
  echo "ROLLBACK: devolvendo a versao anterior." >&2
  ssh -i "$KEY" "$SRV" 'docker logs --tail 40 api 2>&1 | tail -40' >&2 || true
  # Cada passo com `|| true`: se o container novo nem existe (falha no passo 8), o `rm -f` falha e o
  # que importa -- devolver o antigo -- nao pode ser abortado por causa disso.
  ssh -i "$KEY" "$SRV" '
    docker rm -f api >/dev/null 2>&1 || true
    docker rename api-anterior api 2>/dev/null || true
    docker start api >/dev/null 2>&1 || true
    docker tag bora-api:anterior bora-api:latest 2>/dev/null || true'
  # Nao anuncia sucesso sem olhar: rollback que falha calado e pior que o deploy que falhou.
  if ssh -i "$KEY" "$SRV" 'for i in $(seq 1 20); do
        docker exec api curl -fs localhost:8080/actuator/health 2>/dev/null | grep -q UP && exit 0
        sleep 3
      done; exit 1'; then
    echo "rollback feito: a versao anterior esta de volta e SADIA." >&2
  else
    echo "!!! O ROLLBACK NAO FICOU SADIO. O SITE PODE ESTAR FORA DO AR. Entre no servidor:" >&2
    echo "    ssh -i $KEY $SRV 'docker ps -a; docker logs --tail 50 api'" >&2
    ssh -i "$KEY" "$SRV" 'docker ps -a --format "{{.Names}}  {{.Status}}"' >&2 || true
  fi
  exit 1
}

dizer "8/9 troca do container, guardando o anterior"
if ! ssh -i "$KEY" "$SRV" "bash -s" <<SCRIPT
set -e
docker tag bora-api:latest bora-api:anterior 2>/dev/null || true
docker tag bora-api:$TAG bora-api:latest
docker stop -t 30 api
docker rename api api-anterior          # guarda os logs do que estava rodando
docker run -d --name api --restart unless-stopped --network bora \
  --env-file /home/ubuntu/bora/api.env \
  --log-opt max-size=20m --log-opt max-file=5 \
  bora-api:latest
SCRIPT
then
  echo "A troca do container FALHOU (o container novo nao subiu)." >&2
  rollback
fi

# ITEM 9.7 DA VARREDURA: aqui o health CHEIO esta certo -- versao que nao fala com o banco nao serve,
# e rollback e a decisao acertada. O que faltava era dizer QUAL dos dois caiu. Sem isso, um RDS fora
# do ar aparecia como "a versao nova nao ficou sadia", e o proximo passo de quem le seria procurar
# defeito num codigo que esta bom.
diagnostico_da_falha() {
  local viva
  viva=$(ssh -i "$KEY" "$SRV" "docker exec api curl -s -o /dev/null -w '%{http_code}' --max-time 10 localhost:8080/actuator/health/viva 2>/dev/null" || true)
  if [ "$viva" = "200" ]; then
    echo "DIAGNOSTICO: o processo SUBIU e responde (grupo viva = 200). O que esta DOWN e um" >&2
    echo "indicador de fora -- quase sempre o banco. O codigo provavelmente esta bom: olhe o RDS" >&2
    echo "antes de procurar defeito na versao nova. Ver varredura 9.7." >&2
  else
    echo "DIAGNOSTICO: o processo nao responde nem no grupo viva (HTTP ${viva:-sem resposta})." >&2
    echo "A falha e da propria aplicacao: veja o log do container." >&2
  fi
}

dizer "9/9 esperando ficar sadio (rollback se nao ficar)"
if ssh -i "$KEY" "$SRV" 'for i in $(seq 1 40); do
      docker exec api curl -fs localhost:8080/actuator/health 2>/dev/null | grep -q UP && exit 0
      sleep 3
    done; exit 1'; then
  ssh -i "$KEY" "$SRV" 'docker rm api-anterior >/dev/null 2>&1 || true'
  echo "NO AR: $TAG (commit $COMMIT)"
  ssh -i "$KEY" "$SRV" 'docker ps --format "{{.Names}}  {{.Status}}"'
else
  echo "A versao nova nao ficou sadia." >&2
  diagnostico_da_falha
  rollback
fi
