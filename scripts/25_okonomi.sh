#!/usr/bin/env bash
# ATLAS Matrix: «Økonomi»-agent – inntekt hittil i år per kilde (Stripe, Airbnb, Adtraction …) og momsgrensen på 50 000 kr.
#  - agent «okonomi»: summerer per kilde, regner prosent av momsgrensen, flagger ved 70 % og 90 %
#  - jarvis.html: node «Økonomi» (klikk = tabell)
#  - briefing: ny seksjon
# Kjør fra roten av atlas-phase42:  bash scripts/25_okonomi.sh
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f src/agents/coordinator.js ] && [ -f src/agents/briefing.js ] && [ -f public/dashboard/jarvis.html ] || { echo "Feil: kjør fra roten av atlas-phase42"; exit 1; }

cat > src/agents/handlers/okonomiAgent.js <<'JS_EOF'
// Økonomi-agent: inntekt hittil i år per kilde, målt mot momsgrensen (50 000 kr omsetning per år).
// Ingen eksterne kall her. Dataene leveres av en planlagt jobb:
//   year: 2026
//   sources: [{ name, amountNok, count, status: "ok"|"mangler", note? }]   (beløp i hele kroner)
// Ingen bokføring og ingen råd; tallene er et varsel om hvor du er i forhold til grensen.
const VAT_LIMIT = 50000;

function assessOkonomi(p) {
  if (!p || typeof p !== "object") throw new Error("payload mangler");
  if (!Number.isInteger(p.year)) throw new Error("year må være et heltall");
  if (!Array.isArray(p.sources) || p.sources.length === 0) throw new Error("sources må være en liste med minst én kilde");
  const sources = p.sources.map((s) => {
    if (!s || typeof s.name !== "string" || !s.name) throw new Error("hver kilde trenger name");
    const status = s.status === "mangler" ? "mangler" : "ok";
    const amount = Number(s.amountNok || 0);
    if (!Number.isFinite(amount) || amount < 0) throw new Error(`${s.name}: amountNok må være et tall`);
    return { name: s.name, amountNok: Math.round(amount), count: Number(s.count || 0), status, note: s.note ? String(s.note).slice(0, 200) : "" };
  });
  const total = sources.reduce((a, s) => a + s.amountNok, 0);
  const percent = Math.round((total / VAT_LIMIT) * 1000) / 10;
  const flags = [];
  if (percent >= 90) flags.push({ typ: "moms", tekst: `Omsetning ${total} kr er ${percent} % av momsgrensen på ${VAT_LIMIT} kr. Sjekk registrering i Merverdiavgiftsregisteret.` });
  else if (percent >= 70) flags.push({ typ: "moms", tekst: `Omsetning ${total} kr er ${percent} % av momsgrensen på ${VAT_LIMIT} kr.` });
  const missing = sources.filter((s) => s.status === "mangler").map((s) => s.name);
  if (missing.length) flags.push({ typ: "mangler", tekst: "Mangler data fra: " + missing.join(", ") });
  return { year: p.year, sources, total, vatLimit: VAT_LIMIT, percent, flags, source: "Stripe + e-post" };
}

function checkOkonomi(result) {
  if (!result || !Number.isFinite(result.total) || !Array.isArray(result.sources)) return ["total mangler"];
  return [];
}

module.exports = { assessOkonomi, checkOkonomi, VAT_LIMIT };
JS_EOF
echo "okonomiAgent.js skrevet"

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
  ('const { assessSosial, checkSosial } = require("./handlers/sosialAgent");', 'const { assessSosial, checkSosial } = require("./handlers/sosialAgent");\nconst { assessOkonomi, checkOkonomi } = require("./handlers/okonomiAgent");'),
  ('  sosial: (payload) => assessSosial(payload),\n', '  sosial: (payload) => assessSosial(payload),\n  okonomi: (payload) => assessOkonomi(payload),\n'),
  ('  } else if (type === "sosial") {', '  } else if (type === "okonomi") {\n    problems.push(...checkOkonomi(result));\n  } else if (type === "sosial") {'),
], 'assessOkonomi')

patch('src/agents/briefing.js', [
  ('  const sosial = latest.sosial && latest.sosial.result ? latest.sosial.result : null;\n', '  const sosial = latest.sosial && latest.sosial.result ? latest.sosial.result : null;\n  const okonomi = latest.okonomi && latest.okonomi.result ? latest.okonomi.result : null;\n'),
  ('    makeAnnonser: null,', '    okonomi: okonomi ? { year: okonomi.year, total: okonomi.total, percent: okonomi.percent, vatLimit: okonomi.vatLimit, sources: okonomi.sources, flags: okonomi.flags, sistOppdatert: latest.okonomi.finishedAt } : null,\n    makeAnnonser: null,'),
  ('"rapport", "sosial"].filter', '"rapport", "sosial", "okonomi"].filter'),
  ('  if (calendar) {\n    for (const c of calendar.conflicts)', '  if (okonomi) {\n    for (const f of okonomi.flags.filter((x) => x.typ === "moms")) todo.push({ typ: "moms", tekst: f.tekst });\n  }\n  if (calendar) {\n    for (const c of calendar.conflicts)'),
  ('  lines.push("📱 Sosiale medier', '''  lines.push("💰 Økonomi (hittil i år)");
  if (!s.okonomi) lines.push("  Ingen data ennå.");
  else {
    lines.push(`  Omsetning ${s.okonomi.total} kr, ${s.okonomi.percent} % av momsgrensen (${s.okonomi.vatLimit} kr)`);
    for (const src of s.okonomi.sources) lines.push(`  • ${src.name}: ${src.status === "ok" ? src.amountNok + " kr (" + src.count + ")" : "mangler data"}`);
    for (const f of s.okonomi.flags.filter((x) => x.typ === "moms")) lines.push(`  ⚠️ ${f.tekst}`);
  }
  lines.push("");

  lines.push("📱 Sosiale medier'''),
], 'okonomi')

patch('public/dashboard/jarvis.html', [
  ('sosial: "Sosiale medier"};', 'sosial: "Sosiale medier", okonomi: "Økonomi"};'),
  ('  if(t.type === "sosial" && t.result && t.result.totals', '''  if(t.type === "okonomi" && t.result && t.result.sources && t.status !== "failed"){
    return t.result.total.toLocaleString("no-NO") + " kr · " + t.result.percent + " % av moms";
  }
  if(t.type === "sosial" && t.result && t.result.totals'''),
  ('    if(a.type === "sosial"){', '    if(a.type === "okonomi"){ el.style.cursor = "pointer"; el.title = "Vis økonomi"; el.addEventListener("click", openOkonomi); }\n    if(a.type === "sosial"){'),
  ('// Sosiale medier: ukentlige tall', '''// Økonomi: inntekt hittil i år per kilde og momsgrensen.
function openOkonomi(){
  const box = document.getElementById("rp"), body = document.getElementById("rpbody");
  document.querySelector("#rp h2").textContent = "Økonomi";
  box.hidden = false;
  const t = LAST_TASKS.find(x => x.type === "okonomi" && x.result && x.result.sources);
  if(!t){ body.textContent = "Ingen data ennå. Jobben kjører hver mandag morgen."; return; }
  const r = t.result, fmt = n => n.toLocaleString("no-NO") + " kr";
  const rows = r.sources.map(s => `<tr><td>${esc(s.name)}</td><td>${s.status === "ok" ? fmt(s.amountNok) : "–"}</td><td>${s.status === "ok" ? s.count : ""}</td><td class="${s.status === "ok" ? "st-ok" : "st-warn"}">${s.status === "ok" ? "ok" : "mangler"}</td><td>${esc(s.note || "")}</td></tr>`).join("");
  const flags = r.flags.map(f => `<p class="st-warn">⚠ ${esc(f.tekst)}</p>`).join("");
  body.innerHTML = `<p>${r.year}: <b>${fmt(r.total)}</b> = ${r.percent} % av momsgrensen (${fmt(r.vatLimit)})</p><table><tr><th>Kilde</th><th>Beløp</th><th>Antall</th><th>Status</th><th>Merknad</th></tr>${rows}</table>${flags}`;
}

// Sosiale medier: ukentlige tall'''),
], 'openOkonomi')
PY

cat > scripts/test_okonomi.js <<'JS_EOF'
const assert = require("assert");
const { assessOkonomi, checkOkonomi } = require("../src/agents/handlers/okonomiAgent");
const { buildBriefing } = require("../src/agents/briefing");
const coordinator = require("../src/agents/coordinator");
(async () => {
  const r = assessOkonomi({ year: 2026, sources: [
    { name: "Stripe", amountNok: 2920, count: 40 },
    { name: "Airbnb", status: "mangler", note: "ikke koblet" },
    { name: "Adtraction", amountNok: 1000.4, count: 3 },
  ]});
  assert.strictEqual(r.total, 3920);
  assert.strictEqual(r.percent, 7.8);
  assert.ok(r.flags.some((f) => f.typ === "mangler" && f.tekst.includes("Airbnb")));
  assert.ok(!r.flags.some((f) => f.typ === "moms"));
  const hot = assessOkonomi({ year: 2026, sources: [{ name: "A", amountNok: 36000 }] });
  assert.ok(hot.flags.some((f) => f.typ === "moms") && hot.percent === 72);
  assert.ok(assessOkonomi({ year: 2026, sources: [{ name: "A", amountNok: 46000 }] }).flags[0].tekst.includes("Merverdiavgiftsregisteret"));
  assert.deepStrictEqual(checkOkonomi(r), []);
  assert.throws(() => assessOkonomi({ year: "2026", sources: [{ name: "A" }] }));
  assert.throws(() => assessOkonomi({ year: 2026, sources: [] }));
  assert.ok(coordinator.agentTypes().includes("okonomi"));
  const t = coordinator.submit("okonomi", { year: 2026, sources: [{ name: "Stripe", amountNok: 10 }] });
  await new Promise((res) => setTimeout(res, 300));
  assert.strictEqual(coordinator.get(t.id).status, "done");
  const b = buildBriefing({ okonomi: { result: hot, finishedAt: new Date().toISOString() } });
  assert.ok(b.tekst.includes("Økonomi (hittil i år)") && b.dagensGjoremal.some((x) => x.typ === "moms"));
  console.log("okonomi OK"); process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
JS_EOF
for t in okonomi sosial fronter rapport laas; do node scripts/test_$t.js; done
node -e 'const h=require("fs").readFileSync("public/dashboard/jarvis.html","utf8");new Function(h.match(/<script>([\s\S]*)<\/script>/)[1]);console.log("jarvis.html kompilerer")'
echo "✅ Script 25 ferdig"
