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

dizer "2/8 build da imagem (os testes rodam aqui dentro)"
docker build --label "git=$COMMIT" -t "bora-api:$TAG" "$BACKEND"

dizer "3/8 teste de subida contra banco inexistente"
# A causa raiz tem que ser "Connection refused" e nada mais. Isto pega bean quebrado, consulta JPQL
# malformada e coluna fora do lugar ANTES de o container de producao parar.
SAIDA="$(docker run --rm \
  -e SPRING_DATASOURCE_URL='jdbc:postgresql://127.0.0.1:1/naoexiste' \
  -e SPRING_DATASOURCE_USERNAME=x -e SPRING_DATASOURCE_PASSWORD=y \
  -e BORA_JWT_SECRET=um-segredo-de-teste-com-mais-de-32-bytes-aqui \
  "bora-api:$TAG" 2>&1 | grep -c 'Connection refused' || true)"
[ "$SAIDA" -gt 0 ] || { echo "ABORTADO: a aplicacao nao subiu por outro motivo que nao o banco." >&2; exit 1; }
echo "ok: a unica causa raiz foi Connection refused"

dizer "4/8 transferencia"
docker save "bora-api:$TAG" | gzip -1 > "$TGZ"
scp -i "$KEY" "$TGZ" "$SRV:/tmp/"
ssh -i "$KEY" "$SRV" "gunzip -c $TGZ | docker load && rm -f $TGZ"
rm -f "$TGZ"

dizer "5/8 a imagem que chegou e a mesma?"
# O ID da imagem muda na transferencia; a ULTIMA camada, que carrega o app.jar, nao.
CAMADA_LOCAL="$(docker inspect "bora-api:$TAG" --format '{{json .RootFS.Layers}}' | tr ',' '\n' | tail -1 | tr -d '"]')"
CAMADA_REMOTA="$(ssh -i "$KEY" "$SRV" "docker inspect bora-api:$TAG --format '{{json .RootFS.Layers}}'" | tr ',' '\n' | tail -1 | tr -d '"]')"
[ "$CAMADA_LOCAL" = "$CAMADA_REMOTA" ] || { echo "ABORTADO: a camada do app.jar difere." >&2; exit 1; }
echo "ok: $CAMADA_LOCAL"

dizer "6/8 BACKUP antes de trocar"
ssh -i "$KEY" "$SRV" '/home/ubuntu/backup-bora.sh && ls -t ~/backups/*.dump | head -1'

dizer "7/8 troca do container, guardando o anterior"
ssh -i "$KEY" "$SRV" "bash -s" <<SCRIPT
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

dizer "8/8 esperando ficar sadio (rollback se nao ficar)"
if ssh -i "$KEY" "$SRV" 'for i in $(seq 1 40); do
      docker exec api curl -fs localhost:8080/actuator/health 2>/dev/null | grep -q UP && exit 0
      sleep 3
    done; exit 1'; then
  ssh -i "$KEY" "$SRV" 'docker rm api-anterior >/dev/null 2>&1 || true'
  echo "NO AR: $TAG (commit $COMMIT)"
  ssh -i "$KEY" "$SRV" 'docker ps --format "{{.Names}}  {{.Status}}"'
else
  echo "A versao nova nao ficou sadia. ROLLBACK." >&2
  ssh -i "$KEY" "$SRV" 'docker logs --tail 40 api 2>&1 | tail -40' >&2 || true
  ssh -i "$KEY" "$SRV" 'set -e
    docker rm -f api
    docker rename api-anterior api
    docker start api
    docker tag bora-api:anterior bora-api:latest'
  echo "rollback feito: a versao anterior esta de volta" >&2
  exit 1
fi
