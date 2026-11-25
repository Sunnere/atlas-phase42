#!/bin/bash
# 04_inspect_balance_code.sh - SKRIVEBESKYTTET. Endrer ingenting. Maskerer nøkler.
# Kjør fra prosjektmappen:  bash ~/Downloads/04_inspect_balance_code.sh > ~/Desktop/balance_output.txt
ROOT="${BONUS_ROOT:-$PWD}"
cd "$ROOT" 2>/dev/null || { echo "FEIL: finner ikke $ROOT"; exit 1; }
[ -f pubspec.yaml ] && [ -d lib ] || { echo "FEIL: $ROOT mangler pubspec.yaml eller lib"; exit 1; }

mask() { sed -E 's/(sk-ant-[A-Za-z0-9_-]{0,8})[A-Za-z0-9_-]*/\1***MASKERT***/g; s/(AIza[A-Za-z0-9_-]{0,4})[A-Za-z0-9_-]*/\1***MASKERT***/g; s/(sk_(live|test)_)[A-Za-z0-9]*/\1***MASKERT***/g'; }
show() { # fil [fra] [til]
  if [ -f "$1" ]; then echo "--- $1 ${2:+(linje $2-$3)} ---"; if [ -n "$2" ]; then sed -n "${2},${3}p" "$1" | mask; else head -250 "$1" | mask; fi; else echo "--- $1: FINNES IKKE ---"; fi; echo; }

echo "=== A. user_state.dart (hele) ==="; show lib/services/user_state.dart
echo "=== B. travel_page.dart saldo-logikk ==="; show lib/pages/travel_page.dart 105 200
echo "=== C. travel_page.dart saldo-inntasting ==="; show lib/pages/travel_page.dart 795 870
echo "=== D. program_logo.dart ==="; show lib/widgets/program_logo.dart 1 50
echo "=== E. api_config.dart ==="; show lib/config/api_config.dart

echo "=== F. ai_service.dart (topp) ==="; show lib/services/ai_service.dart 1 40

echo "=== G. Bygges det med dart-define? (nøkler maskert) ==="
grep -rnE 'dart-define|ANTHROPIC_API_KEY' . --include=*.sh --include=*.yaml --include=*.yml --include=*.json --include=Makefile --include=*.md --exclude-dir=build --exclude-dir=.dart_tool --exclude-dir=Pods --exclude-dir=node_modules 2>/dev/null | mask | head -20
echo "(ferdig med G)"; echo

echo "=== H. iOS widget (Swift) ==="
SW=$(find ios -name '*.swift' -not -path '*/Pods/*' -not -path '*/Runner/*' 2>/dev/null | head -3)
if [ -z "$SW" ]; then echo "Ingen widget-Swift funnet"; else for f in $SW; do show "$f"; done; fi

echo "=== I. iOS Info.plist: bildetilgang ==="
grep -nE 'NSPhotoLibraryUsageDescription|NSCameraUsageDescription' ios/Runner/Info.plist 2>/dev/null || echo "Ingen bildetillatelser funnet"

echo; echo "=== J. Endepunkter i api_service.dart ==="
grep -nE "Uri\.parse|/api/|'/[a-z]" lib/services/api_service.dart 2>/dev/null | mask | head -40

echo; echo "=== FERDIG ==="
