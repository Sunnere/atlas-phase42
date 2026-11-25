#!/bin/bash
# 02_inspect_loyalty_structure.sh
# READ-ONLY: endrer ingenting. Kartlegger appen før vi legger til Spenn/Norwegian/Strawberry.
# Kjør:  bash ~/bonusvarsel/scripts/02_inspect_loyalty_structure.sh | pbcopy
# (pbcopy legger resultatet i utklippstavlen, lim det inn i chatten)

set -u
REPO="$HOME/bonusvarsel"
cd "$REPO" 2>/dev/null || { echo "FEIL: fant ikke $REPO"; exit 1; }

echo "=== 1. Dart-filer i lib/ (maks 3 nivåer) ==="
find lib -maxdepth 3 -type f -name "*.dart" 2>/dev/null | sort

echo
echo "=== 2. Nøkkelfiler (sti finnes?) ==="
for f in user_state travel_page eb_shopping_page ai_service ai_chat_page api_config main onboarding_page; do
  p=$(find lib -name "${f}.dart" 2>/dev/null | head -1)
  if [ -n "$p" ]; then echo "OK   $p ($(wc -l < "$p" | tr -d ' ') linjer)"; else echo "MANGLER ${f}.dart"; fi
done

echo
echo "=== 3. Relevante pakker i pubspec.yaml ==="
grep -nE "^\s*(image_picker|google_mlkit_text_recognition|http|dio|home_widget|cloud_firestore|firebase_core|shared_preferences|flutter_markdown):" pubspec.yaml 2>/dev/null || echo "(ingen treff)"

echo
echo "=== 4. Saldo-funksjoner (EuroBonus/Trumf) ==="
grep -rnE "(set|get)(Eurobonus|Trumf)Points" lib 2>/dev/null | head -20 || true

echo
echo "=== 5. Hvor kalles Anthropic fra? (nøkkel i appen = må flyttes til backend) ==="
grep -rnE "api\.anthropic\.com|x-api-key|ANTHROPIC_API_KEY" lib 2>/dev/null | sed -E 's/(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]*/\1...MASKERT/g' | head -10 || true
echo "(tomt over = ingen direkte Anthropic-kall i lib/, bra)"

echo
echo "=== 6. Backend-endepunkter i repoet (Node/Express) ==="
find . -maxdepth 3 -name "package.json" -not -path "*/node_modules/*" -not -path "./ios/*" -not -path "./android/*" 2>/dev/null
grep -rnE "\.(get|post)\(['\"]/" --include=*.js . 2>/dev/null | grep -v node_modules | head -25 || true

echo
echo "=== 7. iOS-widget: hvilke nøkler leses? ==="
W=$(find ios -name "BonusWidget*.swift" -not -path "*/Pods/*" 2>/dev/null | head -1)
if [ -n "$W" ]; then echo "$W"; grep -nE "UserDefaults|string\(forKey|integer\(forKey|double\(forKey" "$W" | head -10; else echo "(fant ikke widget-fil)"; fi

echo
echo "=== 8. Git-status (skal være ren før vi patcher) ==="
git status --short 2>/dev/null | head -10
echo "(tomt = ren)"
