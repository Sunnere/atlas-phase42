#!/usr/bin/env bash
# Lager scripts/17_jarvis_gold_label.sh (bygger Jarvis-siden på nytt og gir Gull-agenten navn).
# Kjør fra roten av atlas-phase42:  bash scripts/17_jarvis_gold_setup.sh
set -euo pipefail

if [ ! -f scripts/13_jarvis_holo.sh ]; then
  echo "FEIL: scripts/13_jarvis_holo.sh finnes ikke. Stå i roten av atlas-phase42."
  exit 1
fi

mkdir -p scripts
cat > scripts/17_jarvis_gold_label.sh << 'INNER_EOF'
#!/usr/bin/env bash
# Bygger Jarvis-siden på nytt (13) og gir alle agenter norske navn, inkl. Gull.
# Kjør fra roten av atlas-phase42:  bash scripts/17_jarvis_gold_label.sh
set -euo pipefail

if [ ! -f scripts/13_jarvis_holo.sh ]; then
  echo "FEIL: scripts/13_jarvis_holo.sh finnes ikke. Stå i roten av atlas-phase42."
  exit 1
fi

bash scripts/13_jarvis_holo.sh

python3 - << 'PY'
import re, sys
p = "public/dashboard/jarvis.html"
src = open(p, encoding="utf-8").read()
new = 'const DISPLAY = {risk: "Risk-agent", regnskap: "Regnskap", fund: "Fond-monitor", gmail: "Gmail", calendar: "Kalender", gold: "Gull-agent"};'
out, n = re.subn(r'const DISPLAY = \{[^}]*\};', new, src, count=1)
if n != 1:
    print("FEIL: fant ikke DISPLAY-linjen"); sys.exit(1)
open(p, "w", encoding="utf-8").write(out)
print("DISPLAY oppdatert")
PY

grep -q 'gold: "Gull-agent"' public/dashboard/jarvis.html
echo "OK: public/dashboard/jarvis.html er klar."
echo "Neste steg: git add public/dashboard/jarvis.html && git commit -m 'Jarvis: vis gull-agent' && git push origin master"
INNER_EOF

chmod +x scripts/17_jarvis_gold_label.sh
echo "Skrev scripts/17_jarvis_gold_label.sh"
echo "Kjør nå: bash scripts/17_jarvis_gold_label.sh"
