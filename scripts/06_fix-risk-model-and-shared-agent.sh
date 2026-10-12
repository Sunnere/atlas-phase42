#!/usr/bin/env bash
# 06: Fiks RiskAgent-modell, logg AI-feil, og del én RiskAgent-instans mellom stats og webhook.
# Bruk: bash scripts/06_fix-risk-model-and-shared-agent.sh [repo-sti]   (default: .)
set -euo pipefail
REPO="${1:-.}"
cd "$REPO"

for f in src/agents/RiskAgent.js src/routes/riskRoutes.js src/routes/webhookRoutes.js; do
  [ -f "$f" ] || { echo "FEIL: mangler $f (kjør fra repo-roten)"; exit 1; }
done

# 1) Ny delt singleton-modul
cat > src/agents/riskAgentInstance.js <<'JS'
const RiskAgent = require("./RiskAgent");

let instance = null;

// Én delt RiskAgent for hele appen, slik at stats og webhook bruker samme historikk.
function getRiskAgent() {
  if (!instance) {
    instance = new RiskAgent(process.env.ANTHROPIC_API_KEY);
  }
  return instance;
}

module.exports = { getRiskAgent };
JS

# 2) Patch RiskAgent, riskRoutes og webhookRoutes (idempotent)
python3 - <<'PY'
import re, sys, pathlib

def patch(path, pairs):
    p = pathlib.Path(path)
    src = p.read_text()
    out = src
    for old, new in pairs:
        if new in out:
            continue  # allerede patchet
        if old not in out:
            sys.exit(f"FEIL: fant ikke forventet tekst i {path}: {old[:60]!r}")
        out = out.replace(old, new, 1)
    if out != src:
        p.write_text(out)
        print(f"patchet {path}")
    else:
        print(f"ingen endring i {path} (allerede patchet)")

patch("src/agents/RiskAgent.js", [
    (
        'model: "claude-3-5-sonnet-20241022",',
        'model: process.env.ATLAS_RISK_MODEL || "claude-haiku-5-5",',
    ),
    (
        '    } catch (error) {\n      return { anomalyRiskLevel: "medium", confidence: 0.5, factors: ["api-error"], reasoning: "Claude API unavailable" };',
        '    } catch (error) {\n      console.error("RiskAgent AI-feil:", error && error.message ? error.message : error);\n      return { anomalyRiskLevel: "medium", confidence: 0.5, factors: ["api-error"], reasoning: "Claude API unavailable: " + (error && error.message ? error.message : "ukjent feil") };',
    ),
])

patch("src/routes/riskRoutes.js", [
    (
        'const agent = new RiskAgent(process.env.ANTHROPIC_API_KEY);',
        'const { getRiskAgent } = require("../agents/riskAgentInstance");\n  const agent = getRiskAgent();',
    ),
])

patch("src/routes/webhookRoutes.js", [
    (
        'function setupWebhookRoutes(app, webhookListener, riskAgentModule) {',
        'const { getRiskAgent } = require("../agents/riskAgentInstance");\n\nfunction setupWebhookRoutes(app, webhookListener, riskAgentModule) {',
    ),
    (
        'const agent = new RiskAgent(process.env.ANTHROPIC_API_KEY);',
        'const agent = getRiskAgent();',
    ),
])
PY

# 3) Syntakssjekk
for f in src/agents/riskAgentInstance.js src/agents/RiskAgent.js src/routes/riskRoutes.js src/routes/webhookRoutes.js; do
  node --check "$f"
done
echo "OK: syntaks i orden"
echo "Neste: git diff, deretter git add + commit + push til master og main."
