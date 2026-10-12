#!/bin/bash
# Read-only: henter ut varsel-relevant kode fra api/server.js til /tmp/tier_logic.txt
set -e
FILE="api/server.js"
OUT="/tmp/tier_logic.txt"
[ -f "$FILE" ] || { echo "❌ Fant ikke $FILE — kjør fra rota av repoet."; exit 1; }
{
  for pat in "LOYALTY_PROGRAMS" "function fetchAllCampaigns" "function fetchCampaigns" "isWeeklyFallbackWindow" "pickWeeklyGeneralOffers" "spenn" "Spenn" "SkyTeam" "skyteam" "bonusreise" "flying" "miles" "avios" "TIER_FAVORITE_LIMITS" "tier"; do
    echo "===== TREFF: $pat ====="
    grep -n -i "$pat" "$FILE" || echo "(ingen treff)"
    echo
  done
} > "$OUT"
wc -l "$OUT"
echo "✅ Ferdig. Kjør: cat $OUT | pbcopy   og lim inn her."
