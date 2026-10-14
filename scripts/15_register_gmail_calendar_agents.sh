#!/usr/bin/env bash
# Registrerer to nye agenter i ATLAS-koordinatoren (atlas-phase42):
#   gmail    : grupperer uleste e-poster i Haster / Partner / Info (regelbasert)
#   calendar : finner kommende hendelser (48 t) og overlapp
# Serveren henter ikke e-post eller kalender selv. Dataene leveres i payload,
# slik at koordinatoren ikke trenger Google-tilgang. Kjør script 14 først.
# Skriver:
#   src/agents/handlers/gmailAgent.js
#   src/agents/handlers/calendarAgent.js
#   src/agents/coordinator.js          (sjekker først at den er versjonen fra script 14)
#   scripts/test_agents.js             (selvtest, kjøres til slutt)
#   public/dashboard/jarvis.html       (visningsnavn, hvis filen finnes)
# Kjør med: bash scripts/15_register_gmail_calendar_agents.sh   (fra roten av atlas-phase42)
set -euo pipefail

EXPECTED_SHA="1c8151bb36840f2eb7ca2d58c429a86668e97798deb8cc642f67054f82f18c19"
COORD="src/agents/coordinator.js"

if [ ! -f "$COORD" ]; then
  echo "Fant ikke $COORD. Kjør fra roten av atlas-phase42." >&2
  exit 1
fi

if grep -q "gmailAgent" "$COORD"; then
  echo "coordinator.js har allerede Gmail- og kalenderagentene, hopper over endring av koordinator."
else
  SHA=$(shasum -a 256 "$COORD" | awk '{print $1}')
  if [ "$SHA" != "$EXPECTED_SHA" ]; then
    echo "coordinator.js er ikke versjonen fra script 14 ($SHA). Stopper for ikke å overskrive noe." >&2
    exit 1
  fi
fi

mkdir -p src/agents/handlers scripts

cat > src/agents/handlers/gmailAgent.js << 'GMAIL_EOF'
// Gmail-agent: grupperer uleste e-poster. Ingen Google-kall her.
// Dataene leveres i payload: messages = [{ from, subject, date, snippet? }].
// Regler følger morgenbrief-spesifikasjonen: sikkerhet og penger først, partnere alltid med,
// alt annet som info. Ingen e-post sendes eller slettes herfra.

const SECURITY = /verify|verif|bekreft|sikkerhet|security|passord|password|innlogging|login|logg inn|påminnelse|purring|forfall|final notice|avslutt|kontoslett|account|konto|suspend|sperr|deaktivert|faktura|invoice|betaling|payment/i;
const PARTNER_FROM = /adtraction\.com/i;

function assessGmail(p) {
  if (!p || typeof p !== "object") throw new Error("payload mangler");
  if (!Array.isArray(p.messages)) throw new Error("messages må være en liste");

  const haster = [];
  const partner = [];
  const info = [];
  for (const m of p.messages) {
    if (!m || typeof m.from !== "string" || typeof m.subject !== "string") {
      throw new Error("hver melding trenger from og subject");
    }
    const text = `${m.subject} ${m.snippet || ""}`;
    const item = { from: m.from, subject: m.subject, date: m.date || null };
    if (PARTNER_FROM.test(m.from)) partner.push(item);
    else if (SECURITY.test(text)) haster.push(item);
    else info.push(item);
  }

  return {
    counts: { haster: haster.length, partner: partner.length, info: info.length, total: p.messages.length },
    haster,
    partner,
    info,
    note: "Sikkerhetsvarsler og penger flagges, aldri konklusjon. Roy avgjør selv.",
  };
}

module.exports = { assessGmail };
GMAIL_EOF

cat > src/agents/handlers/calendarAgent.js << 'CAL_EOF'
// Kalender-agent: kommende hendelser (48 t) og overlapp. Ingen Google-kall her.
// Dataene leveres i payload: events = [{ summary, start, end }] med ISO 8601-tider,
// og now (valgfri ISO-tid, standard er nå).

const HOURS_AHEAD = 48;

function assessCalendar(p) {
  if (!p || typeof p !== "object") throw new Error("payload mangler");
  if (!Array.isArray(p.events)) throw new Error("events må være en liste");

  const now = p.now ? Date.parse(p.now) : Date.now();
  if (!Number.isFinite(now)) throw new Error("now må være gyldig ISO-tid");

  const events = p.events.map((e) => {
    const start = Date.parse(e && e.start);
    const end = Date.parse(e && e.end);
    if (!Number.isFinite(start) || !Number.isFinite(end) || end < start) {
      throw new Error("hver hendelse trenger gyldig start og end: " + JSON.stringify(e));
    }
    return { summary: String(e.summary || "(uten tittel)"), start, end };
  });

  const horizon = now + HOURS_AHEAD * 3600 * 1000;
  const upcoming = events
    .filter((e) => e.end >= now && e.start <= horizon)
    .sort((a, b) => a.start - b.start)
    .map((e) => ({
      summary: e.summary,
      start: new Date(e.start).toISOString(),
      end: new Date(e.end).toISOString(),
      airbnb: /airbnb/i.test(e.summary),
    }));

  const conflicts = [];
  for (let i = 1; i < upcoming.length; i++) {
    const a = upcoming[i - 1];
    const b = upcoming[i];
    if (Date.parse(b.start) < Date.parse(a.end)) {
      conflicts.push({ a: a.summary, b: b.summary, start: b.start });
    }
  }

  return {
    windowHours: HOURS_AHEAD,
    upcoming,
    conflicts,
    counts: { upcoming: upcoming.length, conflicts: conflicts.length },
  };
}

module.exports = { assessCalendar };
CAL_EOF

cat > "$COORD" << 'COORD_EOF'
const crypto = require("crypto");
const { getRiskAgent } = require("./riskAgentInstance");
const { assessRegnskap } = require("./handlers/regnskapAgent");
const { analyseFund } = require("./handlers/fundMonitorAgent");
const { assessGmail } = require("./handlers/gmailAgent");
const { assessCalendar } = require("./handlers/calendarAgent");

const tasks = new Map();

// Hver agenttype får en handler. Nye agenter registreres her.
const handlers = {
  risk: (payload) => getRiskAgent().assessTransaction(payload),
  regnskap: (payload) => assessRegnskap(payload),
  fund: (payload) => analyseFund(payload),
  gmail: (payload) => assessGmail(payload),
  calendar: (payload) => assessCalendar(payload),
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
  assert.deepStrictEqual(coordinator.agentTypes(), ["risk", "regnskap", "fund", "gmail", "calendar"]);

  // regnskap (fra script 14)
  const okReg = await waitFor(coordinator.submit("regnskap", { type: "income", amount: 3272.5, date: "2026-02-27", source: "Airbnb" }));
  assert.strictEqual(okReg.status, "done");
  assert.strictEqual(okReg.result.category, "Utleieinntekt (kortidsutleie)");
  const badReg = await waitFor(coordinator.submit("regnskap", { type: "income", amount: -5, date: "2026-03-01" }));
  assert.strictEqual(badReg.status, "failed");

  // fund (fra script 14)
  const rising = await waitFor(coordinator.submit("fund", { name: "Test-fond", closes: monthly([2020, 1], Array.from({ length: 40 }, (_, i) => 100 * Math.pow(1.01, i))) }));
  assert.strictEqual(rising.result.rating, "GRØNN");
  const falling = await waitFor(coordinator.submit("fund", { name: "Falt", closes: monthly([2020, 1], Array.from({ length: 40 }, (_, i) => 100 * Math.pow(0.99, i))) }));
  assert.strictEqual(falling.result.rating, "RØD");

  // gmail
  const mail = await waitFor(coordinator.submit("gmail", {
    messages: [
      { from: "notice@adtraction.com", subject: "Godkjent: CS Megastore", date: "2026-10-13" },
      { from: "security@bank.no", subject: "Bekreft innlogging", date: "2026-10-13" },
      { from: "kontakt@curli.no", subject: "Ny kampanje", date: "2026-10-12" },
    ],
  }));
  assert.strictEqual(mail.status, "done");
  assert.strictEqual(mail.result.counts.partner, 1);
  assert.strictEqual(mail.result.counts.haster, 1);
  assert.strictEqual(mail.result.counts.info, 1);
  const badMail = await waitFor(coordinator.submit("gmail", { messages: [{ subject: "uten avsender" }] }));
  assert.strictEqual(badMail.status, "failed");

  // calendar
  const now = "2026-10-13T08:00:00Z";
  const cal = await waitFor(coordinator.submit("calendar", {
    now,
    events: [
      { summary: "Airbnb – gjest", start: "2026-10-14T13:00:00Z", end: "2026-10-14T18:00:00Z" },
      { summary: "Møte", start: "2026-10-14T16:00:00Z", end: "2026-10-14T17:00:00Z" },
      { summary: "Langt senere", start: "2026-11-01T10:00:00Z", end: "2026-11-01T11:00:00Z" },
    ],
  }));
  assert.strictEqual(cal.status, "done");
  assert.strictEqual(cal.result.counts.upcoming, 2);
  assert.strictEqual(cal.result.counts.conflicts, 1);
  assert.strictEqual(cal.result.upcoming[0].airbnb, true);
  const badCal = await waitFor(coordinator.submit("calendar", { events: [{ summary: "x", start: "ikke-dato", end: "2026-10-14T18:00:00Z" }] }));
  assert.strictEqual(badCal.status, "failed");

  console.log("Alle selvtester bestått (16 sjekker).");
})().catch((e) => {
  console.error("SELVTEST FEILET:", e.message);
  process.exit(1);
});
TEST_EOF

if [ -f public/dashboard/jarvis.html ]; then
  sed -i.bak '/const DISPLAY = /c\const DISPLAY = {risk: "Risk-agent", regnskap: "Regnskap", fund: "Fond-monitor", gmail: "Gmail", calendar: "Kalender"};' public/dashboard/jarvis.html
  rm -f public/dashboard/jarvis.html.bak
  echo "Oppdaterte visningsnavn i public/dashboard/jarvis.html"
fi

node scripts/test_agents.js
echo "Ferdig: Gmail- og kalenderagenten er registrert i koordinatoren."
