#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

resolve_db_path() {
  if [[ -n "${THOUGHT_STREAM_HOME:-}" ]]; then
    printf "%s/thoughts.sqlite3\n" "$THOUGHT_STREAM_HOME"
    return
  fi

  local app_support="$HOME/Library/Application Support/ThoughtStream/thoughts.sqlite3"
  if [[ -f "$app_support" ]]; then
    printf "%s\n" "$app_support"
    return
  fi

  printf "%s/.thought-stream/thoughts.sqlite3\n" "$ROOT_DIR"
}

DB_PATH="$(resolve_db_path)"

if [[ ! -f "$DB_PATH" ]]; then
  echo "Database not found: $DB_PATH"
  exit 1
fi

sqlite3 "$DB_PATH" <<'SQL'
BEGIN IMMEDIATE;
DELETE FROM thoughts_fts;
DELETE FROM thoughts;
DELETE FROM sqlite_sequence WHERE name = 'thoughts';
COMMIT;
SQL

echo "Cleared ThoughtStream database: $DB_PATH"
