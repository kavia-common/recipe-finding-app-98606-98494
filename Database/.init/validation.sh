#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/recipe-finding-app-98606-98494/Database"
cd "$WORKSPACE"
mkdir -p "$WORKSPACE/logs"
VALID_LOG="$WORKSPACE/logs/validation.log"
: >"$VALID_LOG"
PORT=5000
# Build
bash "$WORKSPACE/build" || { echo "build failed; see $VALID_LOG" >&2; tail -n 200 "$VALID_LOG" >&2; exit 50; }
BUILD_DIR=$(grep -m1 '^BUILD_DIR=' "$VALID_LOG" 2>/dev/null | cut -d'=' -f2- || echo "build")
# Start server
START_PID=$(bash "$WORKSPACE/start" ) || { echo "start failed; see $VALID_LOG" >&2; tail -n 200 "$VALID_LOG" >&2; exit 51; }
# Read PGID
PGID=$(cat "$WORKSPACE/logs/validation_pgid" 2>/dev/null || true)
trap 'if [ -n "${PGID:-}" ]; then kill -TERM -"$PGID" 2>/dev/null || true; fi; rm -f "$WORKSPACE/logs/validation_pid" "$WORKSPACE/logs/validation_pgid" 2>/dev/null || true' EXIT
# Wait up to 60s for server
for i in $(seq 1 60); do
  if curl -sSf "http://localhost:$PORT/" >/dev/null 2>&1; then break; fi
  sleep 1
done
if ! curl -sSf "http://localhost:$PORT/" >/dev/null 2>&1; then
  echo "Validation server did not start; see $VALID_LOG" >&2; tail -n 200 "$VALID_LOG" >&2 || true; bash "$WORKSPACE/stop" || true; exit 46
fi
# Smoke check for HTML
HTML=$(curl -sSf "http://localhost:$PORT/") || { echo "failed to fetch index" >&2; bash "$WORKSPACE/stop" || true; exit 47; }
if ! printf "%s" "$HTML" | grep -qi '<!doctype html\|<html'; then
  echo "Unexpected response from validation server" >&2; bash "$WORKSPACE/stop" || true; exit 48
fi
# Record evidence
printf "validation: ok\nnode=%s\nnpm=%s\npm_toolchain=%s\nBUILD_DIR=%s\n" "$(node -v || echo unknown)" "$(npm -v || echo unknown)" "$(cat "$WORKSPACE/logs/toolchain.txt" 2>/dev/null || echo UNKNOWN)" "$BUILD_DIR" > "$VALID_LOG"
# Touch VALIDATION_OK
echo "validation: ok" > "$WORKSPACE/VALIDATION_OK"
# Cleanup
bash "$WORKSPACE/stop" || true
exit 0
