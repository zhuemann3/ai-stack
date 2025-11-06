#!/usr/bin/env bash
# ai_stack_backup.sh
# Backup all AI-stack bind-mounted data into timestamped archives under ./backups/YYYY-MM-DD

set -euo pipefail
BACKUP_DIR="./backups/$(date +%F)"
DATA_DIR="./data"

mkdir -p "$BACKUP_DIR"

echo "📦 Starting AI-stack backup..."
echo "Backup target: $BACKUP_DIR"

for folder in postgres_data qdrant_data n8n_data webui_data; do
  SRC="$DATA_DIR/$folder"
  if [ -d "$SRC" ]; then
    ARCHIVE="$BACKUP_DIR/${folder}_$(date +%H%M).tgz"
    echo "→ Archiving $SRC → $ARCHIVE"
    tar czf "$ARCHIVE" -C "$SRC" .
  else
    echo "⚠️  Skipping $SRC (not found)"
  fi
done

# Optional rotation: keep only last 7 days of backups
find ./backups -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true

echo "✅ Backup complete. Archives stored in $BACKUP_DIR"

