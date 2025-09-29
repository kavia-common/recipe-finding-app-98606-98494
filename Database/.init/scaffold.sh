#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/recipe-finding-app-98606-98494/Database"
cd "$WORKSPACE"
# If already CRA-like, skip
if [ -f package.json ] && ( [ -f src/index.js ] || [ -f src/index.jsx ] || [ -f public/index.html ] ); then exit 0; fi
if [ -f package.json ] && ! ( [ -f src/index.js ] || [ -f public/index.html ] ); then echo "package.json exists but no CRA structure; skipping scaffold to avoid overwrite" >&2; exit 6; fi
# Prefer global modern create-react-app if available
USE_NPX=1
if command -v create-react-app >/dev/null 2>&1; then
  CRA_V=$(create-react-app --version 2>/dev/null || echo "0")
  CRA_MAJOR=$(echo "$CRA_V" | cut -d. -f1 || echo 0)
  if [ "$CRA_MAJOR" -ge 5 ]; then USE_NPX=0; fi
fi
# Workaround for npm project name restrictions: pass --template and set temporary name in package.json after scaffolding
TMPLOG=/tmp/cra_out.log
# Use npx create-react-app in current dir non-interactively but supply a safe CLI name using --template and --skip-install when necessary
# create-react-app rejects uppercase folder names; detect and run with an explicit project name then move files into place
PROJ_NAME_SAFE=$(basename "$WORKSPACE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g')
if [ -z "$PROJ_NAME_SAFE" ]; then PROJ_NAME_SAFE="app"; fi
# If the safe name equals current folder name, we still must avoid uppercase; if name had uppercase letters, use proj_name_safe as explicit name in a temp dir
if [ "$PROJ_NAME_SAFE" = "$(basename \"$WORKSPACE\")" ] && echo "$(basename \"$WORKSPACE\")" | grep '[A-Z]' >/dev/null 2>&1; then
  PROJ_NAME_SAFE="$(basename \"$WORKSPACE\")" | tr '[:upper:]' '[:lower:]'
fi
TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT
if [ "$USE_NPX" -eq 1 ]; then
  # create into temp dir with safe name to avoid naming restriction
  (cd "$TMPDIR" && npx --yes create-react-app@latest "$PROJ_NAME_SAFE" --use-npm >"$TMPLOG" 2>&1) || { sed -n '1,200p' "$TMPLOG" >&2; exit 7; }
else
  (cd "$TMPDIR" && create-react-app "$PROJ_NAME_SAFE" --use-npm >"$TMPLOG" 2>&1) || { sed -n '1,200p' "$TMPLOG" >&2; exit 8; }
fi
# Move generated project contents into the workspace without changing file modes or creating helper executables
SRCDIR="$TMPDIR/$PROJ_NAME_SAFE"
if [ ! -d "$SRCDIR" ]; then echo "scaffold failed: expected output missing" >&2; sed -n '1,200p' "$TMPLOG" >&2; exit 9; fi
# Copy files into workspace, but do not overwrite existing files (idempotent)
shopt -s dotglob
for f in "$SRCDIR"/*; do
  bn=$(basename "$f")
  if [ -e "$WORKSPACE/$bn" ]; then continue; fi
  mv "$f" "$WORKSPACE/"
done
# Add ImageUpload and App only if absent
if [ ! -d src ]; then mkdir -p src; fi
if [ ! -f src/ImageUpload.js ]; then
  cat > src/ImageUpload.js <<'JS'
import React, {useState} from 'react';
export default function ImageUpload(){
  const [src,setSrc]=useState(null);
  return (
    <div>
      <input data-testid="file" type="file" accept="image/*" onChange={e=>{const f=e.target.files[0]; if(!f) return; const r=new FileReader(); r.onload=ev=>setSrc(ev.target.result); r.readAsDataURL(f);}} />
      {src && <img src={src} alt="preview" style={{maxWidth:300}} />}
    </div>
  );
}
JS
fi
if [ ! -f src/App.js ]; then
  cat > src/App.js <<'JS'
import React from 'react';
import ImageUpload from './ImageUpload';
export default function App(){ return (<div><h1>Recipe Finder (dev scaffold)</h1><ImageUpload/></div>); }
JS
fi
if [ ! -f .env.example ]; then
  cat > .env.example <<'ENV'
# REACT_APP_API_URL=http://localhost:3001
ENV
fi
exit 0
