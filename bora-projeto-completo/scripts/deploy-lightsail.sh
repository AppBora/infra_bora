#!/usr/bin/env bash
# ============================================================================
# Bora — Deploy na AWS Lightsail (API em container + PostgreSQL gerenciado)
# Rode no Git Bash, com: AWS CLI v2 + plugin lightsailctl + Docker instalados.
# Pré-requisito: `aws configure` já feito (usuário IAM, região sa-east-1).
#
# Uso:
#   cp deploy-lightsail.env.example deploy-lightsail.env   # preencha os segredos
#   ./deploy-lightsail.sh                                   # tudo
#   ./deploy-lightsail.sh service|image|deploy|bucket       # uma etapa só
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"

# ---- Config (ajuste os caminhos se sua estrutura local for outra) ----------
REGION="${REGION:-sa-east-1}"
SERVICE="${SERVICE:-bora-api}"
POWER="${POWER:-micro}"              # nano | micro | small | medium  (Spring Boot: micro/small)
SCALE="${SCALE:-1}"
BUCKET="${BUCKET:-bora-front}"
BACKEND_DIR="${BACKEND_DIR:-../../bora-fase-3-backend-java}"
FRONTEND_DIR="${FRONTEND_DIR:-../../bora-fase-2-frontend}"

# ---- Segredos e dados do banco (vêm do arquivo .env, NÃO comitar) ----------
if [ -f deploy-lightsail.env ]; then set -a; . ./deploy-lightsail.env; set +a; fi
: "${DB_ENDPOINT:?defina DB_ENDPOINT no deploy-lightsail.env}"
: "${DB_NAME:?defina DB_NAME}"; : "${DB_USER:?defina DB_USER}"; : "${DB_PASSWORD:?defina DB_PASSWORD}"
: "${BORA_JWT_SECRET:?defina BORA_JWT_SECRET (>=32 bytes)}"
: "${ADMIN_EMAIL:=admin@bora.app}"; : "${ADMIN_SENHA:?defina ADMIN_SENHA}"
: "${CORS_ORIGINS:=*}"               # troque pela URL real do frontend após o passo bucket

need() { command -v "$1" >/dev/null 2>&1 || { echo "!! Falta '$1' no PATH"; exit 1; }; }
need aws; need docker

# ---- 1) Cria o Container Service (idempotente) ------------------------------
step_service() {
  echo ">> Garantindo o container service '$SERVICE' ($POWER x$SCALE)..."
  if aws lightsail get-container-services --region "$REGION" --service-name "$SERVICE" >/dev/null 2>&1; then
    echo "   já existe."
  else
    aws lightsail create-container-service --region "$REGION" \
      --service-name "$SERVICE" --power "$POWER" --scale "$SCALE"
  fi
  echo ">> Aguardando ficar ACTIVE (pode levar alguns minutos)..."
  until [ "$(aws lightsail get-container-services --region "$REGION" --service-name "$SERVICE" \
        --query 'containerServices[0].state' --output text)" = "ACTIVE" ]; do
    printf "."; sleep 10
  done; echo " ok"
}

# ---- 2) Build + push da imagem da API --------------------------------------
step_image() {
  echo ">> Build da imagem (Dockerfile de $BACKEND_DIR)..."
  docker build -t bora-api:latest "$BACKEND_DIR"
  echo ">> Enviando a imagem para o Lightsail..."
  aws lightsail push-container-image --region "$REGION" \
    --service-name "$SERVICE" --label app --image bora-api:latest
}

# ---- 3) Deploy (gera JSON com envs + endpoint público + health check) ------
step_deploy() {
  IMAGE_REF="$(aws lightsail get-container-images --region "$REGION" --service-name "$SERVICE" \
      --query 'containerImages[0].image' --output text)"
  echo ">> Implantando imagem: $IMAGE_REF"
  TMP="$(mktemp -d)"
  cat > "$TMP/containers.json" <<JSON
{
  "app": {
    "image": "$IMAGE_REF",
    "ports": { "8080": "HTTP" },
    "environment": {
      "SPRING_DATASOURCE_URL": "jdbc:postgresql://$DB_ENDPOINT:5432/$DB_NAME?sslmode=require",
      "SPRING_DATASOURCE_USERNAME": "$DB_USER",
      "SPRING_DATASOURCE_PASSWORD": "$DB_PASSWORD",
      "BORA_JWT_SECRET": "$BORA_JWT_SECRET",
      "BORA_BOOTSTRAP_ADMIN_EMAIL": "$ADMIN_EMAIL",
      "BORA_BOOTSTRAP_ADMIN_SENHA": "$ADMIN_SENHA",
      "BORA_CORS_ORIGINS": "$CORS_ORIGINS"
    }
  }
}
JSON
  cat > "$TMP/endpoint.json" <<JSON
{
  "containerName": "app",
  "containerPort": 8080,
  "healthCheck": { "path": "/actuator/health", "successCodes": "200-299",
                   "intervalSeconds": 10, "timeoutSeconds": 5,
                   "healthyThreshold": 2, "unhealthyThreshold": 5 }
}
JSON
  aws lightsail create-container-service-deployment --region "$REGION" \
    --service-name "$SERVICE" \
    --containers "file://$TMP/containers.json" \
    --public-endpoint "file://$TMP/endpoint.json"
  rm -rf "$TMP"
  URL="$(aws lightsail get-container-services --region "$REGION" --service-name "$SERVICE" \
        --query 'containerServices[0].url' --output text)"
  echo ">> API publicada em: $URL"
  echo "   Teste: curl ${URL}actuator/health"
}

# ---- 4) Frontend: bucket + upload ------------------------------------------
step_bucket() {
  echo ">> Garantindo o bucket '$BUCKET'..."
  aws lightsail get-bucket --region "$REGION" --bucket-name "$BUCKET" >/dev/null 2>&1 \
    || aws lightsail create-bucket --region "$REGION" --bucket-name "$BUCKET" --bundle-id small_1_0
  echo ">> Subindo o frontend ($FRONTEND_DIR) para o bucket..."
  # Buckets do Lightsail são compatíveis com a API S3. Requer chaves de acesso do bucket
  # (Console Lightsail > Bucket > Access keys) exportadas como AWS_ACCESS_KEY_ID/SECRET, OU
  # suba pelo Console. Ajuste o endpoint S3 da região se necessário.
  aws s3 sync "$FRONTEND_DIR" "s3://$BUCKET" --exclude ".git/*" --exclude "node_modules/*" || {
    echo "!! Upload via S3 falhou. Suba o frontend pelo Console (Bucket > Objects) ou configure as access keys do bucket.";
  }
  echo ">> Depois: crie uma Distribution (CDN/HTTPS) apontando para o bucket no Console,"
  echo "   ajuste BORA_API no api.js para a URL da API e rode './deploy-lightsail.sh deploy' de novo"
  echo "   com CORS_ORIGINS = URL do frontend."
}

case "${1:-all}" in
  service) step_service ;;
  image)   step_image ;;
  deploy)  step_deploy ;;
  bucket)  step_bucket ;;
  all)     step_service; step_image; step_deploy; step_bucket ;;
  *) echo "uso: $0 [service|image|deploy|bucket|all]"; exit 1 ;;
esac
echo ">> Concluído."
