#!/bin/bash
set -e

cd ~/bonusshop-web

NEW_COLOR="#0F9D6E"

echo "=== FØR endring: viser alle treff på FF385C ==="
grep -rn "FF385C" --include="*.html" ./public

echo ""
echo "=== Bytter #FF385C -> $NEW_COLOR i alle HTML-filer under public/ ==="
find ./public -name "*.html" -exec sed -i '' "s/#FF385C/${NEW_COLOR}/g" {} \;

echo ""
echo "=== ETTER endring: bekrefter at FF385C er borte og ny farge er inne ==="
if grep -rn "FF385C" --include="*.html" ./public; then
  echo "FEIL: FF385C finnes fortsatt et sted, sjekk over"
  exit 1
else
  echo "OK: Ingen FF385C-treff igjen"
fi

echo ""
echo "=== Viser nye treff på $NEW_COLOR ==="
grep -rln "$NEW_COLOR" --include="*.html" ./public

echo ""
echo "=== Ferdig. Ikke deployet ennå - sjekk visuelt lokalt eller kjør firebase deploy manuelt når du er fornøyd ==="
