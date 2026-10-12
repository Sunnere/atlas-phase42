#!/usr/bin/env bash
# 07: Valider AI-svar i RiskAgent så riskScore aldri blir NaN/null.
# Bruk: bash scripts/07_fix-risk-ai-response-validation.sh [repo-sti]   (default: .)
set -euo pipefail
REPO="${1:-.}"
cd "$REPO"
[ -f src/agents/RiskAgent.js ] || { echo "FEIL: mangler src/agents/RiskAgent.js (kjør fra repo-roten)"; exit 1; }

python3 - <<'PY'
import sys, pathlib
p = pathlib.Path("src/agents/RiskAgent.js")
src = p.read_text()
out = src

pairs = [
    (
        "    const riskScore = Math.min(100, baseScore + aiBoost * aiAnalysis.confidence);",
        "    const aiConfidence = Number.isFinite(Number(aiAnalysis.confidence)) ? Math.min(1, Math.max(0, Number(aiAnalysis.confidence))) : 0.5;\n    const riskScore = Math.min(100, baseScore + aiBoost * aiConfidence);",
    ),
    (
        "aiAnalysis: aiAnalysis.factors },",
        "aiAnalysis: Array.isArray(aiAnalysis.factors) ? aiAnalysis.factors : [] },",
    ),
]

for old, new in pairs:
    if new in out:
        continue
    if old not in out:
        sys.exit(f"FEIL: fant ikke forventet tekst: {old[:60]!r}")
    out = out.replace(old, new, 1)

if out != src:
    p.write_text(out)
    print("patchet src/agents/RiskAgent.js")
else:
    print("ingen endring (allerede patchet)")
PY

node --check src/agents/RiskAgent.js
echo "OK: syntaks i orden"
echo "Neste: git add src/agents/RiskAgent.js scripts/07_*, commit, push master og main."
