#!/bin/bash
# ============================================================================
# 02_trippel_trumf_varsel_2dager_for.sh
#
# Erstatter forrige forsøk (01_trippel_trumf_varsel_i_dag.sh), som traff
# feil mønster - din faktiske kode ser annerledes ut enn det vi husket.
# Dette scriptet er laget mot den EKTE koden du limte inn (api/server.js
# linje 1318-1331), og testet mot en nøyaktig kopi av den før levering.
#
# Formål: Endre trippelTrumfDateTomorrow() PERMANENT slik at
# isTrippelTrumfEveWindow() trigges 2 dager før selve Trippel Trumf-dagen
# (kl 18:00), i stedet for 1 dag før (kvelden før) som i dag.
# Effekt akkurat nå: varselet for 17. sept trigges 15. sept (i dag) kl 18:00
# i stedet for 16. sept. Gjelder også fremtidige datoer i listen (f.eks. 15. okt).
#
# Kjør slik:
#   cd /Users/sunnerehelse/bonusvarsel
#   bash scripts/02_trippel_trumf_varsel_2dager_for.sh
#
# ETTER KJØRING - OBLIGATORISK:
#   git diff api/server.js
# ============================================================================

set -euo pipefail

TARGET_FILE="api/server.js"

if [ ! -f "$TARGET_FILE" ]; then
  echo "❌ Fant ikke $TARGET_FILE i gjeldende mappe."
  echo "   Kjør scriptet fra roten av bonusvarsel-repoet:"
  echo "   cd /Users/sunnerehelse/bonusvarsel && bash scripts/02_trippel_trumf_varsel_2dager_for.sh"
  exit 1
fi

if ! grep -q "function trippelTrumfDateTomorrow" "$TARGET_FILE"; then
  echo "⚠️  Fant ikke funksjonen trippelTrumfDateTomorrow() i $TARGET_FILE."
  echo "   Gjør INGEN endring. Kjør dette og lim inn resultatet:"
  echo "   grep -n -B2 -A15 \"function trippelTrumfDateTomorrow\" $TARGET_FILE"
  exit 2
fi

if ! grep -q "now.getDate() + 1" "$TARGET_FILE"; then
  echo "⚠️  Fant funksjonen, men ikke det forventede mønsteret (\"getDate() + 1\")."
  echo "   Filen kan ha blitt endret siden sist. Gjør INGEN endring."
  echo "   Kjør dette og lim inn resultatet:"
  echo "   grep -n -B2 -A15 \"function trippelTrumfDateTomorrow\" $TARGET_FILE"
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

# Målrettet mot funksjonen trippelTrumfDateTomorrow() spesifikt, ikke et
# generisk "getDate() + 1"-treff andre steder i filen.
old_pattern = re.compile(
    r"(function trippelTrumfDateTomorrow\(\) \{\s*\n"
    r"\s*const now = osloNow\(\);\s*\n"
    r"\s*const tomorrow = new Date\(now\.getFullYear\(\), now\.getMonth\(\), )"
    r"now\.getDate\(\) \+ 1(\);)"
)

def replacement(m):
    return (
        "  // ENDRET 2026-09-15: varsel skal nå trigges 2 dager før Trippel\n"
        + "  // Trumf-dagen (var: + 1, dvs. kvelden før). Effekt: 17.sept-varselet\n"
        + "  // sendes 15.sept kl 18:00 i stedet for 16.sept.\n"
        + m.group(1)
        + "now.getDate() + 2"
        + m.group(2)
    )

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
echo "  2. git add $TARGET_FILE && git commit -m \"Trippel Trumf-varsel: 2 dager før i stedet for 1\""
echo "  3. git push"
echo ""
echo "Husk: Railway sin in-memory state nullstilles ved deploy - sjekk om"
echo "favoritter må registreres på nytt før du tester check-favorites."
