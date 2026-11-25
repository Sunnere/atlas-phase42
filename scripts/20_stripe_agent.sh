#!/usr/bin/env bash
# 20_stripe_agent.sh — kobler Stripe-oppsummering inn i ATLAS-koordinatoren (type "stripe") og morgenoppdateringen.
# Kjør fra repo-roten:  bash scripts/20_stripe_agent.sh
set -euo pipefail

if [ ! -f "16_railway-backend-phase42.js" ] || [ ! -d "src/agents" ]; then
  echo "FEIL: kjør fra repo-roten." >&2
  exit 1
fi
if [ ! -f "src/agents/briefing.js" ]; then
  echo "FEIL: src/agents/briefing.js finnes ikke. Kjør 19_morning_briefing.sh først." >&2
  exit 1
fi

mkdir -p src/agents/handlers
cat > src/agents/handlers/stripeAgent.js <<'ROY_EOF_STRIPE_HANDLER'
// Stripe-agent: oppsummerer betalinger siste døgn. Ingen Stripe-kall her.
// Dataene leveres i payload fra en planlagt jobb (Stripe-connector):
//   charges:  [{ id, amount, currency, status, created, refunded, disputed, failure_message? }]
//   refunds:  [{ id, amount, currency, created }]
//   disputes: [{ id, amount, currency, status, created, reason? }]
//   balance:  { available: [{amount,currency}], pending: [{amount,currency}] }   (valgfri)
// Beløp er i minste enhet (øre), som hos Stripe. Ingen penger flyttes eller endres herfra.

const FAILED_ALERT_SHARE = 0.2; // over 20 % mislykkede betalinger flagges
const MIN_CHARGES_FOR_SHARE = 5;

function sumByCurrency(items) {
  const out = {};
  for (const it of items) {
    const cur = String(it.currency || "nok").toUpperCase();
    out[cur] = (out[cur] || 0) + Number(it.amount || 0);
  }
  return out;
}

function analyseStripe(p) {
  if (!p || typeof p !== "object") throw new Error("payload mangler");
  const charges = Array.isArray(p.charges) ? p.charges : [];
  const refunds = Array.isArray(p.refunds) ? p.refunds : [];
  const disputes = Array.isArray(p.disputes) ? p.disputes : [];

  const succeeded = charges.filter((c) => c.status === "succeeded");
  const failed = charges.filter((c) => c.status === "failed");
  const openDisputes = disputes.filter((d) => d.status && !/won|lost|closed/i.test(d.status));

  const flags = [];
  if (openDisputes.length > 0) flags.push({ typ: "dispute", tekst: `${openDisputes.length} åpen(e) dispute(r) i Stripe` });
  if (charges.length >= MIN_CHARGES_FOR_SHARE && failed.length / charges.length > FAILED_ALERT_SHARE) {
    flags.push({ typ: "feil", tekst: `${failed.length} av ${charges.length} betalinger feilet (${Math.round((100 * failed.length) / charges.length)} %)` });
  }

  return {
    counts: {
      charges: charges.length,
      succeeded: succeeded.length,
      failed: failed.length,
      refunds: refunds.length,
      disputes: disputes.length,
      openDisputes: openDisputes.length,
    },
    volume: sumByCurrency(succeeded),
    refunded: sumByCurrency(refunds),
    balance: p.balance || null,
    flags,
    failedSamples: failed.slice(0, 5).map((c) => ({ id: c.id, amount: c.amount, currency: c.currency, message: c.failure_message || null })),
    note: "Oppsummering og flagg. Ingen refusjon, ingen endring i Stripe.",
  };
}

function checkStripe(result) {
  const problems = [];
  if (!result.counts || !Number.isFinite(result.counts.charges)) problems.push("counts mangler");
  if (!result.volume || typeof result.volume !== "object") problems.push("volume mangler");
  return problems;
}

module.exports = { analyseStripe, checkStripe };
ROY_EOF_STRIPE_HANDLER
cat > src/agents/coordinator.js <<'ROY_EOF_COORD'
const crypto = require("crypto");
const { getRiskAgent } = require("./riskAgentInstance");
const { assessRegnskap } = require("./handlers/regnskapAgent");
const { analyseFund } = require("./handlers/fundMonitorAgent");
const { assessGmail } = require("./handlers/gmailAgent");
const { assessCalendar } = require("./handlers/calendarAgent");
const { analyseGold, checkGold } = require("./handlers/goldAgent");
const { analyseStripe, checkStripe } = require("./handlers/stripeAgent");
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
  stripe: (payload) => analyseStripe(payload),
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
  } else if (type === "stripe") {
    problems.push(...checkStripe(result));
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
cat > src/agents/briefing.js <<'ROY_EOF_BRIEF'
// Morgenoppdatering ("oppdater meg"): setter sammen siste resultat fra alle agenter
// til én oversikt. Ren funksjon over latest() — ingen eksterne kall.
// Make-annonsetall er med som plassholder til Zernio-post-ID-ene er lagret.

function fmtTime(iso) {
  if (!iso) return "";
  return new Date(iso).toLocaleString("nb-NO", { timeZone: "Europe/Oslo", dateStyle: "short", timeStyle: "short" });
}

function buildBriefing(latest, now = new Date()) {
  const gmail = latest.gmail && latest.gmail.result ? latest.gmail.result : null;
  const calendar = latest.calendar && latest.calendar.result ? latest.calendar.result : null;
  const gold = latest.gold && latest.gold.result ? latest.gold.result : null;
  const stripe = latest.stripe && latest.stripe.result ? latest.stripe.result : null;

  const todo = [];
  if (gmail) {
    for (const m of gmail.haster) todo.push({ typ: "haster", tekst: `${m.subject} (fra ${m.from})` });
    for (const m of gmail.partner) todo.push({ typ: "partner", tekst: `${m.subject} (fra ${m.from})` });
  }
  if (stripe) {
    for (const f of stripe.flags) todo.push({ typ: "stripe", tekst: f.tekst });
  }
  if (calendar) {
    for (const c of calendar.conflicts) todo.push({ typ: "kalender", tekst: `Overlapp: ${c.a} / ${c.b}` });
  }

  const sections = {
    gull: gold
      ? { pris: gold.price, endringProsent: gold.percentChange, tidspunkt: gold.datetime, kilde: gold.source, sjekket: latest.gold.finishedAt }
      : null,
    epost: gmail
      ? { counts: gmail.counts, haster: gmail.haster, partner: gmail.partner, info: gmail.info, sistOppdatert: latest.gmail.finishedAt }
      : null,
    kalender: calendar
      ? { counts: calendar.counts, neste48t: calendar.upcoming, konflikter: calendar.conflicts, sistOppdatert: latest.calendar.finishedAt }
      : null,
    stripe: stripe
      ? { counts: stripe.counts, volume: stripe.volume, refunded: stripe.refunded, flags: stripe.flags, sistOppdatert: latest.stripe.finishedAt }
      : null,
    makeAnnonser: null, // kobles inn når Zernio-post-ID-er lagres i datastore
  };

  const mangler = ["gmail", "calendar", "gold", "stripe"].filter((t) => !latest[t]);

  return {
    generatedAt: now.toISOString(),
    dagensGjoremal: todo,
    seksjoner: sections,
    mangler,
    tekst: renderText(sections, todo, mangler, now),
  };
}

function renderText(s, todo, mangler, now) {
  const lines = [];
  lines.push(`☀️ Oppdatering ${fmtTime(now.toISOString())}`);
  lines.push("");

  lines.push("✅ Dagens gjøremål");
  if (todo.length === 0) lines.push("  Ingenting akutt registrert.");
  for (const t of todo) lines.push(`  • [${t.typ}] ${t.tekst}`);
  lines.push("");

  lines.push("📧 E-post");
  if (!s.epost) lines.push("  Ingen data ennå (morgenjobben kl. 07:03 henter den).");
  else {
    lines.push(`  ${s.epost.counts.total} uleste siste døgn: ${s.epost.counts.haster} å være obs på, ${s.epost.counts.partner} partner, ${s.epost.counts.info} info`);
    for (const m of s.epost.haster) lines.push(`  ⚠️ ${m.subject} (${m.from})`);
  }
  lines.push("");

  lines.push("📅 Neste 48 timer");
  if (!s.kalender) lines.push("  Ingen data ennå.");
  else if (s.kalender.neste48t.length === 0) lines.push("  Ingen hendelser.");
  else for (const c of s.kalender.neste48t) lines.push(`  • ${fmtTime(c.start)}: ${c.summary}`);
  lines.push("");

  lines.push("🥇 Gull (XAU/USD)");
  if (!s.gull) lines.push("  Ingen data ennå.");
  else lines.push(`  ${s.gull.pris} USD (${s.gull.endringProsent >= 0 ? "+" : ""}${Number(s.gull.endringProsent).toFixed(2)} %) — sjekket ${fmtTime(s.gull.sjekket)}`);
  lines.push("");

  lines.push("💳 Stripe (siste døgn)");
  if (!s.stripe) lines.push("  Ingen data ennå.");
  else {
    const vol = Object.entries(s.stripe.volume).map(([c, v]) => `${(v / 100).toFixed(2)} ${c}`).join(", ") || "0";
    lines.push(`  ${s.stripe.counts.succeeded} vellykkede (${vol}), ${s.stripe.counts.failed} feilet, ${s.stripe.counts.refunds} refusjoner, ${s.stripe.counts.openDisputes} åpne disputer`);
  }
  lines.push("");

  lines.push("📣 Make-annonser (visninger, likes, kommentarer)");
  lines.push("  Ikke koblet ennå. Venter på at Zernio-post-ID-er lagres.");

  if (mangler.length) {
    lines.push("");
    lines.push(`ℹ️ Ingen resultat ennå fra: ${mangler.join(", ")}`);
  }
  return lines.join("\n");
}

module.exports = { buildBriefing };
ROY_EOF_BRIEF

node --check src/agents/handlers/stripeAgent.js
node --check src/agents/coordinator.js
node --check src/agents/briefing.js
echo "OK: 20_stripe_agent installert."
echo "Neste: git add src/agents && git commit -m "Stripe-agent i koordinator og morgenoppdatering" && git push origin master"
