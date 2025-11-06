#!/bin/bash
# ======================================================
# AI Stack Preflight & Health Checker (macOS)
# Logs results + shows macOS notification if issues found
# ======================================================

STACK_DIR="$HOME/ai-stack"
LOG_DIR="$STACK_DIR/logs"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/check-$(date '+%Y-%m-%d_%H-%M-%S').log"

OLLAMA_URL="http://localhost:11434/api/tags"
WEBUI_URL="http://localhost:3001"
N8N_URL="http://localhost:5678"
QDRANT_URL="http://localhost:6333/healthz"

notify() {
    # macOS notification
    osascript -e "display notification \"$1\" with title \"AI Stack Monitor\""
}

log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "=========================================="
log " 🧠 AI Stack Preflight Check $(date)"
log "=========================================="
log ""

# 1️⃣  Check Ollama
log "🔍 Checking Ollama..."
if curl -fs "$OLLAMA_URL" >/dev/null 2>&1; then
    log "✅ Ollama is running"
else
    log "❌ Ollama not reachable on port 11434"
    notify "Ollama is NOT running. Start it manually."
    exit 1
fi
log ""

# 2️⃣  Check Docker
log "🔍 Checking Docker..."
if ! docker info >/dev/null 2>&1; then
    log "❌ Docker is not running."
    notify "Docker is NOT running — start Docker Desktop."
    exit 1
fi
log "✅ Docker is active"
log ""

cd "$STACK_DIR" || { log "❌ Missing $STACK_DIR"; notify "Stack directory missing"; exit 1; }

# 3️⃣  Check containers
declare -A SERVICES=(
  ["postgres"]="docker compose up -d postgres"
  ["qdrant"]="docker compose up -d qdrant"
  ["n8n"]="docker compose up -d n8n"
  ["open-webui"]="docker compose up -d open-webui"
)

declare -A URLS=(
  ["postgres"]="(docker exec postgres pg_isready >/dev/null 2>&1)"
  ["qdrant"]="curl -fs $QDRANT_URL >/dev/null 2>&1"
  ["n8n"]="curl -fs $N8N_URL >/dev/null 2>&1"
  ["open-webui"]="curl -fs $WEBUI_URL >/dev/null 2>&1"
)

FAILURES=()

for service in "${!SERVICES[@]}"; do
  log "🔍 Checking $service..."
  if eval "${URLS[$service]}"; then
    log "✅ $service is responding"
  else
    log "⚠️  $service not responding — attempting start..."
    eval "${SERVICES[$service]}" >>"$LOG_FILE" 2>&1
    sleep 5
    if eval "${URLS[$service]}"; then
      log "✅ $service started successfully"
    else
      log "❌ $service failed to start"
      FAILURES+=("$service")
    fi
  fi
  log ""
done

log "=========================================="
if [ ${#FAILURES[@]} -eq 0 ]; then
  log "✅ All systems operational!"
  notify "AI Stack started successfully — all services running."
else
  log "❌ Some services failed: ${FAILURES[*]}"
  notify "AI Stack issues: ${FAILURES[*]}"
fi
log "=========================================="
log ""
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tee -a "$LOG_FILE"

