#!/bin/bash
# Pekar Procfile og package.json "start" til atlas-backend/server.js (Phase 4.5 & 4.6).
# Kjøres fra repo-roten: bash scripts/01_fix-start-command.sh
set -euo pipefail

if [ ! -f Procfile ] || [ ! -f package.json ]; then
  echo "FEIL: Procfile eller package.json finnes ikke her. Kjor fra repo-roten."
  exit 1
fi

python3 - << 'PY'
import re, pathlib

old = "16_railway-backend-phase42.js"
new = "cd atlas-backend && node server.js"

p = pathlib.Path("Procfile")
t = p.read_text()
t2 = t.replace("node " + old, new)
if t2 == t and "server.js" not in t:
    raise SystemExit("FEIL: uventet innhold i Procfile: " + t)
p.write_text(t2)

p = pathlib.Path("package.json")
t = p.read_text()
t2 = re.sub(r'"start":\s*"node ' + re.escape(old) + '"', '"start": "' + new + '"', t)
if t2 == t and "atlas-backend" not in t:
    raise SystemExit("FEIL: fant ikke start-script i package.json")
p.write_text(t2)
print("OK: Procfile og package.json oppdatert")
PY

echo "--- Procfile ---"
cat Procfile
echo "--- package.json start ---"
grep -n '"start"' package.json
