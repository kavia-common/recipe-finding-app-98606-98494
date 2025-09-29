#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/recipe-finding-app-98606-98494/Database"
cd "$WORKSPACE"
mkdir -p logs
TEST_LOG="$WORKSPACE/logs/test.log"
: >"$TEST_LOG"
# Detect TypeScript: tsconfig.json or dependency in package.json
IS_TS=false
if [ -f tsconfig.json ] || node -e "try{const j=require('./package.json');console.log(Boolean((j.devDependencies&&j.devDependencies.typescript)||(j.dependencies&&j.dependencies.typescript)));}catch(e){console.log(false)}" 2>/dev/null | grep -q true; then IS_TS=true; fi
# Ensure App entry exists
if [ ! -f src/App.js ] && [ ! -f src/App.jsx ] && [ ! -f src/App.tsx ]; then
echo "src/App.* not found; skipping test creation" >>"$TEST_LOG"
echo "ERROR: src/App.* not found in project. Create src/App.js/tsx or adjust path." >&2
exit 30
fi
# Create appropriate test file only if missing
if [ "$IS_TS" = true ]; then
  if [ ! -f src/App.test.tsx ]; then
    cat > src/App.test.tsx <<'EOF'
import React from 'react';
import {render} from '@testing-library/react';
import App from './App';

test('renders without crashing', () => {
  const {container} = render(<App />);
  expect(container).toBeTruthy();
});
EOF
  fi
else
  if [ ! -f src/App.test.js ]; then
    cat > src/App.test.js <<'EOF'
import React from 'react';
import {render} from '@testing-library/react';
import App from './App';

test('renders without crashing', () => {
  const {container} = render(<App />);
  expect(container).toBeTruthy();
});
EOF
  fi
fi
# Run tests via local jest or npx fallback
export CI=1
# Prefer the project-local jest binary
if [ -x node_modules/.bin/jest ]; then
  echo "Running project-local jest..." >>"$TEST_LOG"
  node_modules/.bin/jest --runInBand --watchAll=false >"$TEST_LOG" 2>&1 || { echo "Tests failed; see $TEST_LOG" >&2; tail -n 200 "$TEST_LOG" >&2; exit 31; }
else
  # If project-local jest absent, try npx --no-install (fails if not cached locally)
  if command -v npx >/dev/null 2>&1 && npx --no-install jest --version >/dev/null 2>&1; then
    echo "Running jest via npx --no-install..." >>"$TEST_LOG"
    npx --no-install jest --runInBand --watchAll=false >"$TEST_LOG" 2>&1 || { echo "Tests failed (npx); see $TEST_LOG" >&2; tail -n 200 "$TEST_LOG" >&2; exit 32; }
  else
    # Provide actionable guidance
    echo "jest not available locally and npx fallback unavailable; ensure dev dependencies include jest and @testing-library/react, then run your package manager to install them." >>"$TEST_LOG"
    echo "ERROR: jest not found. Add jest and @testing-library/react to devDependencies and run 'npm ci' or 'yarn install' in the project root." >&2
    exit 33
  fi
fi
# Success
echo "Tests passed; logs at $TEST_LOG" >>"$TEST_LOG"
exit 0
