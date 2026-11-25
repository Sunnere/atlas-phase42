#!/bin/bash
# ============================================================================
# 04_rydd_elite_kampanje.sh
#
# Formål: Rydde opp fetchEliteCampaigns() i api/server.js.
# I dag returnerer den ÉN hardkodet kampanje med en utløpt dato
# (22.06.2026 - "Spar 2000 kr"), som vi ikke lenger kan stole på er
# korrekt (samme problem som Trumf/SAS-tallene fra forrige økt).
#
# Endring:
#   1. Fjerner det utløpte, konkrete tilbudet (dato + kronebeløp)
#   2. Erstatter med en tom liste + en kommentar som forklarer hvorfor,
#      slik at appen ikke viser en død/feil kampanje til elite-brukere
#   3. Legger til en TODO-kommentar: elite/SkyTeam-varsling har ingen
#      egen datakilde i dag - bør bygges som egen ting, ikke bare
#      legges inn i denne hardkodede lista igjen
#
# Dette er en MIDLERTIDIG rydding (ingen ny datakilde bygges her), på
# samme måte som Trumf/SAS ble ryddet med nøytral tekst forrige økt,
# inntil en ekte SAS Holidays/SkyTeam-kilde er på plass.
#
# Kjør slik:
#   cd /Users/sunnerehelse/bonusvarsel
#   bash scripts/04_rydd_elite_kampanje.sh
#
# ETTER KJØRING - OBLIGATORISK:
#   git diff api/server.js
# ============================================================================

set -euo pipefail

TARGET_FILE="api/server.js"

if [ ! -f "$TARGET_FILE" ]; then
  echo "❌ Fant ikke $TARGET_FILE i gjeldende mappe."
  echo "   Kjør fra roten av bonusvarsel-repoet:"
  echo "   cd /Users/sunnerehelse/bonusvarsel && bash scripts/04_rydd_elite_kampanje.sh"
  exit 1
fi

if ! grep -q "async function fetchEliteCampaigns" "$TARGET_FILE"; then
  echo "⚠️  Fant ikke funksjonen fetchEliteCampaigns() i $TARGET_FILE."
  echo "   Gjør INGEN endring. Kjør dette og lim inn resultatet:"
  echo "   grep -n -B2 -A20 \"async function fetchEliteCampaigns\" $TARGET_FILE"
  exit 2
fi

if ! grep -q "SAS Holidays: Spar 2 000 kr" "$TARGET_FILE"; then
  echo "⚠️  Fant funksjonen, men ikke det forventede innholdet (\"SAS Holidays: Spar 2 000 kr\")."
  echo "   Filen kan ha blitt endret siden sist. Gjør INGEN endring."
  echo "   Kjør dette og lim inn resultatet:"
  echo "   grep -n -B2 -A20 \"async function fetchEliteCampaigns\" $TARGET_FILE"
  exit 2
fi

BACKUP="${TARGET_FILE}.bak_$(date +%Y%m%d_%H%M%S)"
cp "$TARGET_FILE" "$BACKUP"
echo "✅ Sikkerhetskopi laget: $BACKUP"

python3 - "$TARGET_FILE" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

old_pattern = re.compile(
    r"// ── SAS Holidays / Elite-tilbud ─+\s*\n"
    r"async function fetchEliteCampaigns\(\) \{\s*\n"
    r"\s*const holidays = \[\s*\n"
    r"\s*\{\s*\n"
    r"\s*title: 'SAS Holidays: Spar 2 000 kr',\s*\n"
    r"\s*desc: 'Bestill fly \+ hotell innen 22\. juni',\s*\n"
    r"\s*code: 'SUMMERDEAL',\s*\n"
    r"\s*savings: '2000 kr',\s*\n"
    r"\s*url: 'https://www\.flysas\.com/no-no/sas-holidays/',\s*\n"
    r"\s*ends: '22\.06\.2026',\s*\n"
    r"\s*\},\s*\n"
    r"\s*\];\s*\n"
    r"\s*return holidays\.map\(\(h, i\) => \(\{\s*\n"
    r"\s*\.\.\.h,\s*\n"
    r"\s*id: `elite-holiday-\$\{i\}`,\s*\n"
    r"\s*source: 'elite',\s*\n"
    r"\s*\}\)\);\s*\n"
    r"\}"
)

replacement = """// ── SAS Holidays / Elite-tilbud ──────────────────────────────────────────────
// RYDDET 2026-09-17: forrige hardkodede kampanje (\"Spar 2 000 kr\", frist
// 22.06.2026) er utløpt og fjernet - vi viste en død kampanje til
// elite-brukere. Returnerer tom liste inntil en ekte kilde er på plass.
//
// TODO: elite/SkyTeam/bonusreise-varsling har INGEN egen datakilde i dag -
// dette er kun ett hardkodet element som går inn i samme
// checkFavoritesAndNotify()-favoritt-matching som Trumf/SAS. Skal dette
// faktisk fungere for elite-brukere må det bygges som egen ting (egen
// henting av SAS Holidays-tilbud + egen varslingslogikk), ikke bare fylles
// inn her igjen med et nytt hardkodet tall/dato.
async function fetchEliteCampaigns() {
  const holidays = [];
  return holidays.map((h, i) => ({
    ...h,
    id: `elite-holiday-${i}`,
    source: 'elite',
  }));
}"""

new_content, n = old_pattern.subn(replacement, content)

if n == 0:
    print("PATCH_FAILED_NO_MATCH")
    sys.exit(2)
if n > 1:
    print(f"PATCH_FAILED_TOO_MANY_MATCHES matches={n}")
    sys.exit(2)

with open(path, "w", encoding="utf-8") as f:
    f.write(new_content)

print(f"PATCH_OK matches={n}")
PYEOF

echo ""
echo "✅ Endring gjort i $TARGET_FILE"
echo ""
echo "NESTE STEG (viktig):"
echo "  1. git diff $TARGET_FILE   ← sjekk at endringen ser riktig ut"
echo "  2. git add $TARGET_FILE && git commit -m \"Fjern utløpt hardkodet elite-kampanje (SAS Holidays)\""
echo "  3. git push"
echo ""
echo "Merk: dette fjerner kun det utløpte tilbudet. Elite-brukere får ingen"
echo "SAS Holidays/SkyTeam-varsler før en ekte datakilde bygges (se TODO i koden)."
