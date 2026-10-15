#!/usr/bin/env bash
# Legger til gull-agent (XAU/USD spot fra Twelve Data) i koordinatoren.
# Kjør fra roten av atlas-phase42:  bash scripts/16_register_gold_agent.sh
# Krever miljøvariabel TWELVE_DATA_API_KEY på Railway for at agenten skal svare live.
set -euo pipefail

if [ ! -f src/agents/coordinator.js ] || [ ! -f src/agents/handlers/fundMonitorAgent.js ]; then
  echo "Feil: kjør fra roten av atlas-phase42 (fant ikke src/agents/coordinator.js)"; exit 1
fi

cat > src/agents/handlers/goldAgent.js << 'JS_EOF'
// Gull-agent: spotkurs XAU/USD (USD per troy unse) fra Twelve Data.
// Rapporterer kurs og døgnendring. Gir ingen kjøps- eller salgsråd.

const SYMBOL = "XAU/USD";
const ENDPOINT = "https://api.twelvedata.com/quote";

// deps gjør testing mulig uten nettverk: { fetch, apiKey }
async function analyseGold(_payload, deps = {}) {
  const fetchFn = deps.fetch || fetch;
  const apiKey = deps.apiKey || process.env.TWELVE_DATA_API_KEY;
  if (!apiKey) throw new Error("TWELVE_DATA_API_KEY mangler i miljøet");

  const url = `${ENDPOINT}?symbol=${encodeURIComponent(SYMBOL)}&apikey=${encodeURIComponent(apiKey)}`;
  const res = await fetchFn(url);
  const j = await res.json();
  if (!res.ok || j.status === "error") {
    throw new Error("Twelve Data: " + (j.message || `HTTP ${res.status}`));
  }

  const price = Number(j.close);
  if (!(price > 0)) throw new Error("ugyldig kurs fra Twelve Data");

  return {
    symbol: SYMBOL,
    name: j.name || "Gold Spot / US Dollar",
    price,
    previousClose: Number(j.previous_close),
    change: Number(j.change),
    percentChange: Number(j.percent_change),
    dayHigh: Number(j.high),
    dayLow: Number(j.low),
    datetime: j.datetime,
    isMarketOpen: j.is_market_open === true,
    source: "Twelve Data",
    note: "Spotkurs. Ikke et kjøps- eller salgsråd.",
  };
}

function checkGold(result) {
  const problems = [];
  if (!result || typeof result !== "object") return ["tomt svar"];
  if (!(Number.isFinite(result.price) && result.price > 0)) problems.push("kurs mangler eller er ugyldig");
  if (!Number.isFinite(result.percentChange)) problems.push("døgnendring mangler");
  return problems;
}

module.exports = { analyseGold, checkGold, SYMBOL };
JS_EOF

cat > src/agents/coordinator.js << 'JS_EOF'
const crypto = require("crypto");
const { getRiskAgent } = require("./riskAgentInstance");
const { assessRegnskap } = require("./handlers/regnskapAgent");
const { analyseFund } = require("./handlers/fundMonitorAgent");
const { assessGmail } = require("./handlers/gmailAgent");
const { assessCalendar } = require("./handlers/calendarAgent");
const { analyseGold, checkGold } = require("./handlers/goldAgent");

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
JS_EOF

cat > scripts/test_gold_agent.js << 'JS_EOF'
// Tester gull-agenten uten nettverk. Kjør: node scripts/test_gold_agent.js
const assert = require("assert");
const { analyseGold, checkGold } = require("../src/agents/handlers/goldAgent");
const { check, agentTypes } = require("../src/agents/coordinator");

const okBody = {
  symbol: "XAU/USD", name: "Gold Spot / US Dollar", close: "4137.7948",
  previous_close: "4101.65932", change: "36.13548", percent_change: "0.88099662",
  high: "4164.02226", low: "4096.84952", datetime: "2026-10-15", is_market_open: true,
};
const fakeFetch = (body, status = 200) => async () => ({ ok: status < 400, status, json: async () => body });

(async () => {
  const r = await analyseGold({}, { apiKey: "test", fetch: fakeFetch(okBody) });
  assert.strictEqual(r.price, 4137.7948);
  assert.strictEqual(r.percentChange, 0.88099662);
  assert.strictEqual(r.source, "Twelve Data");
  assert.deepStrictEqual(checkGold(r), []);

  await assert.rejects(analyseGold({}, { apiKey: "", fetch: fakeFetch(okBody) }), /TWELVE_DATA_API_KEY/);
  await assert.rejects(
    analyseGold({}, { apiKey: "test", fetch: fakeFetch({ status: "error", message: "run out of credits" }, 429) }),
    /run out of credits/
  );
  await assert.rejects(analyseGold({}, { apiKey: "test", fetch: fakeFetch({ close: "0" }) }), /ugyldig kurs/);

  assert.strictEqual(check("gold", r).ok, true);
  assert.strictEqual(check("gold", { price: -1, percentChange: 0 }).ok, false);
  assert.ok(agentTypes().includes("gold"));
  console.log("ALLE GULL-TESTER BESTÅTT");
})().catch((e) => { console.error("FEIL:", e.message); process.exit(1); });
JS_EOF

echo "Skrev gull-agent: src/agents/handlers/goldAgent.js, src/agents/coordinator.js, scripts/test_gold_agent.js"
echo "Kjør testen:  node scripts/test_gold_agent.js"
echo "Husk: sett TWELVE_DATA_API_KEY i Railway før live-bruk."
