#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/recipe-finding-app-98606-98494/Database"
cd "$WORKSPACE"
LOG="$WORKSPACE/logs/scaffold.log"
mkdir -p "$WORKSPACE/logs"
: >"$LOG"
# If empty workspace -> scaffold CRA via npx (avoid deprecated flags)
if [ ! -f package.json ] && [ -z "$(ls -A . 2>/dev/null)" ]; then
  if command -v npx >/dev/null 2>&1; then
    if ! npx create-react-app@latest . --use-npm --silent >"$LOG" 2>&1; then
      if command -v create-react-app >/dev/null 2>&1; then
        create-react-app . --use-npm >"$LOG" 2>&1 || { echo "create-react-app failed; see $LOG" >&2; tail -n 200 "$LOG" >&2; exit 7; }
      else
        echo "create-react-app failed and no global create-react-app available; see $LOG" >&2; tail -n 200 "$LOG" >&2; exit 7
      fi
    fi
  else
    if command -v create-react-app >/dev/null 2>&1; then
      create-react-app . --use-npm >"$LOG" 2>&1 || { echo "create-react-app failed; see $LOG" >&2; tail -n 200 "$LOG" >&2; exit 7; }
    else
      echo "npx and create-react-app not available; cannot scaffold" >&2; exit 8
    fi
  fi
  echo "CRA" > "$WORKSPACE/logs/toolchain.txt"
  echo "REACT_APP_API_URL=http://localhost:3001/api" > "$WORKSPACE/.env.local"
  exit 0
fi
# If package.json exists, detect toolchain safely
if [ -f package.json ]; then
  TOOLCHAIN=$(node -e 'try{const j=require("./package.json");const deps=Object.assign({},j.dependencies||{},j.devDependencies||{});if(deps["react-scripts"])console.log("CRA");else if(deps["next"])console.log("NEXT");else if(deps["vite"])console.log("VITE");else if(deps["pnpm"])console.log("PNPM");else console.log("OTHER");}catch(e){console.error(e.message);process.exit(0)}' 2>>"$LOG" || echo "OTHER")
  echo "$TOOLCHAIN" > "$WORKSPACE/logs/toolchain.txt"
  # restore node_modules using lockfile if missing
  if [ ! -d node_modules ]; then
    if [ -f package-lock.json ]; then
      npm ci --prefer-offline --no-audit --no-fund >"$LOG" 2>&1 || { echo "npm ci failed; see $LOG" >&2; tail -n 200 "$LOG" >&2; exit 9; }
    elif [ -f yarn.lock ]; then
      yarn install --silent >"$LOG" 2>&1 || { echo "yarn install failed; see $LOG" >&2; tail -n 200 "$LOG" >&2; exit 10; }
    elif [ -f pnpm-lock.yaml ] && command -v pnpm >/dev/null 2>&1; then
      pnpm install --silent >"$LOG" 2>&1 || { echo "pnpm install failed; see $LOG" >&2; tail -n 200 "$LOG" >&2; exit 11; }
    else
      echo "No lockfile found; running npm install (non-deterministic)" >>"$LOG"
      npm i --no-audit --no-fund >"$LOG" 2>&1 || { echo "npm install failed; see $LOG" >&2; tail -n 200 "$LOG" >&2; exit 12; }
    fi
  fi
  # If toolchain is non-CRA, exit with log so later steps can adapt
  if [ "$(cat "$WORKSPACE/logs/toolchain.txt")" != "CRA" ]; then
    echo "Non-CRA toolchain detected: $(cat "$WORKSPACE/logs/toolchain.txt")" >>"$LOG"
    exit 0
  fi
fi
# If reach here nothing to do
exit 0
