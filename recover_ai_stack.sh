#!/usr/bin/env bash
set -e

STACK_DIR="$HOME/ai-stack"
LOGFILE="$STACK_DIR/recover.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Starting AI stack recovery..." | tee -a "$LOGFILE"

cd "$STACK_DIR" || { echo "Cannot find $STACK_DIR"; exit 1; }

# Check Docker health
if ! docker info >/dev/null 2>&1; then
  echo "Docker not running. Starting Docker Desktop..." | tee -a "$LOGFILE"
  open -a Docker
  sleep 10
fi

# Check Ollama
if ! curl -s http://localhost:11434/api/version >/dev/null; then
  echo "Ollama not responding. Restarting service..." | tee -a "$LOGFILE"
  brew services restart ollama
  sleep 5
fi

# Check key containers
if ! docker ps | grep -q open-webui; then
  echo "Restarting Docker stack..." | tee -a "$LOGFILE"
  docker compose down
  docker compose up -d
else
  echo "Stack already running. Restarting gracefully..." | tee -a "$LOGFILE"
  docker compose restart
fi

# Verify connectivity
if docker exec open-webui curl -s http://host.docker.internal:11434/api/version >/dev/null; then
  echo "Ollama connection verified." | tee -a "$LOGFILE"
else
  echo "Warning: WebUI may not be connected to Ollama." | tee -a "$LOGFILE"
fi

echo "[$DATE] Recovery complete." | tee -a "$LOGFILE"
