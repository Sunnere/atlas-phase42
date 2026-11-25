#!/bin/bash
# 09_fix_runner_deployment_target.sh
# Fikser MACOSX_DEPLOYMENT_TARGET i selve Runner-prosjektet (ikke Pods) + Flutter-xcconfig-filene.
# Kjør EN GANG etter 08_fix_macos_deployment_target.sh, deretter kjør pod install på nytt.
# Kjør fra prosjektmappen:  bash ~/Downloads/09_fix_runner_deployment_target.sh
set -euo pipefail
ROOT="${BONUS_ROOT:-$PWD}"
cd "$ROOT"
PBX=macos/Runner.xcodeproj/project.pbxproj
[ -f pubspec.yaml ] && [ -d lib ] || { echo "FEIL: $ROOT mangler pubspec.yaml eller lib"; exit 1; }
[ -f "$PBX" ] || { echo "FEIL: $PBX finnes ikke"; exit 1; }

BK=".script_backups/$(date +%Y%m%d-%H%M%S)_09"
mkdir -p "$BK/macos/Runner.xcodeproj" "$BK/macos/Flutter"
cp "$PBX" "$BK/macos/Runner.xcodeproj/"

N=$(grep -c 'MACOSX_DEPLOYMENT_TARGET = [0-9]' "$PBX" || true)
if [ "$N" -eq 0 ]; then
  echo "SKIP: ingen MACOSX_DEPLOYMENT_TARGET-linjer i $PBX (uvanlig, sjekk manuelt)"; exit 0
fi
ALREADY=$(grep -c 'MACOSX_DEPLOYMENT_TARGET = 12\.0;' "$PBX" || true)
if [ "$ALREADY" -eq "$N" ]; then
  echo "SKIP: alle $N treff i $PBX er allerede 12.0. Ingenting endret."
else
  sed -i.bak -E 's/MACOSX_DEPLOYMENT_TARGET = [0-9]+(\.[0-9]+)?;/MACOSX_DEPLOYMENT_TARGET = 12.0;/g' "$PBX"
  rm -f "$PBX.bak"
  echo "OK: oppdaterte $N MACOSX_DEPLOYMENT_TARGET-linjer i $PBX til 12.0"
fi

for f in macos/Flutter/Flutter-Debug.xcconfig macos/Flutter/Flutter-Release.xcconfig macos/Flutter/Flutter-Profile.xcconfig; do
  [ -f "$f" ] || continue
  if grep -q '^MACOSX_DEPLOYMENT_TARGET=' "$f"; then
    cp "$f" "$BK/macos/Flutter/$(basename "$f")"
    if grep -q '^MACOSX_DEPLOYMENT_TARGET=12\.0$' "$f"; then
      echo "SKIP: $f er allerede 12.0"
    else
      sed -i.bak -E 's/^MACOSX_DEPLOYMENT_TARGET=.*/MACOSX_DEPLOYMENT_TARGET=12.0/' "$f"
      rm -f "$f.bak"
      echo "OK: oppdaterte $f til 12.0"
    fi
  fi
done

echo "✅ Ferdig. Backup: $BK"
echo "Neste steg (i denne rekkefølgen):"
echo "  cd macos && pod deintegrate && pod install --repo-update && cd .."
echo "  flutter clean && flutter pub get"
echo "  flutter run -d macos"
