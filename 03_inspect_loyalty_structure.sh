#!/bin/bash
# 03_inspect_loyalty_structure.sh - SKRIVEBESKYTTET. Endrer ingenting. Maskerer nøkler.
# Kjør fra prosjektmappen:  bash ~/Downloads/03_inspect_loyalty_structure.sh | pbcopy
ROOT="${BONUS_ROOT:-$PWD}"
cd "$ROOT" 2>/dev/null || { echo "FEIL: finner ikke $ROOT"; exit 1; }
[ -f pubspec.yaml ] && [ -d lib ] || { echo "FEIL: $ROOT mangler pubspec.yaml eller lib"; exit 1; }

mask() { sed -E 's/(sk-ant-[A-Za-z0-9_-]{0,8})[A-Za-z0-9_-]*/\1***MASKERT***/g; s/(AIza[A-Za-z0-9_-]{0,4})[A-Za-z0-9_-]*/\1***MASKERT***/g; s/(sk_(live|test)_)[A-Za-z0-9]*/\1***MASKERT***/g'; }

echo "=== 1. VERSJON ==="
grep -E '^(name|version):' pubspec.yaml

echo; echo "=== 2. MAPPER I lib ==="
find lib -maxdepth 2 -type d | sort

echo; echo "=== 3. DART-FILER (uten .bak) ==="
find lib -name '*.dart' | sort | head -150

echo; echo "=== 4. SALDO / UserState / widget ==="
grep -rnE 'class UserState|sasBalance|trumfBalance|eurobonus|Balance|saldo|HomeWidget' lib --include=*.dart 2>/dev/null | mask | head -60

echo; echo "=== 5. ANTHROPIC / API-KALL ==="
grep -rniE 'anthropic|sk-ant|x-api-key|railway|http\.post' lib --include=*.dart 2>/dev/null | mask | head -30

echo; echo "=== 6. HARDKODEDE NØKLER I lib (skal være 0) ==="
N=$(grep -rnE 'sk-ant-|sk_live_|sk_test_' lib --include=*.dart 2>/dev/null | wc -l | tr -d ' ')
echo "Antall treff: $N"

echo; echo "=== 7. FIRESTORE-BRUK ==="
grep -rnE "collection\(['\"]" lib --include=*.dart 2>/dev/null | head -25

echo; echo "=== 8. PAKKER (pubspec) ==="
sed -n '/^dependencies:/,/^dev_dependencies:/p' pubspec.yaml | head -50

echo; echo "=== FERDIG ==="
