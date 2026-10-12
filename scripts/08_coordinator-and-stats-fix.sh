#!/usr/bin/env bash
# 08: (a) Normaliser tidsstempel så stats teller riktig, (b) legg til koordinator + checker-agent.
# Bruk: bash scripts/08_coordinator-and-stats-fix.sh [repo-sti]   (default: .)
set -euo pipefail
REPO="${1:-.}"
cd "$REPO"
for f in src/agents/RiskAgent.js src/agents/riskAgentInstance.js 16_railway-backend-phase42.js; do
  [ -f "$f" ] || { echo "FEIL: mangler $f (kjør fra repo-roten, etter script 06)"; exit 1; }
done

# 1) Koordinator (oppgavekø, ruting til agenter, checker)
cat > src/agents/coordinator.js <<'JS'
const crypto = require("crypto");
const { getRiskAgent } = require("./riskAgentInstance");

const tasks = new Map();

// Hver agenttype får en handler. Nye agenter (regnskap, m.fl.) registreres her.
const handlers = {
  risk: (payload) => getRiskAgent().assessTransaction(payload),
};

// Checker: verifiserer at agentens svar faktisk er brukbart.
function check(type, result) {
  const problems = [];
  if (!result || typeof result !== "object") {
    problems.push("tomt svar");
  } else if (type === "risk") {
    if (!Number.isFinite(result.riskScore) || result.riskScore < 0 || result.riskScore > 100) problems.push("riskScore mangler eller er ugyldig");
    if (!["low", "medium", "high"].includes(result.riskLevel)) problems.push("riskLevel ugyldig");
    if (typeof result.recommendation !== "string") problems.push("recommendation mangler");
  }
  return { ok: problems.length === 0, problems };
}

async function run(task) {
  task.status = "running";
  const handler = handlers[task.type];
  if (!handler) {
    task.status = "failed";
    task.error = `ukjent agenttype: ${task.type}`;
    return;
  }
  try {
    task.result = await handler(task.payload);
    task.check = check(task.type, task.result);
    task.status = task.check.ok ? "done" : "needs_review";
  } catch (err) {
    task.status = "failed";
    task.error = err.message;
  }
  task.finishedAt = new Date().toISOString();
}

function submit(type, payload) {
  const task = {
    id: crypto.randomUUID(),
    type,
    status: "queued",
    createdAt: new Date().toISOString(),
    payload,
    result: null,
    check: null,
    error: null,
  };
  tasks.set(task.id, task);
  run(task); // kjører i bakgrunnen
  return task;
}

function list() {
  return [...tasks.values()].slice(-100).reverse();
}

function get(id) {
  return tasks.get(id) || null;
}

module.exports = { submit, list, get, check, agentTypes: () => Object.keys(handlers) };
JS

# 2) Ruter for koordinator
cat > src/routes/coordinatorRoutes.js <<'JS'
const coordinator = require("../agents/coordinator");

function setupCoordinatorRoutes(app) {
  app.get("/api/coordinator/agents", (req, res) => {
    res.json({ success: true, data: coordinator.agentTypes() });
  });

  app.get("/api/coordinator/tasks", (req, res) => {
    res.json({ success: true, data: coordinator.list() });
  });

  app.get("/api/coordinator/tasks/:id", (req, res) => {
    const task = coordinator.get(req.params.id);
    if (!task) return res.status(404).json({ success: false, error: "Ikke funnet" });
    res.json({ success: true, data: task });
  });

  app.post("/api/coordinator/tasks", (req, res) => {
    const { type, payload } = req.body || {};
    if (!type || !payload || typeof payload !== "object") {
      return res.status(400).json({ success: false, error: "Krever type og payload (objekt)" });
    }
    if (!coordinator.agentTypes().includes(type)) {
      return res.status(400).json({ success: false, error: `Ukjent agenttype: ${type}` });
    }
    const task = coordinator.submit(type, payload);
    res.status(202).json({ success: true, data: task });
  });
}

module.exports = { setupCoordinatorRoutes };
JS

# 3) Patch: timestamp-normalisering, entrypoint-kobling (idempotent)
python3 - <<'PY'
import sys, pathlib

def patch(path, old, new):
    p = pathlib.Path(path)
    src = p.read_text()
    if new in src:
        print(f"allerede patchet: {path}")
        return
    if old not in src:
        sys.exit(f"FEIL: fant ikke forventet tekst i {path}: {old[:70]!r}")
    p.write_text(src.replace(old, new, 1))
    print(f"patchet {path}")

patch(
    "src/agents/RiskAgent.js",
    "  async assessTransaction(transaction) {\n    const { id, amount, merchant, category, timestamp = Date.now(), userId } = transaction;",
    "  async assessTransaction(rawTransaction) {\n    const transaction = { ...rawTransaction, timestamp: typeof rawTransaction.timestamp === \"number\" ? rawTransaction.timestamp : (Date.parse(rawTransaction.timestamp) || Date.now()) };\n    const { id, amount, merchant, category, timestamp, userId } = transaction;",
)

patch(
    "16_railway-backend-phase42.js",
    "setupRiskRoutes(app);",
    "setupRiskRoutes(app);\nconst { setupCoordinatorRoutes } = require(\"./src/routes/coordinatorRoutes\");\nsetupCoordinatorRoutes(app);",
)
PY

for f in src/agents/coordinator.js src/routes/coordinatorRoutes.js src/agents/RiskAgent.js 16_railway-backend-phase42.js; do
  node --check "$f"
done
echo "OK: syntaks i orden"
echo "Neste: git add -A src scripts 16_railway-backend-phase42.js, commit, push master og main."
