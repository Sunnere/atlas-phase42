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
if grep -q "Risk stats: GET" "$ENTRY"; then
  echo "Banner er allerede oppdatert. Ingen endring."
  exit 0
fi
if ! grep -q "ATLAS Phase 4.2 Backend running" "$ENTRY"; then
  echo "FEIL: fant ikke console-banneren 'ATLAS Phase 4.2 Backend running' i $ENTRY. Stopper."
  exit 1
fi

python3 - <<'PY'
import pathlib, re
p = pathlib.Path("16_railway-backend-phase42.js")
src = p.read_text(encoding="utf-8")

src = src.replace("ATLAS Phase 4.2 Backend running", "ATLAS Phase 4.5 & 4.6 Backend running", 1)

pattern = re.compile(r"^.*Orchestrate: POST http://localhost:(\$\{port\}|8080)/api/orchestrate.*$", re.M)
m = pattern.search(src)
if not m:
    raise SystemExit("FEIL: fant ikke Orchestrate-linjen (port-format ukjent).")
line = m.group(0)
port_part = m.group(1)
stats = line.replace("Orchestrate: POST", "Risk stats: GET").replace(
    f"http://localhost:{port_part}/api/orchestrate",
    f"http://localhost:{port_part}/api/risk/stats")
stream = line.replace("Orchestrate: POST", "Risk stream (WebSocket)").replace(
    f"http://localhost:{port_part}/api/orchestrate",
    f"ws://localhost:{port_part}/api/risk/stream")
src = src[:m.end()] + "\n" + stats + "\n" + stream + src[m.end():]
p.write_text(src, encoding="utf-8")
PY

echo "== Endring =="
git diff -- "$ENTRY" || true

if git diff --quiet -- "$ENTRY"; then
  echo "Ingen endring."
  exit 0
fi

node --check "$ENTRY"
git add "$ENTRY"
git commit -m "Update startup banner for Phase 4.5 & 4.6 risk endpoints"
git push origin master
git push origin master:main
echo "Ferdig."
