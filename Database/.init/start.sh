#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/recipe-finding-app-98606-98494/Database"
cd "$WORKSPACE"
VALID_LOG="$WORKSPACE/logs/validation.log"
: >"$VALID_LOG"
PORT=5000
BUILD_DIR=$(grep -m1 '^BUILD_DIR=' "$VALID_LOG" 2>/dev/null | cut -d'=' -f2- || echo "build")
# Choose serve binary
if [ -x ./node_modules/.bin/serve ]; then
  SERVE_CMD=("./node_modules/.bin/serve" "-s" "$BUILD_DIR" "-l" "$PORT")
elif command -v npx >/dev/null 2>&1; then
  SERVE_CMD=("npx" "serve" "-s" "$BUILD_DIR" "-l" "$PORT")
else
  echo "serve not available (no local binary and no npx); cannot validate serve" >&2; exit 45
fi
# Start in its own session so we can kill the whole group
setsid "${SERVE_CMD[@]}" >"$VALID_LOG" 2>&1 &
PID=$!
sleep 0.2
PGID=$(ps -o pgid= "$PID" | tr -d ' ' || true)
# persist PIDs for later cleanup
echo "$PID" > "$WORKSPACE/logs/validation_pid"
echo "$PGID" > "$WORKSPACE/logs/validation_pgid"
# provide a trap when sourced/executed standalone
trap 'if [ -n "${PGID:-}" ]; then kill -TERM -"$PGID" 2>/dev/null || true; fi; wait "$PID" 2>/dev/null || true' EXIT
# Wait for server readiness (background script should handle polling in validation step)
echo "started:$PID:$PGID" >> "$VALID_LOG"
echo "$PID"
