#!/usr/bin/env bash
# AI Stack Control Script
# Usage: ./ai_stack_control.sh [backup|recover|commit]

set -e
STACK_DIR="$HOME/ai-stack"
BACKUP_DIR="$STACK_DIR"
DATE=$(date +%Y%m%d)
LOGFILE="$STACK_DIR/ai_stack.log"

# --- Helper functions ---
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

backup_stack() {
  log "Starting backup..."
  cd "$STACK_DIR" || exit 1
  docker compose down
  tar -czf "$BACKUP_DIR/ai-stack-backup-$DATE.tar.gz" docker-compose.yml .env data/
  docker compose images > "$BACKUP_DIR/ai-stack-images-$DATE.txt"
  log "Backup complete: ai-stack-backup-$DATE.tar.gz"
}

recover_stack() {
  log "Starting recovery..."
  cd "$STACK_DIR" || exit 1

  if ! docker info >/dev/null 2>&1; then
    log "Docker not running. Starting Docker Desktop..."
    open -a Docker
    sleep 10
  fi

  if ! curl -s http://localhost:11434/api/version >/dev/null; then
    log "Ollama not responding. Restarting service..."
    brew services restart ollama
    sleep 5
  fi

  docker compose down
  docker compose up -d
  if docker exec open-webui curl -s http://host.docker.internal:11434/api/version >/dev/null; then
    log "Ollama connection verified."
  else
    log "Warning: WebUI may not be connected to Ollama."
  fi

  log "Recovery complete."
}

commit_stack() {
  log "Starting Git commit & sync..."
  cd "$STACK_DIR" || exit 1
  git add docker-compose.yml recover_ai_stack.sh ai_stack_control.sh .gitignore RESTORE.md \
          Dockerfile.ocr embed_api.py load_to_qdrant.py ocr_api.py qdrant-config.yaml
  git commit -m "Snapshot: auto-backup and sync on $DATE" || log "No changes to commit."
  git push
  TAG="stable-$DATE"
  git tag -a "$TAG" -m "Known good AI stack snapshot ($DATE)"
  git push origin "$TAG"
  log "Git sync complete. Tagged as $TAG."
}

case "$1" in
  backup) backup_stack ;;
  recover) recover_stack ;;
  commit) backup_stack; commit_stack ;;
  *)
    echo "Usage: $0 [backup|recover|commit]"
    exit 1
    ;;
esac