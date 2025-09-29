#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/recipe-finding-app-98606-98494/Database"
cd "$WORKSPACE"
LOG="$WORKSPACE/logs/install.log"
mkdir -p "$(dirname "$LOG")"
: >"$LOG"
PM=$(cat "$WORKSPACE/logs/package_manager.txt" 2>/dev/null || echo npm)
TOOLCHAIN=$(cat "$WORKSPACE/logs/toolchain.txt" 2>/dev/null || echo UNKNOWN)
if [ ! -f package.json ]; then echo "package.json missing; cannot install dependencies" >>"$LOG"; exit 20; fi
NEEDED=("jest" "@testing-library/react" "@testing-library/jest-dom" "msw" "cross-env" "dotenv" "serve")
has_pkg(){ node -e "try{const j=require('./package.json');const deps=Object.assign({},j.dependencies||{},j.devDependencies||{});console.log(Boolean(deps['$1']));}catch(e){console.log(false)}" 2>>"$LOG" || echo false; }
MISSING=()
for pkg in "${NEEDED[@]}"; do
  if [ "$(has_pkg "$pkg")" != "true" ]; then MISSING+=("$pkg"); fi
done
if [ ${#MISSING[@]} -gt 0 ]; then
  if [ "$PM" = "yarn" ]; then
    yarn add --dev "${MISSING[@]}" --silent >>"$LOG" 2>&1 || { echo "yarn add dev deps failed; see $LOG" >&2; tail -n 200 "$LOG" >&2; exit 21; }
    yarn install --silent >>"$LOG" 2>&1 || true
  elif [ "$PM" = "pnpm" ] && command -v pnpm >/dev/null 2>&1; then
    pnpm add -D "${MISSING[@]}" --silent >>"$LOG" 2>&1 || { echo "pnpm add dev deps failed; see $LOG" >&2; tail -n 200 "$LOG" >&2; exit 22; }
    pnpm install --silent >>"$LOG" 2>&1 || true
  else
    npm i --no-audit --no-fund --save-dev "${MISSING[@]}" >>"$LOG" 2>&1 || { echo "npm install dev deps failed; see $LOG" >&2; tail -n 200 "$LOG" >&2; exit 23; }
    if [ -f package-lock.json ]; then
      npm ci --prefer-offline --no-audit --no-fund >>"$LOG" 2>&1 || true
    fi
  fi
else
  if [ -f package-lock.json ]; then
    npm ci --prefer-offline --no-audit --no-fund >>"$LOG" 2>&1 || { echo "npm ci failed; see $LOG" >&2; tail -n 200 "$LOG" >&2; exit 24; }
  elif [ -f yarn.lock ]; then
    yarn install --silent >>"$LOG" 2>&1 || { echo "yarn install failed; see $LOG" >&2; tail -n 200 "$LOG" >&2; exit 25; }
  elif [ -f pnpm-lock.yaml ] && command -v pnpm >/dev/null 2>&1; then
    pnpm install --silent >>"$LOG" 2>&1 || { echo "pnpm install failed; see $LOG" >&2; tail -n 200 "$LOG" >&2; exit 26; }
  else
    npm i --no-audit --no-fund >>"$LOG" 2>&1 || { echo "npm install failed; see $LOG" >&2; tail -n 200 "$LOG" >&2; exit 27; }
  fi
fi
# record jest version if available
mkdir -p "$WORKSPACE/logs"
if [ -x node_modules/.bin/jest ]; then
  node_modules/.bin/jest --version > "$WORKSPACE/logs/jest_version.log" 2>&1 || true
else
  if command -v npx >/dev/null 2>&1 && npx --no-install jest --version >/dev/null 2>&1; then
    npx --no-install jest --version > "$WORKSPACE/logs/jest_version.log" 2>&1 || true
  else
    echo "local jest binary not found and npx fallback unavailable" >>"$LOG"
  fi
fi
# minimal eslint/prettier
[ -f .eslintrc.json ] || cat > .eslintrc.json <<'EOF'
{"extends":["react-app","plugin:prettier/recommended"]}
EOF
[ -f .prettierrc ] || cat > .prettierrc <<'EOF'
{"singleQuote":true}
EOF
# lightweight AI mock
mkdir -p src/mocks
[ -f src/mocks/aiMock.js ] || cat > src/mocks/aiMock.js <<'EOF'
// Minimal mock for image/AI endpoints used in development
export function predictImage(_input){ return Promise.resolve({ label:'mock-label', confidence:0.99 }); }
EOF
[ -f src/mocks/README.md ] || cat > src/mocks/README.md <<'EOF'
Enable mocks in development (import in src/index.js when NODE_ENV=development).
EOF
exit 0
