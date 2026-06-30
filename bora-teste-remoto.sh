#!/usr/bin/env bash
# Sobe o link de teste remoto do Bora (frontend + API via tuneis cloudflare) e imprime o link pronto.
# Pre-requisito: Docker do Bora rodando (API :8080). Rode no Git Bash.
set -u
FRONT_DIR="C:/Users/user/OneDrive/Desktop/Bora/bora-fase-2-frontend"
CF="C:/Users/user/Downloads/SUIVIA/infra/cloudflared.exe"
LOGDIR="C:/Users/user/Downloads/SUIVIA"

echo ">> Subindo servidor do frontend (:5500)..."
( cd "$FRONT_DIR" && npx --yes http-server -p 5500 -c-1 >/dev/null 2>&1 & )

echo ">> Subindo tunel da API (:8080)..."
"$CF" tunnel --url http://localhost:8080 --no-autoupdate > "$LOGDIR/cf_api.log" 2>&1 &
echo ">> Subindo tunel do frontend (:5500)..."
"$CF" tunnel --url http://localhost:5500 --no-autoupdate > "$LOGDIR/cf_front.log" 2>&1 &

echo ">> Aguardando URLs publicas..."
A=""; F=""
for i in $(seq 1 20); do
  A=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOGDIR/cf_api.log" 2>/dev/null | head -1)
  F=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOGDIR/cf_front.log" 2>/dev/null | head -1)
  [ -n "$A" ] && [ -n "$F" ] && break
  sleep 2
done

if [ -z "$A" ] || [ -z "$F" ]; then echo "!! Nao consegui obter as URLs. Veja $LOGDIR/cf_*.log"; exit 1; fi

echo ""
echo "==================== LINK DE TESTE ===================="
echo "$F/login.html?api=$A"
echo "Login: admin@bora.app  |  Senha: bora123"
echo "======================================================="
echo "(deixe esta janela aberta — fechar derruba os tuneis)"
wait
