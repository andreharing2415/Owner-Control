#!/usr/bin/env bash
# ─── Deploy da API ObraMaster no Cloud Run (projeto obramaster) ─────────────
# Uso: bash deploy-cloudrun.sh [região]
# Região padrão: us-central1
# Requer: gcloud config set project obramaster (ou use --project abaixo)
# ─────────────────────────────────────────────────────────────────────────────

set -e

PROJECT_ID="${GCP_PROJECT:-mestreobra}"
SERVICE_NAME="${CLOUD_RUN_SERVICE:-mestreobra-backend}"
REGION="${1:-us-central1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "========================================="
echo "  ObraMaster — Deploy Cloud Run"
echo "========================================="
echo "  Projeto:  $PROJECT_ID"
echo "  Serviço:  $SERVICE_NAME"
echo "  Região:   $REGION"
echo "  Contexto: $SCRIPT_DIR"
echo ""

# 1. Definir projeto
echo "[1/4] Configurando projeto..."
gcloud config set project "$PROJECT_ID"

# 2. APIs necessárias
echo "[2/4] Habilitando APIs (se necessário)..."
gcloud services enable run.googleapis.com cloudbuild.googleapis.com --quiet 2>/dev/null || true

# 3. Build da imagem e push (Cloud Build)
echo "[3/4] Build da imagem (Cloud Build)..."
IMAGE="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
gcloud builds submit --tag "$IMAGE" "$SCRIPT_DIR"

# 4. Deploy no Cloud Run
echo "[4/4] Deploy no Cloud Run..."
gcloud run deploy "$SERVICE_NAME" \
  --image "$IMAGE" \
  --platform managed \
  --region "$REGION" \
  --allow-unauthenticated \
  --port 8080 \
  --timeout 300 \
  --memory 1Gi \
  --cpu 1

echo ""
echo "========================================="
echo "  Deploy concluído"
echo "========================================="
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --platform managed --region "$REGION" --format='value(status.url)' 2>/dev/null || echo "(execute: gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)')")
echo "  URL da API: $SERVICE_URL"
echo "  Docs:       $SERVICE_URL/docs"
echo "  Health:     $SERVICE_URL/health"
echo ""
echo "  Para o Flutter usar esta API:"
echo "  flutter run -d chrome --dart-define=API_BASE_URL=$SERVICE_URL"
echo ""
