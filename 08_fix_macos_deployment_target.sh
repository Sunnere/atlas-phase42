#!/bin/bash
# 08_fix_macos_deployment_target.sh
# Fikser "MACOSX_DEPLOYMENT_TARGET ... 10.12/10.15 ... range is 12.0" ved pod install/flutter run -d macos.
# Endrer macos/Podfile: bumper 'platform :osx' til 12.0, og legger til en post_install-linje
# som tvinger MACOSX_DEPLOYMENT_TARGET=12.0 på ALLE pod-targets (ikke bare Flutter sine egne).
# Kjør fra prosjektmappen:  bash ~/Downloads/08_fix_macos_deployment_target.sh
set -euo pipefail
ROOT="${BONUS_ROOT:-$PWD}"
cd "$ROOT"
F=macos/Podfile
[ -f pubspec.yaml ] && [ -d lib ] || { echo "FEIL: $ROOT mangler pubspec.yaml eller lib"; exit 1; }
[ -f "$F" ] || { echo "FEIL: $F finnes ikke"; exit 1; }
command -v python3 >/dev/null || { echo "FEIL: python3 mangler"; exit 1; }

if grep -q "MACOSX_DEPLOYMENT_TARGET'\] = '12.0'" "$F"; then
  echo "SKIP: $F har allerede deployment-target-fiksen. Ingenting endret."; exit 0
fi

BK=".script_backups/$(date +%Y%m%d-%H%M%S)_08"
mkdir -p "$BK/macos"
cp "$F" "$BK/$F"

python3 - <<'PY'
import re, sys
p = 'macos/Podfile'
s = open(p, encoding='utf-8').read()

m = re.search(r"^platform :osx, '([\d.]+)'", s, re.M)
if not m:
    print("FEIL: fant ikke 'platform :osx, ...'-linjen i Podfile"); sys.exit(2)
old_platform_line = m.group(0)
s = s.replace(old_platform_line, "platform :osx, '12.0'", 1)

anchor = "post_install do |installer|\n  installer.pods_project.targets.each do |target|\n    flutter_additional_macos_build_settings(target)\n  end\n"
if s.count(anchor) != 1:
    print(f"FEIL: fant post_install-blokken {s.count(anchor)} ganger (forventet 1). Ingenting er endret.")
    sys.exit(2)

extra = anchor + "    target.build_configurations.each do |config|\n      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '12.0'\n    end\n"
s = s.replace(anchor, extra, 1)

open(p, 'w', encoding='utf-8').write(s)
print(f"OK: byttet '{old_platform_line}' -> platform :osx, '12.0', og la til tvunget deployment target i post_install")
PY

echo "✅ Ferdig. Backup: $BK"
echo "Neste steg:"
echo "  cd macos && pod install --repo-update && cd .."
echo "  flutter clean && flutter pub get"
echo "  flutter run -d macos"
