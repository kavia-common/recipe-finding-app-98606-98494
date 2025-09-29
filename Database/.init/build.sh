#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/recipe-finding-app-98606-98494/Database"
cd "$WORKSPACE"
VALID_LOG="$WORKSPACE/logs/validation.log"
: >"$VALID_LOG"
TOOLCHAIN=$(cat "$WORKSPACE/logs/toolchain.txt" 2>/dev/null || echo "UNKNOWN")
case "$TOOLCHAIN" in
  CRA)
    npm run build >"$VALID_LOG" 2>&1 || { echo "npm run build failed; see $VALID_LOG" >&2; tail -n 200 "$VALID_LOG" >&2; exit 40; }
    BUILD_DIR=build
    ;;
  VITE)
    npm run build >"$VALID_LOG" 2>&1 || { echo "vite build failed; see $VALID_LOG" >&2; tail -n 200 "$VALID_LOG" >&2; exit 41; }
    BUILD_DIR=dist
    ;;
  NEXT)
    npm run build >"$VALID_LOG" 2>&1 || { echo "next build failed; see $VALID_LOG" >&2; tail -n 200 "$VALID_LOG" >&2; exit 42; }
    BUILD_DIR=.next
    ;;
  *)
    echo "Unknown or unsupported toolchain ($TOOLCHAIN); attempting npm run build" >"$VALID_LOG"
    npm run build >"$VALID_LOG" 2>&1 || { echo "build failed; see $VALID_LOG" >&2; tail -n 200 "$VALID_LOG" >&2; exit 43; }
    BUILD_DIR=build
    ;;
esac
if [ ! -d "$BUILD_DIR" ]; then echo "build output ($BUILD_DIR) not found after build" >&2; exit 44; fi
printf "BUILD_DIR=%s\n" "$BUILD_DIR" >> "$VALID_LOG"
