#!/bin/bash
# ─── ObraMaster — Full Stack Restart ─────────────────────────────────────────
# Sobe Docker (PostgreSQL + MinIO), reinicia backend (uvicorn) e frontend
# (Flutter web). Mata processos antigos antes de subir novos.
# Uso: bash restart.sh
# ──────────────────────────────────────────────────────────────────────────────

BACKEND_PORT=8000
FRONTEND_PORT=64685
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_DIR="$PROJECT_ROOT"

echo "========================================="
echo "  ObraMaster — Full Stack Restart"
echo "========================================="
echo "Projeto:  $PROJECT_ROOT"
echo "Backend:  $SCRIPT_DIR (porta $BACKEND_PORT)"
echo "Frontend: $FLUTTER_DIR (porta $FRONTEND_PORT)"
echo ""

# ─── Funcao auxiliar: matar processos em uma porta ────────────────────────────
kill_port() {
    local port=$1
    if command -v powershell &>/dev/null; then
        local pids
        pids=$(powershell -Command "
            Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty OwningProcess -Unique
        " 2>/dev/null | tr -d '\r')
        if [ -n "$pids" ]; then
            for pid in $pids; do
                if [ "$pid" != "0" ]; then
                    echo "  Matando PID $pid (porta $port)..."
                    taskkill //PID "$pid" //F 2>/dev/null
                fi
            done
            sleep 2
        else
            echo "  Nenhum processo na porta $port."
        fi
    else
        local pids
        pids=$(lsof -ti :$port 2>/dev/null)
        if [ -n "$pids" ]; then
            echo "  Matando PIDs: $pids (porta $port)"
            kill -9 $pids 2>/dev/null
            sleep 2
        else
            echo "  Nenhum processo na porta $port."
        fi
    fi
}

# ─── 1. Docker Compose (PostgreSQL + MinIO) ──────────────────────────────────
echo "[1/5] Subindo Docker Compose (postgres + minio)..."

if ! command -v docker &>/dev/null; then
    echo "  ERRO: Docker nao encontrado no PATH!"
    echo "  Instale o Docker Desktop ou adicione ao PATH."
    exit 1
fi

if ! docker info &>/dev/null 2>&1; then
    echo "  Docker daemon nao esta rodando. Tentando iniciar Docker Desktop..."
    if [ -f "/c/Program Files/Docker/Docker/Docker Desktop.exe" ]; then
        "/c/Program Files/Docker/Docker/Docker Desktop.exe" &
        echo "  Aguardando Docker iniciar (ate 60s)..."
        for i in $(seq 1 60); do
            sleep 1
            if docker info &>/dev/null 2>&1; then
                echo "  Docker pronto! (${i}s)"
                break
            fi
            if [ "$i" = "60" ]; then
                echo "  ERRO: Docker nao iniciou em 60s. Inicie manualmente."
                exit 1
            fi
        done
    else
        echo "  ERRO: Docker Desktop nao encontrado. Inicie manualmente."
        exit 1
    fi
fi

cd "$PROJECT_ROOT"
docker compose up -d postgres minio 2>&1 | sed 's/^/  /'

echo "  Aguardando PostgreSQL ficar pronto..."
for i in $(seq 1 30); do
    sleep 1
    if docker exec obramaster-postgres pg_isready -U obramaster -d obramaster &>/dev/null 2>&1; then
        echo "  PostgreSQL pronto! (${i}s)"
        break
    fi
    if [ "$i" = "30" ]; then
        echo "  AVISO: PostgreSQL nao respondeu em 30s. Continuando..."
    fi
done
echo ""

# ─── 2. Matar processos nas portas ───────────────────────────────────────────
echo "[2/5] Matando processos antigos..."
kill_port $BACKEND_PORT
kill_port $FRONTEND_PORT
echo ""

# ─── 3. Limpar cache Python ──────────────────────────────────────────────────
echo "[3/5] Limpando __pycache__..."
find "$SCRIPT_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
find "$SCRIPT_DIR" -name "*.pyc" -delete 2>/dev/null
echo "  Cache limpo."
echo ""

# ─── 4. Iniciar backend (uvicorn) ────────────────────────────────────────────
echo "[4/5] Iniciando backend (uvicorn porta $BACKEND_PORT)..."
cd "$SCRIPT_DIR"
python -m uvicorn app.main:app --host 0.0.0.0 --port $BACKEND_PORT --reload &
UVICORN_PID=$!

echo "  Aguardando backend..."
BACKEND_OK=false
for i in $(seq 1 20); do
    sleep 1
    if curl -s http://localhost:$BACKEND_PORT/health >/dev/null 2>&1; then
        BACKEND_OK=true
        echo "  Backend pronto! (${i}s)"
        break
    fi
done

if [ "$BACKEND_OK" = false ]; then
    echo "  ERRO: Backend nao respondeu em 20s."
    echo "  Verifique: python -m uvicorn app.main:app --port $BACKEND_PORT"
    exit 1
fi

AUTH_COUNT=$(curl -s http://localhost:$BACKEND_PORT/openapi.json 2>/dev/null | python -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(len([p for p in d.get('paths',{}) if 'auth' in p]))
except:
    print(0)
" 2>/dev/null)
TOTAL_COUNT=$(curl -s http://localhost:$BACKEND_PORT/openapi.json 2>/dev/null | python -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(len(d.get('paths',{})))
except:
    print(0)
" 2>/dev/null)
echo "  Rotas: $TOTAL_COUNT total | $AUTH_COUNT auth"
echo ""

# ─── 5. Iniciar frontend (Flutter web) ───────────────────────────────────────
echo "[5/5] Iniciando frontend Flutter (porta $FRONTEND_PORT)..."
cd "$FLUTTER_DIR"
flutter run -d chrome \
    --web-port=$FRONTEND_PORT \
    --dart-define=API_BASE_URL=http://localhost:$BACKEND_PORT \
    &>/dev/null &
FLUTTER_PID=$!

echo "  Flutter iniciando em background (PID $FLUTTER_PID)..."
echo "  Aguardando Flutter compilar (ate 60s)..."
FRONTEND_OK=false
for i in $(seq 1 60); do
    sleep 2
    if curl -s http://localhost:$FRONTEND_PORT >/dev/null 2>&1; then
        FRONTEND_OK=true
        echo "  Frontend pronto! (${i}x2s)"
        break
    fi
done

echo ""
echo "========================================="
echo "  ObraMaster — Status"
echo "========================================="
echo ""
echo "  Backend:  http://localhost:$BACKEND_PORT  (PID $UVICORN_PID)"
echo "  API Docs: http://localhost:$BACKEND_PORT/docs"
echo "  Rotas:    $TOTAL_COUNT total | $AUTH_COUNT auth"
echo ""
if [ "$FRONTEND_OK" = true ]; then
    echo "  Frontend: http://localhost:$FRONTEND_PORT  (PID $FLUTTER_PID)"
else
    echo "  Frontend: Ainda compilando... (PID $FLUTTER_PID)"
    echo "            Acesse http://localhost:$FRONTEND_PORT em alguns segundos"
fi
echo ""
echo "========================================="
