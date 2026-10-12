#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

ENTRY="16_railway-backend-phase42.js"

if [ ! -f "$ENTRY" ]; then
  echo "FEIL: $ENTRY finnes ikke. Stopper."
  exit 1
fi
if ! grep -q "webhookListener.httpServer = server;" "$ENTRY" || ! grep -q "webhookListener.initialize();" "$ENTRY"; then
  echo "FEIL: WebSocket-listeneren er ikke koblet til 'server' på forventet måte. Stopper for manuell sjekk."
  grep -n "webhookListener" "$ENTRY" || true
  exit 1
fi
if ! grep -q "^app.listen(port, () => {" "$ENTRY"; then
  if grep -q "^server.listen(port, () => {" "$ENTRY"; then
    echo "Allerede rettet. Ingen endring."
    exit 0
  fi
  echo "FEIL: fant ikke 'app.listen(port, () => {' ved starten av linjen. Stopper."
  exit 1
fi
if [ "$(grep -c '^app.listen(port, () => {' "$ENTRY")" -ne 1 ]; then
  echo "FEIL: forventet nøyaktig én 'app.listen(port, () => {'-linje. Stopper."
  exit 1
fi

sed -i.bak 's/^app\.listen(port, () => {/server.listen(port, () => {/' "$ENTRY"
rm -f "$ENTRY.bak"

echo "== Endring =="
git diff -- "$ENTRY" || true

node --check "$ENTRY"
git add "$ENTRY"
git commit -m "Fix: listen on http server so WebSocket /api/risk/stream gets upgrades"
git push origin master
git push origin master:main
echo "Ferdig."
