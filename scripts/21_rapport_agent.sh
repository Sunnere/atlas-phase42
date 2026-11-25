#!/usr/bin/env bash
# Kobler ATLAS Rapport (Øyer, Lillehammer, privat osv.) inn i ATLAS Matrix.
#  - ny agent «rapport» i koordinatoren: henter antall saker per instans (bare tall, ingen innhold) hvert 5. minutt
#  - GET /api/rapport/saker: saksliste, krever header x-atlas-key = ATLAS_DASH_KEY (siden er ellers offentlig)
#  - jarvis.html: ATLAS Rapport-node med tall, og trykk på den for å se sakene
# Kjør fra roten av atlas-phase42:  bash scripts/21_rapport_agent.sh
# Miljøvariabler på Railway (atlas-tjenesten): RAPPORT_INSTANCES (JSON) og ATLAS_DASH_KEY
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -f src/agents/coordinator.js ] || [ ! -f src/routes/coordinatorRoutes.js ] || [ ! -f public/dashboard/jarvis.html ]; then
  echo "Feil: kjør fra roten av atlas-phase42"; exit 1
fi

cat > src/agents/handlers/rapportAgent.js <<'JS_EOF'
// Rapport-agent: teller saker i ATLAS Rapport-instansene (Øyer, Lillehammer, privat osv.).
// Resultatet havner i /api/coordinator/tasks som er åpent, så det inneholder BARE tall og tidspunkt.
// Sakslisten med titler hentes fra /api/rapport/saker, som krever ATLAS_DASH_KEY.
// Instanser settes i RAPPORT_INSTANCES (JSON): [{"name":"Øyer","url":"https://…","token":"…"}]

const TIMEOUT_MS = 10000;
const CACHE_MS = 60 * 1000;
let cache = { at: 0, instances: [], cases: [] };

function instances() {
  try {
    const a = JSON.parse(process.env.RAPPORT_INSTANCES || "[]");
    return Array.isArray(a) ? a.filter((i) => i && i.name && /^https?:\/\//.test(i.url || "") && i.token) : [];
  } catch (_) {
    return [];
  }
}

async function fetchOne(inst, fetchFn) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    const res = await fetchFn(String(inst.url).replace(/\/$/, "") + "/api/meetings", {
      headers: { Authorization: "Bearer " + inst.token },
      signal: ctrl.signal,
    });
    if (!res.ok) return { name: inst.name, ok: false, error: "HTTP " + res.status, cases: [] };
    const list = await res.json();
    if (!Array.isArray(list)) return { name: inst.name, ok: false, error: "uventet svar", cases: [] };
    return { name: inst.name, ok: true, cases: list };
  } catch (err) {
    return { name: inst.name, ok: false, error: err.name === "AbortError" ? "tidsavbrudd" : "ikke nådd", cases: [] };
  } finally {
    clearTimeout(timer);
  }
}

async function collect(deps = {}) {
  const fetchFn = deps.fetch || fetch;
  const list = instances();
  if (!list.length) throw new Error("RAPPORT_INSTANCES mangler i miljøet");
  const results = await Promise.all(list.map((i) => fetchOne(i, fetchFn)));
  const summary = results.map((r) => {
    const kinds = {};
    for (const c of r.cases) kinds[c.kind || "meeting"] = (kinds[c.kind || "meeting"] || 0) + 1;
    const last = r.cases.map((c) => c.createdAt).filter(Boolean).sort().pop() || null;
    return { name: r.name, ok: r.ok, total: r.cases.length, kinds, last, error: r.error || null };
  });
  const cases = [];
  for (const r of results) {
    for (const c of r.cases) cases.push({ instance: r.name, id: c.id, title: c.title, kind: c.kind || "meeting", status: c.status, createdAt: c.createdAt });
  }
  cases.sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
  cache = { at: Date.now(), instances: summary, cases };
  return summary;
}

// Tall til koordinatoren. Ingen titler, ingen tokens.
async function assessRapport(_payload, deps = {}) {
  const summary = await collect(deps);
  return {
    instances: summary,
    total: summary.reduce((s, i) => s + i.total, 0),
    instancesOk: summary.filter((i) => i.ok).length,
    instancesTotal: summary.length,
    source: "ATLAS Rapport",
  };
}

function checkRapport(result) {
  const problems = [];
  if (!result || typeof result !== "object") return ["tomt svar"];
  if (!Array.isArray(result.instances)) problems.push("instances mangler");
  else if (result.instancesOk < result.instancesTotal) {
    const bad = result.instances.filter((i) => !i.ok).map((i) => i.name + " (" + i.error + ")");
    problems.push("ikke nådd: " + bad.join(", "));
  }
  return problems;
}

// For den beskyttede sakslisten. Bruker cache i 60 sekunder.
async function getCases(deps = {}) {
  if (Date.now() - cache.at > CACHE_MS) await collect(deps);
  return { at: new Date(cache.at).toISOString(), instances: cache.instances, cases: cache.cases };
}

module.exports = { assessRapport, checkRapport, getCases, instances };
JS_EOF
echo "rapportAgent.js skrevet"

python3 - <<'PY'
import pathlib

# ---------- coordinator.js ----------
p = pathlib.Path('src/agents/coordinator.js'); s = p.read_text()
if 'rapportAgent' not in s:
    old = 'const store = require("./store");'
    assert s.count(old) == 1, 'fant ikke store-require'
    s = s.replace(old, 'const { assessRapport, checkRapport } = require("./handlers/rapportAgent");\n' + old)
    old = '  stripe: (payload) => analyseStripe(payload),\n'
    assert s.count(old) == 1, 'fant ikke stripe-handler'
    s = s.replace(old, old + '  rapport: (payload) => assessRapport(payload),\n')
    old = '  } else if (type === "gold") {'
    assert s.count(old) == 1, 'fant ikke gold-sjekk'
    s = s.replace(old, '  } else if (type === "rapport") {\n    problems.push(...checkRapport(result));\n' + old)
    p.write_text(s); print('coordinator.js: rapport-agent registrert')
else: print('coordinator.js: allerede oppdatert')

# ---------- scheduler.js ----------
p = pathlib.Path('src/agents/scheduler.js'); s = p.read_text()
if 'RAPPORT_EVERY_MINUTES' not in s:
    old = 'const GOLD_EVERY_MINUTES = 15;'
    assert s.count(old) == 1
    s = s.replace(old, old + '\nconst RAPPORT_EVERY_MINUTES = 5;')
    old = '  let lastSlot = null;\n'
    assert s.count(old) == 1
    s = s.replace(old, old + '  let lastRapportSlot = null;\n')
    old = '  submit("gold", {}); // kjør én gang ved oppstart'
    assert s.count(old) == 1
    s = s.replace(old, old + '\n  if (process.env.RAPPORT_INSTANCES) submit("rapport", {});')
    old = '      submit("gold", {});\n    }\n'
    assert s.count(old) == 1, 'fant ikke gold-blokk i tick'
    s = s.replace(old, old + '    if (process.env.RAPPORT_INSTANCES && now.getUTCMinutes() % RAPPORT_EVERY_MINUTES === 0 && slot !== lastRapportSlot) {\n      lastRapportSlot = slot;\n      submit("rapport", {});\n    }\n')
    s = s.replace('module.exports = { startScheduler, GOLD_EVERY_MINUTES };', 'module.exports = { startScheduler, GOLD_EVERY_MINUTES, RAPPORT_EVERY_MINUTES };')
    p.write_text(s); print('scheduler.js: rapport hvert 5. minutt')
else: print('scheduler.js: allerede oppdatert')

# ---------- coordinatorRoutes.js ----------
p = pathlib.Path('src/routes/coordinatorRoutes.js'); s = p.read_text()
if '/api/rapport/saker' not in s:
    old = '  app.post("/api/coordinator/tasks", (req, res) => {'
    assert s.count(old) == 1
    new = '''  // Saksliste fra ATLAS Rapport. Siden er offentlig, så denne krever nøkkel i headeren x-atlas-key.
  app.get("/api/rapport/saker", async (req, res) => {
    const want = process.env.ATLAS_DASH_KEY;
    if (!want) return res.status(503).json({ success: false, error: "ATLAS_DASH_KEY er ikke satt på serveren" });
    const crypto = require("crypto");
    const got = Buffer.from(String(req.get("x-atlas-key") || ""));
    const exp = Buffer.from(want);
    if (got.length !== exp.length || !crypto.timingSafeEqual(got, exp)) {
      return res.status(401).json({ success: false, error: "Feil nøkkel" });
    }
    try {
      res.set("Cache-Control", "no-store");
      res.json({ success: true, data: await require("../agents/handlers/rapportAgent").getCases() });
    } catch (err) {
      res.status(502).json({ success: false, error: err.message });
    }
  });

'''
    s = s.replace(old, new + old)
    p.write_text(s); print('coordinatorRoutes.js: /api/rapport/saker')
else: print('coordinatorRoutes.js: allerede oppdatert')

# ---------- jarvis.html ----------
p = pathlib.Path('public/dashboard/jarvis.html'); s = p.read_text()
if 'openRapport' not in s:
    def rep(old, new, cnt=1):
        global s
        assert s.count(old) == cnt, 'fant ikke: ' + old[:60]
        s = s.replace(old, new)
    rep('gold: "Gull-agent"};', 'gold: "Gull-agent", stripe: "Stripe", rapport: "ATLAS Rapport"};')
    rep('"Stripe", "Kalender", "ATLAS Møte", "Adtraction"', '"Stripe", "Kalender", "Adtraction"')
    rep('function taskText(t){\n', '''function taskText(t){
  if(t.type === "rapport" && t.result && Array.isArray(t.result.instances) && t.status !== "failed"){
    return t.result.instances.map(i => i.name + " " + (i.ok ? i.total : "?")).join(" · ");
  }
''')
    rep('return {name, status: "", task: "Ingen oppgaver ennå", planned: false};', 'return {type, name, status: "", task: "Ingen oppgaver ennå", planned: false};')
    rep('return {name, status: TASK_STATE[latest.status] || "", task: taskText(latest), planned: false};', 'return {type, name, status: TASK_STATE[latest.status] || "", task: taskText(latest), planned: false};')
    rep('    stage.appendChild(el);\n  });\n}', '''    if(a.type === "rapport"){ el.style.cursor = "pointer"; el.title = "Vis saker"; el.addEventListener("click", openRapport); }
    stage.appendChild(el);
  });
}''')
    rep('<footer id="foot">', '''<div id="rp" hidden><div class="rpbox"><button id="rpx" aria-label="Lukk">×</button><h2>ATLAS Rapport</h2><div id="rpbody"></div></div></div>
<footer id="foot">''')
    rep('</style>', '''#rp{position:fixed;inset:0;background:rgba(3,7,14,.82);z-index:20;display:flex;align-items:center;justify-content:center;padding:16px}
#rp[hidden]{display:none}
.rpbox{position:relative;max-width:720px;width:100%;max-height:85vh;overflow:auto;background:#0a1220;border:1px solid rgba(56,214,255,.35);border-radius:14px;padding:18px;color:#e6f4ff}
.rpbox h2{margin:0 0 10px;font-size:18px}
#rpx{position:absolute;right:10px;top:8px;background:none;border:0;color:#9fb3c8;font-size:26px;cursor:pointer}
.rpbox table{width:100%;border-collapse:collapse;font-size:13px}
.rpbox td,.rpbox th{padding:6px 8px;border-bottom:1px solid rgba(255,255,255,.08);text-align:left;vertical-align:top}
.rpbox input{padding:10px;border-radius:8px;border:1px solid #345;background:#06101c;color:#e6f4ff;width:100%;box-sizing:border-box;margin:8px 0}
.rpbox button.go{padding:10px 16px;border-radius:8px;border:0;background:#38d6ff;color:#03070e;font-weight:600;cursor:pointer}
.rpbad{color:#ff8a8a}
</style>''')
    rep('// Koderegn i bakgrunnen', '''// ATLAS Rapport: saksliste bak nøkkel (siden er offentlig, så titler vises bare med riktig kode).
const KEYNAME = "atlas_dash_key";
function lsGet(){ try{ return localStorage.getItem(KEYNAME) || ""; }catch(e){ return ""; } }
function lsSet(v){ try{ localStorage.setItem(KEYNAME, v); }catch(e){} }
const KIND = {defect: "Feilmelding", inspection: "Inspeksjon", documents: "Dokumentsjekk", meeting: "Møte"};
function keyForm(msg){
  return (msg ? `<p class="rpbad">${esc(msg)}</p>` : "") + `<p>Skriv inn koden for ATLAS Matrix for å se sakene.</p><input id="rpkey" type="password" autocomplete="off" placeholder="Kode"><button class="go" id="rpgo">Vis saker</button>`;
}
async function openRapport(){
  const box = document.getElementById("rp"), body = document.getElementById("rpbody");
  box.hidden = false;
  const key = lsGet();
  const bindForm = () => { const go = document.getElementById("rpgo"); if(go) go.onclick = () => { lsSet(document.getElementById("rpkey").value.trim()); openRapport(); }; };
  if(!key){ body.innerHTML = keyForm(""); bindForm(); return; }
  body.textContent = "Henter …";
  try{
    const r = await fetch(BASE + "/api/rapport/saker", {headers: {"x-atlas-key": key}, cache: "no-store"});
    if(r.status === 401){ lsSet(""); body.innerHTML = keyForm("Feil kode"); bindForm(); return; }
    if(r.status === 503){ body.textContent = "Ikke satt opp: ATLAS_DASH_KEY mangler på serveren."; return; }
    const j = await r.json();
    if(!j.success){ body.innerHTML = `<p class="rpbad">${esc(j.error || "Feil")}</p>`; return; }
    const d = j.data;
    const head = d.instances.map(i => `${esc(i.name)}: ${i.ok ? i.total + " saker" : `<span class="rpbad">${esc(i.error)}</span>`}`).join(" · ");
    const rows = d.cases.slice(0, 100).map(c => `<tr><td>${esc(new Date(c.createdAt).toLocaleString("no-NO",{dateStyle:"short",timeStyle:"short"}))}</td><td>${esc(c.instance)}</td><td>${esc(KIND[c.kind] || c.kind)}</td><td>${esc(c.title || "")}</td><td>${esc(c.status || "")}</td></tr>`).join("");
    body.innerHTML = `<p>${head}</p>` + (rows ? `<table><tr><th>Tid</th><th>Kunde</th><th>Type</th><th>Tittel</th><th>Status</th></tr>${rows}</table>` : "<p>Ingen saker ennå.</p>");
  }catch(e){ body.textContent = "Kunne ikke hente sakene."; }
}
document.getElementById("rpx").onclick = () => { document.getElementById("rp").hidden = true; };
document.getElementById("rp").addEventListener("click", e => { if(e.target.id === "rp") e.target.hidden = true; });

// Koderegn i bakgrunnen''')
    p.write_text(s); print('jarvis.html: ATLAS Rapport-node og saksliste')
else: print('jarvis.html: allerede oppdatert')
PY

cat > scripts/test_rapport.js <<'JS_EOF'
// Selvtest for rapport-agenten. Kjøres med: node scripts/test_rapport.js
const assert = require("assert");
const http = require("http");
const express = require("express");

function fakeInstance(token, list) {
  return new Promise((resolve) => {
    const srv = http.createServer((req, res) => {
      if (req.url === "/api/meetings" && req.headers.authorization === "Bearer " + token) {
        res.setHeader("content-type", "application/json");
        return res.end(JSON.stringify(list));
      }
      res.statusCode = 401; res.end("{}");
    }).listen(0, () => resolve(srv));
  });
}

(async () => {
  const a = await fakeInstance("tok-a", [
    { id: "1", title: "Lekkasje bad Skogly", createdAt: "2026-11-20T10:00:00Z", status: "done", kind: "defect" },
    { id: "2", title: "Inspeksjon Furuly", createdAt: "2026-11-21T09:00:00Z", status: "done", kind: "inspection" },
  ]);
  const b = await fakeInstance("tok-b-riktig", []);
  process.env.RAPPORT_INSTANCES = JSON.stringify([
    { name: "Øyer", url: "http://127.0.0.1:" + a.address().port, token: "tok-a" },
    { name: "Lillehammer", url: "http://127.0.0.1:" + b.address().port, token: "feil-token" },
  ]);
  process.env.ATLAS_DASH_KEY = "hemmelig-nok-kode";

  const { assessRapport, checkRapport } = require("../src/agents/handlers/rapportAgent");
  const r = await assessRapport({});
  assert.strictEqual(r.total, 2);
  assert.strictEqual(r.instancesOk, 1);
  assert.strictEqual(r.instances[0].kinds.defect, 1);
  assert.strictEqual(r.instances[1].error, "HTTP 401");
  const text = JSON.stringify(r);
  assert.ok(!text.includes("Lekkasje") && !text.includes("tok-a") && !text.includes("feil-token"), "resultatet skal ikke ha titler eller tokens");
  assert.ok(checkRapport(r)[0].includes("Lillehammer"));
  assert.deepStrictEqual(checkRapport({ instances: [{ ok: true }], instancesOk: 1, instancesTotal: 1 }), []);

  // koordinatoren kjenner agenten og sjekken er koblet inn
  const coordinator = require("../src/agents/coordinator");
  assert.ok(coordinator.agentTypes().includes("rapport"));
  assert.strictEqual(coordinator.check("rapport", r).ok, false);

  // beskyttet saksliste
  const { setupCoordinatorRoutes } = require("../src/routes/coordinatorRoutes");
  const app = express(); setupCoordinatorRoutes(app);
  const web = await new Promise((res) => { const s = app.listen(0, () => res(s)); });
  const U = "http://127.0.0.1:" + web.address().port + "/api/rapport/saker";
  assert.strictEqual((await fetch(U)).status, 401);
  assert.strictEqual((await fetch(U, { headers: { "x-atlas-key": "feil" } })).status, 401);
  const ok = await fetch(U, { headers: { "x-atlas-key": "hemmelig-nok-kode" } });
  assert.strictEqual(ok.status, 200);
  const j = await ok.json();
  assert.strictEqual(j.data.cases.length, 2);
  assert.strictEqual(j.data.cases[0].title, "Inspeksjon Furuly");
  assert.ok(!JSON.stringify(j).includes("tok-a"));
  const open = await (await fetch(U.replace("rapport/saker", "coordinator/tasks"))).text();
  assert.ok(!open.includes("Lekkasje"), "åpne oppgaver skal ikke ha titler");
  delete process.env.ATLAS_DASH_KEY;
  assert.strictEqual((await fetch(U)).status, 503);

  [a, b, web].forEach((s) => s.close());
  console.log("rapport OK");
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
JS_EOF
echo "scripts/test_rapport.js skrevet"
node scripts/test_rapport.js
node -e 'const fs=require("fs");const h=fs.readFileSync("public/dashboard/jarvis.html","utf8");const m=h.match(/<script>([\s\S]*)<\/script>/);new Function(m[1]);console.log("jarvis.html: script kompilerer")'
echo "✅ Script 21 ferdig"
echo "Neste: sett på Railway (atlas-tjenesten) ATLAS_DASH_KEY og RAPPORT_INSTANCES, se meldingen fra Claude."
