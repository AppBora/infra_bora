#!/bin/bash
# Roda o Cifrar com o JRE da propria imagem da API, na rede do banco, com o segredo entrando
# SO por --env-file. Nada e ecoado: o programa imprime apenas contagens.
set -eu
MODO="${1:?uso: rodar.sh conferir|aplicar}"
docker run --rm --network bora \
  --env-file /home/ubuntu/bora/api.env \
  -v /home/ubuntu/cifrar:/cifrar:ro \
  --entrypoint java bora-api:latest \
  -cp "/cifrar/classes:/cifrar/lib/jakarta.persistence-api-3.1.0.jar:/cifrar/lib/slf4j-api-2.0.13.jar:/cifrar/lib/postgresql-42.7.3.jar" \
  Cifrar "$MODO"
