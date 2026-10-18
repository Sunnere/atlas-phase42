#!/usr/bin/env bash
# 18: Koordinator-timer (gull hvert 15. min), lagring av siste resultat per agent,
# og GET /api/coordinator/summary som gir "oppdater meg"-oversikten.
# Kjør fra roten av atlas-phase42:  bash scripts/18_coordinator_schedule.sh
set -euo pipefail

if [ ! -f 16_railway-backend-phase42.js ] || [ ! -f src/agents/coordinator.js ]; then
  echo "FEIL: stå i roten av atlas-phase42 (fant ikke 16_railway-backend-phase42.js eller src/agents/coordinator.js)."
  exit 1
fi

mkdir -p src/agents src/routes data

cat > src/agents/store.js << 'ROY_EOF_STORE'
// Lagrer siste ferdige resultat per agenttype til disk, slik at det overlever restart.
// På Railway uten volum nullstilles data/ ved deploy. Sett COORDINATOR_STORE til en volum-sti for å beholde den.
const fs = require("fs");
const path = require("path");

const FILE = process.env.COORDINATOR_STORE || path.join(__dirname, "..", "..", "data", "coordinator-latest.json");
let latest = {};

function load() {
  try {
    latest = JSON.parse(fs.readFileSync(FILE, "utf8"));
  } catch (_) {
    latest = {};
  }
}

function save() {
  try {
    fs.mkdirSync(path.dirname(FILE), { recursive: true });
    fs.writeFileSync(FILE, JSON.stringify(latest, null, 2));
  } catch (err) {
    console.error("[coordinator] kunne ikke lagre resultat:", err.message);
  }
}

function record(task) {
  latest[task.type] = {
    taskId: task.id,
    status: task.status,
    finishedAt: task.finishedAt,
    check: task.check,
    result: task.result,
  };
  save();
}

function getLatest() {
  return latest;
}

load();
module.exports = { record, getLatest, FILE };
ROY_EOF_STORE

cat > src/agents/scheduler.js << 'ROY_EOF_SCHED'
// Timer for koordinatoren. Kjører bare agenter som henter sine data selv (i dag: gull).
// Gmail, Kalender, Regnskap og Fond får data fra planlagte oppgaver i Claude og sendes via POST /api/coordinator/tasks.

const GOLD_EVERY_MINUTES = 15;

function startScheduler(submit, { intervalMs = 60 * 1000 } = {}) {
  let lastSlot = null;

  function tick(now = new Date()) {
    const slot = Math.floor(now.getTime() / 60000);
    if (now.getUTCMinutes() % GOLD_EVERY_MINUTES === 0 && slot !== lastSlot) {
      lastSlot = slot;
      submit("gold", {});
    }
  }

  submit("gold", {}); // kjør én gang ved oppstart
  const timer = setInterval(() => tick(), intervalMs);
  if (timer.unref) timer.unref();
  return { tick, stop: () => clearInterval(timer) };
}

module.exports = { startScheduler, GOLD_EVERY_MINUTES };
ROY_EOF_SCHED

cat > src/agents/coordinator.js << 'ROY_EOF_COORD'
const crypto = require("crypto");
const { getRiskAgent } = require("./riskAgentInstance");
const { assessRegnskap } = require("./handlers/regnskapAgent");
const { analyseFund } = require("./handlers/fundMonitorAgent");
const { assessGmail } = require("./handlers/gmailAgent");
const { assessCalendar } = require("./handlers/calendarAgent");
const { analyseGold, checkGold } = require("./handlers/goldAgent");
const store = require("./store");

const tasks = new Map();

// Hver agenttype får en handler. Nye agenter registreres her.
const handlers = {
  risk: (payload) => getRiskAgent().assessTransaction(payload),
  regnskap: (payload) => assessRegnskap(payload),
  fund: (payload) => analyseFund(payload),
  gmail: (payload) => assessGmail(payload),
  calendar: (payload) => assessCalendar(payload),
  gold: (payload) => analyseGold(payload),
};

const RATINGS = ["GRØNN", "ORANSJE", "RØD", "GRÅ (for kort historikk)"];

// Checker: verifiserer at agentens svar faktisk er brukbart.
function check(type, result) {
  const problems = [];
  if (!result || typeof result !== "object") {
    problems.push("tomt svar");
  } else if (type === "risk") {
    if (!Number.isFinite(result.riskScore) || result.riskScore < 0 || result.riskScore > 100) problems.push("riskScore mangler eller er ugyldig");
    if (!["low", "medium", "high"].includes(result.riskLevel)) problems.push("riskLevel ugyldig");
    if (typeof result.recommendation !== "string") problems.push("recommendation mangler");
  } else if (type === "regnskap") {
    if (!["income", "expense"].includes(result.type)) problems.push("type ugyldig");
    if (typeof result.category !== "string" || !result.category) problems.push("kategori mangler");
  } else if (type === "fund") {
    if (!RATINGS.includes(result.rating)) problems.push("rating ugyldig");
    if (!Number.isFinite(result.ann)) problems.push("annualisert avkastning ugyldig");
  } else if (type === "gmail") {
    if (!result.counts || !Number.isFinite(result.counts.total)) problems.push("counts mangler");
  } else if (type === "calendar") {
    if (!Array.isArray(result.upcoming)) problems.push("upcoming mangler");
  } else if (type === "gold") {
    problems.push(...checkGold(result));
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
  if (task.status === "done" || task.status === "needs_review") store.record(task);
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

module.exports = { submit, list, get, check, latest: () => store.getLatest(), agentTypes: () => Object.keys(handlers) };
ROY_EOF_COORD

cat > src/routes/coordinatorRoutes.js << 'ROY_EOF_ROUTES'
const coordinator = require("../agents/coordinator");

function setupCoordinatorRoutes(app) {
  app.get("/api/coordinator/agents", (req, res) => {
    res.json({ success: true, data: coordinator.agentTypes() });
  });

  // Siste ferdige resultat per agent, også etter restart. Brukes til "oppdater meg"-oversikten.
  app.get("/api/coordinator/summary", (req, res) => {
    res.json({ success: true, data: coordinator.latest() });
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
ROY_EOF_ROUTES

python3 - << 'PY'
import sys
p = "16_railway-backend-phase42.js"
src = open(p, encoding="utf-8").read()
anchor = "setupCoordinatorRoutes(app);"
if src.count(anchor) != 1:
    print("FEIL: fant ikke entydig 'setupCoordinatorRoutes(app);' i 16_railway-backend-phase42.js"); sys.exit(1)
if "startScheduler" in src:
    print("Timer er allerede koblet inn i 16_railway-backend-phase42.js, hopper over.")
else:
    block = anchor + '\n// Timer for koordinatoren (gull hvert 15. min). Slå av med COORDINATOR_SCHEDULER=off.\nif (process.env.COORDINATOR_SCHEDULER !== "off") {\n  require("./src/agents/scheduler").startScheduler(require("./src/agents/coordinator").submit);\n}'
    open(p, "w", encoding="utf-8").write(src.replace(anchor, block, 1))
    print("Koblet timer inn i 16_railway-backend-phase42.js")
PY

node --check src/agents/store.js
node --check src/agents/scheduler.js
node --check src/agents/coordinator.js
node --check src/routes/coordinatorRoutes.js
node --check 16_railway-backend-phase42.js
echo "OK: koordinator-timer, lagring og /api/coordinator/summary er på plass."
echo "Neste steg: git add src/agents src/routes data 16_railway-backend-phase42.js scripts/18_coordinator_schedule.sh && git commit -m 'Koordinator: timer, lagring og sammendrag' && git push origin master"
