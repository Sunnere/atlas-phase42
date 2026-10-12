#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

echo "== Status =="
if [ ! -d atlas-backend ]; then
  echo "FEIL: mappen atlas-backend/ finnes ikke lokalt. Stopper."
  exit 1
fi

TRACKED=$(git ls-files atlas-backend | wc -l | tr -d ' ')
echo "Filer i atlas-backend som git sporer: $TRACKED"

if [ "$TRACKED" -gt 0 ]; then
  echo "atlas-backend er allerede sporet i git. Ingen commit nødvendig."
  git ls-files atlas-backend | head -20
  exit 0
fi

echo "atlas-backend er IKKE sporet. Legger til filer."
git add atlas-backend
git status --short atlas-backend | head -30
git commit -m "Track atlas-backend (Phase 4.5/4.6 server) for Railway deploy"
git push origin master
git push origin master:main
echo "Ferdig. Railway deployer på nytt fra master."
