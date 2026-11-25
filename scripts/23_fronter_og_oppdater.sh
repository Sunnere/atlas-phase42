#!/usr/bin/env bash
# ATLAS Matrix: «Fronter»-agent (Make + Railway-status for alle prosjekter) og «Oppdater»-knapp.
#  - agent «fronter»: tar imot status per scenario/tjeneste fra planlagt Claude-jobb (Make + Railway),
#    grupperer per front (BonusShop, Bonusvarsel, ATLAS Rapport, ATLAS Matrix, …) og flagger feil/pause
#  - jarvis.html: ny node «Fronter» (klikk = liste), og «Oppdater»-knapp øverst: kjører gull + rapport på nytt,
#    laster siden og viser hele morgenoppdateringen i et vindu
#  - briefing: nye seksjoner Fronter og ATLAS Rapport
# Kjør fra roten av atlas-phase42:  bash scripts/23_fronter_og_oppdater.sh
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f src/agents/coordinator.js ] && [ -f src/agents/briefing.js ] && [ -f public/dashboard/jarvis.html ] || { echo "Feil: kjør fra roten av atlas-phase42"; exit 1; }

cat > src/agents/handlers/fronterAgent.js <<'JS_EOF'
// Fronter-agent: samler driftsstatus fra Make-scenarioer og Railway-tjenester, gruppert per front.
// Ingen eksterne kall her. Dataene leveres i payload fra en planlagt jobb:
//   items: [{ front, name, kind: "make"|"railway", status: "ok"|"warn"|"error"|"paused", detail?, next? }]
const STATUSES = ["ok", "warn", "error", "paused"];

function emptyCounts() {
  return { ok: 0, warn: 0, error: 0, paused: 0, total: 0 };
}

function assessFronter(p) {
  if (!p || typeof p !== "object") throw new Error("payload mangler");
  if (!Array.isArray(p.items)) throw new Error("items må være en liste");
  const counts = emptyCounts();
  const byFront = {};
  const items = [];
  for (const it of p.items) {
    if (!it || typeof it.name !== "string" || !STATUSES.includes(it.status)) {
      throw new Error("hvert element trenger name og status (ok/warn/error/paused): " + JSON.stringify(it));
    }
    const front = String(it.front || "Annet");
    const kind = it.kind === "railway" ? "railway" : "make";
    const item = { front, name: it.name, kind, status: it.status, detail: it.detail ? String(it.detail).slice(0, 200) : "", next: it.next || null };
    items.push(item);
    counts[it.status]++; counts.total++;
    byFront[front] = byFront[front] || emptyCounts();
    byFront[front][it.status]++; byFront[front].total++;
  }
  const attention = items.filter((i) => i.status === "error" || i.status === "warn");
  return { counts, byFront, items, attention, source: "Make + Railway" };
}

function checkFronter(result) {
  const problems = [];
  if (!result || !result.counts || !Number.isFinite(result.counts.total)) return ["counts mangler"];
  if (result.counts.total === 0) problems.push("ingen elementer");
  if (result.counts.error > 0) problems.push(result.counts.error + " med feil: " + result.attention.filter((i) => i.status === "error").map((i) => i.name).join(", "));
  return problems;
}

module.exports = { assessFronter, checkFronter };
JS_EOF
echo "fronterAgent.js skrevet"

python3 - <<'PY'
import pathlib

def patch(path, pairs, marker):
    p = pathlib.Path(path); s = p.read_text()
    if marker in s:
        print(path + ': allerede oppdatert'); return
    for old, new in pairs:
        assert s.count(old) == 1, path + ' fant ikke: ' + old[:60]
        s = s.replace(old, new)
    p.write_text(s); print(path + ': oppdatert')

patch('src/agents/coordinator.js', [
  ('const { assessRapport, checkRapport } = require("./handlers/rapportAgent");', 'const { assessRapport, checkRapport } = require("./handlers/rapportAgent");\nconst { assessFronter, checkFronter } = require("./handlers/fronterAgent");'),
  ('  rapport: (payload) => assessRapport(payload),\n', '  rapport: (payload) => assessRapport(payload),\n  fronter: (payload) => assessFronter(payload),\n'),
  ('  } else if (type === "gold") {', '  } else if (type === "fronter") {\n    problems.push(...checkFronter(result));\n  } else if (type === "gold") {'),
], 'assessFronter')

patch('src/agents/briefing.js', [
  ('  const stripe = latest.stripe && latest.stripe.result ? latest.stripe.result : null;\n',
   '  const stripe = latest.stripe && latest.stripe.result ? latest.stripe.result : null;\n  const fronter = latest.fronter && latest.fronter.result ? latest.fronter.result : null;\n  const rapport = latest.rapport && latest.rapport.result ? latest.rapport.result : null;\n'),
  ('    makeAnnonser: null,', '    fronter: fronter ? { counts: fronter.counts, byFront: fronter.byFront, attention: fronter.attention, sistOppdatert: latest.fronter.finishedAt } : null,\n    rapport: rapport ? { total: rapport.total, instances: rapport.instances, sistOppdatert: latest.rapport.finishedAt } : null,\n    makeAnnonser: null,'),
  ('  if (calendar) {\n    for (const c of calendar.conflicts)', '  if (fronter) {\n    for (const a of fronter.attention) todo.push({ typ: a.status === "error" ? "feil" : "obs", tekst: `${a.front}: ${a.name}${a.detail ? " – " + a.detail : ""}` });\n  }\n  if (calendar) {\n    for (const c of calendar.conflicts)'),
  ('["gmail", "calendar", "gold", "stripe"].filter', '["gmail", "calendar", "gold", "stripe", "fronter", "rapport"].filter'),
  ('  lines.push("📣 Make-annonser', '''  lines.push("🧭 Fronter (Make + Railway)");
  if (!s.fronter) lines.push("  Ingen data ennå.");
  else {
    const c = s.fronter.counts;
    lines.push(`  ${c.ok} i orden, ${c.warn} obs, ${c.error} feil, ${c.paused} pauset av ${c.total}`);
    for (const [f, v] of Object.entries(s.fronter.byFront)) lines.push(`  • ${f}: ${v.ok}/${v.total} i orden${v.error ? `, ${v.error} feil` : ""}`);
  }
  lines.push("");

  lines.push("📝 ATLAS Rapport");
  if (!s.rapport) lines.push("  Ingen data ennå.");
  else lines.push("  " + s.rapport.instances.map((i) => `${i.name}: ${i.ok ? i.total + " saker" : "ikke nådd"}`).join(" · "));
  lines.push("");

  lines.push("📣 Make-annonser'''),
], 'fronter')

patch('public/dashboard/jarvis.html', [
  ('stripe: "Stripe", rapport: "ATLAS Rapport"};', 'stripe: "Stripe", rapport: "ATLAS Rapport", fronter: "Fronter"};'),
  ('const SLOTS = 8;', 'const SLOTS = 12;\nconst MIN_SLOTS = 8;\nlet LAST_TASKS = [];'),
  ('    if(nodes.length >= SLOTS) break;', '    if(nodes.length >= MIN_SLOTS) break;'),
  ('  if(t.status === "failed") return "Feil: "', '''  if(t.type === "fronter" && t.result && t.result.counts && t.status !== "failed"){
    const c = t.result.counts;
    return c.ok + " i orden" + (c.error ? " · " + c.error + " feil" : "") + (c.warn ? " · " + c.warn + " obs" : "");
  }
  if(t.status === "failed") return "Feil: "'''),
  ('    if(a.type === "rapport"){', '    if(a.type === "fronter"){ el.style.cursor = "pointer"; el.title = "Vis fronter"; el.addEventListener("click", openFronter); }\n    if(a.type === "rapport"){'),
  ('  render(buildNodes(types, tasks));', '  LAST_TASKS = tasks;\n  render(buildNodes(types, tasks));'),
  ('<header><span>ATLAS · koordinator</span><span id="clock"></span></header>', '<header><span>ATLAS · koordinator</span><span><button id="upd" type="button">Oppdater</button> <span id="clock"></span></span></header>'),
  ('#rp[hidden]{display:none}', '''#rp[hidden]{display:none}
#upd{background:rgba(56,214,255,.12);color:#9be7ff;border:1px solid rgba(56,214,255,.45);border-radius:8px;padding:6px 14px;cursor:pointer;font:inherit;margin-right:14px}
#upd:disabled{opacity:.5;cursor:wait}
.rpbox pre{white-space:pre-wrap;font:13px/1.5 ui-monospace,Menlo,monospace;margin:0}
.st-ok{color:#7ee2a8}.st-warn{color:#ffd166}.st-error{color:#ff8a8a}.st-paused{color:#9fb3c8}'''),
  ('// Koderegn i bakgrunnen', '''// Fronter: Make- og Railway-status per front, fra siste «fronter»-oppgave.
function openFronter(){
  const box = document.getElementById("rp"), body = document.getElementById("rpbody");
  document.querySelector("#rp h2").textContent = "Fronter";
  box.hidden = false;
  const t = LAST_TASKS.find(x => x.type === "fronter" && x.result && x.result.items);
  if(!t){ body.textContent = "Ingen statusdata ennå. Den planlagte jobben henter den hver morgen."; return; }
  const LBL = {ok: "i orden", warn: "obs", error: "feil", paused: "pauset"};
  const rows = t.result.items.slice().sort((a,b) => String(a.front).localeCompare(String(b.front))).map(i =>
    `<tr><td>${esc(i.front)}</td><td>${esc(i.kind === "railway" ? "Railway" : "Make")}</td><td>${esc(i.name)}</td><td class="st-${esc(i.status)}">${LBL[i.status]}</td><td>${esc(i.detail || i.next || "")}</td></tr>`).join("");
  body.innerHTML = `<p>Oppdatert ${esc(new Date(t.finishedAt || t.createdAt).toLocaleString("no-NO",{dateStyle:"short",timeStyle:"short"}))}</p><table><tr><th>Front</th><th>Type</th><th>Navn</th><th>Status</th><th>Merknad</th></tr>${rows}</table>`;
}

// Oppdater: kjør gull + rapport på nytt, last siden, vis morgenoppdateringen.
async function doUpdate(){
  const btn = document.getElementById("upd"), box = document.getElementById("rp"), body = document.getElementById("rpbody");
  btn.disabled = true; btn.textContent = "Oppdaterer …";
  const k = lsGet();
  const h = {"content-type": "application/json"}; if(k) h["x-atlas-key"] = k;
  try{
    await Promise.all(["gold", "rapport"].map(type => fetch(BASE + "/api/coordinator/tasks", {method: "POST", headers: h, body: JSON.stringify({type, payload: {}})}).catch(() => null)));
    await new Promise(r => setTimeout(r, 3500));
    await load();
    document.querySelector("#rp h2").textContent = "Oppdatering";
    const r = await fetch(BASE + "/api/coordinator/briefing", {headers: k ? {"x-atlas-key": k} : {}, cache: "no-store"});
    if(r.status === 401){ body.innerHTML = keyForm("Skriv inn koden"); const go = document.getElementById("rpgo"); if(go) go.onclick = () => { lsSet(document.getElementById("rpkey").value.trim()); doUpdate(); }; }
    else { const j = await r.json(); body.innerHTML = `<pre>${esc(j.data.tekst)}</pre>`; }
    box.hidden = false;
  }catch(e){ body.textContent = "Kunne ikke hente oppdateringen."; box.hidden = false; }
  btn.disabled = false; btn.textContent = "Oppdater";
}
document.getElementById("upd").addEventListener("click", doUpdate);

// Koderegn i bakgrunnen'''),
], 'doUpdate')
PY

cat > scripts/test_fronter.js <<'JS_EOF'
const assert = require("assert");
const { assessFronter, checkFronter } = require("../src/agents/handlers/fronterAgent");
const { buildBriefing } = require("../src/agents/briefing");
const coordinator = require("../src/agents/coordinator");
(async () => {
  const r = assessFronter({ items: [
    { front: "BonusShop", name: "Autopost", kind: "make", status: "ok", next: "2026-11-26T11:15:00Z" },
    { front: "BonusShop", name: "Pinterest", kind: "make", status: "error", detail: "1 feil siste døgn" },
    { front: "ATLAS Rapport", name: "atlas-rapport-oyer", kind: "railway", status: "ok" },
    { front: "Bonusvarsel", name: "Gammelt scenario", kind: "make", status: "paused" },
  ]});
  assert.deepStrictEqual(r.counts, { ok: 2, warn: 0, error: 1, paused: 1, total: 4 });
  assert.strictEqual(r.byFront.BonusShop.error, 1);
  assert.ok(checkFronter(r)[0].includes("Pinterest"));
  assert.throws(() => assessFronter({ items: [{ name: "x", status: "rar" }] }));
  assert.ok(coordinator.agentTypes().includes("fronter"));
  const t = coordinator.submit("fronter", { items: [{ front: "A", name: "n", kind: "railway", status: "ok" }] });
  await new Promise((res) => setTimeout(res, 300));
  assert.strictEqual(coordinator.get(t.id).status, "done");
  const b = buildBriefing({ fronter: { result: r, finishedAt: new Date().toISOString() } });
  assert.ok(b.tekst.includes("Fronter (Make + Railway)") && b.tekst.includes("BonusShop: 1/2"));
  assert.ok(b.dagensGjoremal.some((x) => x.typ === "feil" && x.tekst.includes("Pinterest")));
  console.log("fronter OK"); process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
JS_EOF
node scripts/test_fronter.js && node scripts/test_rapport.js && node scripts/test_laas.js
node -e 'const h=require("fs").readFileSync("public/dashboard/jarvis.html","utf8");new Function(h.match(/<script>([\s\S]*)<\/script>/)[1]);console.log("jarvis.html kompilerer")'
echo "✅ Script 23 ferdig"
