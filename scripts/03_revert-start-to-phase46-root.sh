#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

ENTRY="16_railway-backend-phase42.js"

if [ ! -f "$ENTRY" ]; then
  echo "FEIL: $ENTRY finnes ikke. Stopper."
  exit 1
fi
if ! grep -q "setupRiskRoutes(app)" "$ENTRY"; then
  echo "FEIL: $ENTRY kobler ikke inn setupRiskRoutes. Stopper."
  exit 1
fi

python3 - <<'PY'
import re, pathlib
ENTRY = "16_railway-backend-phase42.js"
BAD = "cd atlas-backend && node server.js"
GOOD = f"node {ENTRY}"

p = pathlib.Path("Procfile")
if p.exists():
    p.write_text(p.read_text().replace(BAD, GOOD))

p = pathlib.Path("package.json")
if p.exists():
    t = p.read_text()
    t = re.sub(r'("start"\s*:\s*")[^"]*(")', lambda m: m.group(1) + GOOD + m.group(2), t)
    p.write_text(t)
PY

echo "== Procfile =="; cat Procfile
echo "== package.json start =="; grep -n '"start"' package.json

if git diff --quiet -- Procfile package.json; then
  echo "Ingen endring nødvendig."
  exit 0
fi

git add Procfile package.json
git commit -m "Fix: start Phase 4.6 server via 16_railway-backend-phase42.js (includes risk routes)"
git push origin master
git push origin master:main
echo "Ferdig."
