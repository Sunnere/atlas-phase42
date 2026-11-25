#!/bin/bash
# ============================================================================
# 06_legg_til_retry_loyaltykey.sh
#
# Formål: Legge til retry i fetchCampaigns() (SAS/LoyaltyKey-kallet) slik at
# ETT forbigående glipp (rate-limit, kald Railway-start, midlertidig
# nettverksfeil) ikke lenger fører til et falskt "0 kampanjer / trolig nede"
# -varsel. Bekreftet via debug-ruta at API-et og mapping-logikken er sunn -
# problemet er mangel på robusthet, ikke en bug i selve mappingen.
#
# Endring i fetchCampaigns():
#   - Prøver opptil 3 ganger (1 første forsøk + 2 retries)
#   - Kort delay mellom forsøk (500ms, dobles: 500ms -> 1000ms)
#   - Retryer KUN på faktisk feil (non-OK-respons eller kastet feil/timeout)
#   - Retryer IKKE hvis API-et svarer OK med gyldig, men tom liste - det er
#     ikke en feilsituasjon, bare ingen kampanjer akkurat da
#   - Logger hvert forsøk slik at vi ser i Railway-loggene om retry faktisk
#     reddet situasjonen ("LoyaltyKey forsøk 1 feilet, prøver igjen...")
#
# Kjør slik:
#   cd /Users/sunnerehelse/bonusvarsel
#   bash scripts/06_legg_til_retry_loyaltykey.sh
#
# ETTER KJØRING - OBLIGATORISK:
#   git diff api/server.js
# ============================================================================

set -euo pipefail

TARGET_FILE="api/server.js"

if [ ! -f "$TARGET_FILE" ]; then
  echo "❌ Fant ikke $TARGET_FILE i gjeldende mappe."
  echo "   Kjør fra roten av bonusvarsel-repoet:"
  echo "   cd /Users/sunnerehelse/bonusvarsel && bash scripts/06_legg_til_retry_loyaltykey.sh"
  exit 1
fi

if ! grep -q "^async function fetchCampaigns" "$TARGET_FILE"; then
  echo "⚠️  Fant ikke funksjonen fetchCampaigns() i $TARGET_FILE."
  echo "   Gjør INGEN endring. Kjør dette og lim inn resultatet:"
  echo "   grep -n -B2 -A80 \"^async function fetchCampaigns\" $TARGET_FILE"
  exit 2
fi

if ! grep -q 'throw new Error(`LoyaltyKey campaigns failed: \${response.status}`);' "$TARGET_FILE"; then
  echo "⚠️  Fant funksjonen, men ikke det forventede innholdet (feilkastingen på non-OK-respons)."
  echo "   Filen kan ha blitt endret siden sist. Gjør INGEN endring."
  echo "   Kjør dette og lim inn resultatet:"
  echo "   grep -n -B2 -A80 \"^async function fetchCampaigns\" $TARGET_FILE"
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
    r'async function fetchCampaigns\(\) \{\s*\n'
    r'\s*const apiUrl =\s*\n'
    r'\s*"https://onlineshopping\.loyaltykey\.com/api/v1/campaigns\?filter\[channel\]=SAS&filter\[language\]=nb&filter\[country\]=NO&filter\[amount\]=20";\s*\n'
    r'\s*\n'
    r'\s*try \{\s*\n'
    r'\s*const response = await fetch\(apiUrl, \{\s*\n'
    r'\s*headers: \{\s*\n'
    r'\s*"User-Agent": "Mozilla/5\.0 \(Macintosh; Intel Mac OS X 10_15_7\)",\s*\n'
    r'\s*"Accept": "application/json, text/plain, \*/\*",\s*\n'
    r'\s*\},\s*\n'
    r'\s*\}\);\s*\n'
    r'\s*\n'
    r'\s*if \(!response\.ok\) \{\s*\n'
    r'\s*throw new Error\(`LoyaltyKey campaigns failed: \$\{response\.status\}`\);\s*\n'
    r'\s*\}\s*\n'
    r'\s*\n'
    r'\s*const payload = await response\.json\(\);'
)

replacement = (
    'async function fetchCampaigns() {\n'
    '  const apiUrl =\n'
    '    "https://onlineshopping.loyaltykey.com/api/v1/campaigns?filter[channel]=SAS&filter[language]=nb&filter[country]=NO&filter[amount]=20";\n'
    '\n'
    '  // LAGT TIL 2026-09-21: retry ved forbigående feil (rate-limit, kald\n'
    '  // Railway-start, nettverksglipp). Bekreftet via /v1/dev/debug-loyaltykey-raw\n'
    '  // at API-et og mapping-logikken er sunn - dette gjelder KUN robusthet mot\n'
    '  // enkeltstående feilede kall, slik at vi ikke sender et falskt\n'
    '  // "0 kampanjer / trolig nede"-varsel pga. ett glipp.\n'
    '  const MAX_ATTEMPTS = 3;\n'
    '  let lastError = null;\n'
    '\n'
    '  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {\n'
    '    try {\n'
    '      const response = await fetch(apiUrl, {\n'
    '        headers: {\n'
    '          "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",\n'
    '          "Accept": "application/json, text/plain, */*",\n'
    '        },\n'
    '      });\n'
    '\n'
    '      if (!response.ok) {\n'
    '        throw new Error(`LoyaltyKey campaigns failed: ${response.status}`);\n'
    '      }\n'
    '\n'
    '      const payload = await response.json();'
)

new_content, n = old_pattern.subn(replacement, content)

if n == 0:
    print("PATCH_FAILED_NO_MATCH")
    sys.exit(2)
if n > 1:
    print(f"PATCH_FAILED_TOO_MANY_MATCHES matches={n}")
    sys.exit(2)

# Del 2: lukk try/for-løkken riktig og legg til retry-delay i catch-blokken.
old_tail = re.compile(
    r'    console\.log\("fetchCampaigns LoyaltyKey mapped:", mapped\.length\);\s*\n'
    r'\s*\n'
    r'    return mapped;\s*\n'
    r'  \} catch \(e\) \{\s*\n'
    r'    console\.error\("fetchCampaigns LoyaltyKey failed:", String\(e\)\);\s*\n'
    r'    return \[\];\s*\n'
    r'  \}\s*\n'
    r'\}'
)

new_tail = (
    '      console.log("fetchCampaigns LoyaltyKey mapped:", mapped.length);\n'
    '\n'
    '      return mapped;\n'
    '    } catch (e) {\n'
    '      lastError = e;\n'
    '      console.error(`fetchCampaigns LoyaltyKey forsøk ${attempt}/${MAX_ATTEMPTS} feilet:`, String(e));\n'
    '\n'
    '      if (attempt < MAX_ATTEMPTS) {\n'
    '        const delayMs = 500 * attempt; // 500ms, så 1000ms\n'
    '        await new Promise((resolve) => setTimeout(resolve, delayMs));\n'
    '      }\n'
    '    }\n'
    '  }\n'
    '\n'
    '  console.error("fetchCampaigns LoyaltyKey failed after retries:", String(lastError));\n'
    '  return [];\n'
    '}'
)

new_content2, n2 = old_tail.subn(new_tail, new_content)

if n2 == 0:
    print("PATCH_FAILED_NO_MATCH_TAIL")
    sys.exit(2)
if n2 > 1:
    print(f"PATCH_FAILED_TOO_MANY_MATCHES_TAIL matches={n2}")
    sys.exit(2)

with open(path, "w", encoding="utf-8") as f:
    f.write(new_content2)

print(f"PATCH_OK matches={n} tail_matches={n2}")
PYEOF

echo ""
echo "✅ Endring gjort i $TARGET_FILE"
echo ""
echo "NESTE STEG (viktig):"
echo "  1. git diff $TARGET_FILE   ← sjekk at endringen ser riktig ut"
echo "  2. git add $TARGET_FILE && git commit -m \"Legg til retry i fetchCampaigns (LoyaltyKey) mot forbigående feil\""
echo "  3. git push"
echo ""
echo "Merk: dette retryer KUN ved feil (non-OK/nettverksfeil), ikke ved gyldig"
echo "tomt svar. Sjekk Railway-loggene neste gang 0-kampanjer-varselet dukker"
echo "opp - se om retry-forsøkene (\"forsøk 1/3 feilet\" osv.) faktisk vises."
