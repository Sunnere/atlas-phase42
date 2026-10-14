#!/usr/bin/env bash
# Registrerer to nye agenter i ATLAS-koordinatoren (atlas-phase42):
#   regnskap : kategoriserer en inntekt/utgift og flagger ukjente poster for gjennomgang
#   fund     : beregner nøkkeltall og score for et fond (samme regler som scripts/fund_score.py)
# Skriver:
#   src/agents/handlers/regnskapAgent.js
#   src/agents/handlers/fundMonitorAgent.js
#   src/agents/coordinator.js          (erstatter filen; sjekker først at den er den kjente versjonen)
#   scripts/test_agents.js              (selvtest, kjøres til slutt)
#   public/dashboard/jarvis.html        (oppdaterer visningsnavn, hvis filen finnes)
# Kjør med: bash scripts/14_register_regnskap_fund_agents.sh   (fra roten av atlas-phase42)
set -euo pipefail

EXPECTED_SHA="bd259b836ef10b034ccf61b8ec797c238a874d9beb5e7ce12dd749e736c55579"
COORD="src/agents/coordinator.js"

if [ ! -f "$COORD" ]; then
  echo "Fant ikke $COORD. Kjør fra roten av atlas-phase42." >&2
  exit 1
fi

if grep -q "regnskapAgent" "$COORD"; then
  echo "coordinator.js har allerede regnskap-agenten, hopper over endring av koordinator."
else
  SHA=$(shasum -a 256 "$COORD" | awk '{print $1}')
  if [ "$SHA" != "$EXPECTED_SHA" ]; then
    echo "coordinator.js er endret siden den ble lest ($SHA). Stopper for ikke å overskrive noe." >&2
    exit 1
  fi
fi

mkdir -p src/agents/handlers scripts

cat > src/agents/handlers/regnskapAgent.js << 'REGNSKAP_EOF'
// Regnskapsagent: regelbasert kategorisering av én postering.
// Ingen eksterne kall. Ukjente poster flagges for gjennomgang i stedet for å gjettes.

const TYPES = ["income", "expense"];

function assessRegnskap(p) {
  const problems = [];
  if (!p || typeof p !== "object") throw new Error("payload mangler");
  if (!TYPES.includes(p.type)) problems.push("type må være income eller expense");
  if (!Number.isFinite(p.amount) || p.amount <= 0) problems.push("beløp må være et positivt tall");
  if (typeof p.date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(p.date)) problems.push("dato må være YYYY-MM-DD");
  if (problems.length) throw new Error(problems.join("; "));

  const src = String(p.source || "").toLowerCase();
  let category;
  if (p.type === "income") {
    if (src.includes("airbnb")) category = "Utleieinntekt (kortidsutleie)";
    else if (src.includes("stripe")) category = "Salgsinntekt (Stripe)";
    else if (src.includes("adtraction")) category = "Provisjonsinntekt (affiliate)";
    else category = "Annen inntekt";
  } else {
    category = "Driftsutgift (ukategorisert)";
  }

  const notes = [];
  if (p.type === "income") {
    notes.push("Momsgrensen (50 000 kr) gjelder akkumulert omsetning per år. Følges opp samlet, ikke per postering.");
  }

  return {
    type: p.type,
    amount: p.amount,
    date: p.date,
    category,
    needsReview: category.startsWith("Annen") || category.includes("ukategorisert"),
    notes,
  };
}

module.exports = { assessRegnskap };
REGNSKAP_EOF

cat > src/agents/handlers/fundMonitorAgent.js << 'FUND_EOF'
// Fond-monitor: nøkkeltall fra månedlige sluttkurser. Samme regler som scripts/fund_score.py.
// Kun kursavkastning, uten utbytte. Score er et sorteringsverktøy, ikke et kjøpsråd.

const MIN_MONTHS = 36;
const GREEN_MIN_ANN = 6.0;
const GREEN_MAX_DD = -30.0;
const GREEN_MAX_VOL = 20.0;

function rating(m) {
  if (m.months < MIN_MONTHS) return "GRÅ (for kort historikk)";
  if (m.ann < 0) return "RØD";
  if (m.ann >= GREEN_MIN_ANN && m.mdd > GREEN_MAX_DD && m.vol < GREEN_MAX_VOL) return "GRØNN";
  return "ORANSJE";
}

function analyseFund(p) {
  if (!p || typeof p.name !== "string" || !p.name) throw new Error("name mangler");
  if (!Array.isArray(p.closes) || p.closes.length < 2) throw new Error("closes må ha minst to månedlige sluttkurser");

  const rows = p.closes
    .map((r) => {
      if (!r || !/^\d{4}-\d{2}$/.test(r.date) || !(Number(r.close) > 0)) {
        throw new Error("ugyldig rad: " + JSON.stringify(r));
      }
      return [r.date, Number(r.close)];
    })
    .sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0));

  const closes = rows.map((r) => r[1]);
  const months = closes.length - 1;
  const years = months / 12;
  const last = closes[closes.length - 1];
  const total = (last / closes[0] - 1) * 100;
  const ann = (Math.pow(last / closes[0], 1 / years) - 1) * 100;

  const rets = [];
  for (let i = 1; i < closes.length; i++) rets.push(closes[i] / closes[i - 1] - 1);
  const mean = rets.reduce((a, b) => a + b, 0) / rets.length;
  let vol = 0;
  if (rets.length > 1) {
    const variance = rets.reduce((s, r) => s + Math.pow(r - mean, 2), 0) / (rets.length - 1);
    vol = Math.sqrt(variance) * Math.sqrt(12) * 100;
  }

  let peak = closes[0];
  let mdd = 0;
  for (const c of closes) {
    if (c > peak) peak = c;
    const dd = (c / peak - 1) * 100;
    if (dd < mdd) mdd = dd;
  }

  const m = { months, ann, vol, mdd };
  return {
    name: p.name,
    rating: rating(m),
    start: rows[0][0],
    end: rows[rows.length - 1][0],
    months,
    total,
    ann,
    vol,
    mdd,
    note: "Kun kursavkastning, uten utbytte. Sorteringsverktøy, ikke kjøpsråd.",
  };
}

module.exports = { analyseFund, rating };
FUND_EOF

cat > "$COORD" << 'COORD_EOF'
const crypto = require("crypto");
const { getRiskAgent } = require("./riskAgentInstance");
const { assessRegnskap } = require("./handlers/regnskapAgent");
const { analyseFund } = require("./handlers/fundMonitorAgent");

const tasks = new Map();

// Hver agenttype får en handler. Nye agenter registreres her.
const handlers = {
  risk: (payload) => getRiskAgent().assessTransaction(payload),
  regnskap: (payload) => assessRegnskap(payload),
  fund: (payload) => analyseFund(payload),
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
COORD_EOF

cat > scripts/test_agents.js << 'TEST_EOF'
// Selvtest for koordinatoren. Kjøres med: node scripts/test_agents.js
const assert = require("assert");
const coordinator = require("../src/agents/coordinator");

function waitFor(task) {
  return new Promise((resolve, reject) => {
    const t0 = Date.now();
    const timer = setInterval(() => {
      const cur = coordinator.get(task.id);
      if (cur.status !== "queued" && cur.status !== "running") {
        clearInterval(timer);
        resolve(cur);
      } else if (Date.now() - t0 > 2000) {
        clearInterval(timer);
        reject(new Error("tidsavbrudd for " + task.type));
      }
    }, 10);
  });
}

function monthly(start, closes) {
  return closes.map((close, i) => {
    const d = new Date(Date.UTC(start[0], start[1] - 1 + i, 1));
    return { date: `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`, close };
  });
}

(async () => {
  assert.deepStrictEqual(coordinator.agentTypes(), ["risk", "regnskap", "fund"]);

  const okReg = await waitFor(coordinator.submit("regnskap", { type: "income", amount: 3272.5, date: "2026-02-27", source: "Airbnb" }));
  assert.strictEqual(okReg.status, "done");
  assert.strictEqual(okReg.result.category, "Utleieinntekt (kortidsutleie)");
  assert.strictEqual(okReg.result.needsReview, false);

  const unknownReg = await waitFor(coordinator.submit("regnskap", { type: "expense", amount: 120, date: "2026-03-01", source: "ukjent" }));
  assert.strictEqual(unknownReg.status, "done");
  assert.strictEqual(unknownReg.result.needsReview, true);

  const badReg = await waitFor(coordinator.submit("regnskap", { type: "income", amount: -5, date: "2026-03-01" }));
  assert.strictEqual(badReg.status, "failed");
  assert.match(badReg.error, /beløp/);

  const rising = await waitFor(coordinator.submit("fund", { name: "Test-fond", closes: monthly([2020, 1], Array.from({ length: 40 }, (_, i) => 100 * Math.pow(1.01, i))) }));
  assert.strictEqual(rising.status, "done");
  assert.strictEqual(rising.result.rating, "GRØNN");

  const short = await waitFor(coordinator.submit("fund", { name: "Kort", closes: monthly([2025, 1], [100, 101, 102, 103]) }));
  assert.strictEqual(short.result.rating, "GRÅ (for kort historikk)");

  const falling = await waitFor(coordinator.submit("fund", { name: "Falt", closes: monthly([2020, 1], Array.from({ length: 40 }, (_, i) => 100 * Math.pow(0.99, i))) }));
  assert.strictEqual(falling.result.rating, "RØD");

  const badFund = await waitFor(coordinator.submit("fund", { name: "Feil", closes: [{ date: "2026-1", close: 1 }, { date: "2026-02", close: 2 }] }));
  assert.strictEqual(badFund.status, "failed");

  console.log("Alle selvtester bestått (" + 8 + " sjekker).");
})().catch((e) => {
  console.error("SELVTEST FEILET:", e.message);
  process.exit(1);
});
TEST_EOF

if [ -f public/dashboard/jarvis.html ]; then
  sed -i.bak 's/const DISPLAY = {risk: "Risk-agent"};/const DISPLAY = {risk: "Risk-agent", regnskap: "Regnskap", fund: "Fond-monitor"};/' public/dashboard/jarvis.html
  rm -f public/dashboard/jarvis.html.bak
  echo "Oppdaterte visningsnavn i public/dashboard/jarvis.html"
fi

node scripts/test_agents.js
echo "Ferdig: regnskap- og fond-agenten er registrert i koordinatoren."
