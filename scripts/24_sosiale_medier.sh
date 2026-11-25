#!/usr/bin/env bash
# ATLAS Matrix: «Sosiale medier»-agent. Tar imot ukentlige tall fra Buffer (Facebook, TikTok, Threads …)
# og en kort anbefaling fra den planlagte jobben. Vises som egen node, og i «Oppdater»-vinduet.
#  - agent «sosial»: summerer per kanal, flagger lav rekkevidde og gjentatte poster
#  - jarvis.html: node «Sosiale medier» (klikk = tabell + anbefaling)
#  - briefing: ny seksjon
# Kjør fra roten av atlas-phase42:  bash scripts/24_sosiale_medier.sh
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f src/agents/coordinator.js ] && [ -f src/agents/briefing.js ] && [ -f public/dashboard/jarvis.html ] || { echo "Feil: kjør fra roten av atlas-phase42"; exit 1; }

cat > src/agents/handlers/sosialAgent.js <<'JS_EOF'
// Sosiale medier-agent. Ingen eksterne kall her. Dataene leveres av en planlagt ukentlig jobb (Buffer):
//   period: { from, to }  (YYYY-MM-DD)
//   channels: [{ name, service, posts, views, reach, reactions, comments, clicks, shares }]
//   repeatedTexts: antall poster som er gjentakelser av samme tekst (valgfri)
//   recommendation: kort anbefaling som tekst (valgfri, maks 800 tegn)
const NUM = ["posts", "views", "reach", "reactions", "comments", "clicks", "shares"];
const LOW_VIEWS_PER_POST = 5;

function assessSosial(p) {
  if (!p || typeof p !== "object") throw new Error("payload mangler");
  if (!Array.isArray(p.channels) || p.channels.length === 0) throw new Error("channels må være en liste med minst én kanal");
  const channels = p.channels.map((c) => {
    if (!c || typeof c.name !== "string" || !c.name) throw new Error("hver kanal trenger name");
    const out = { name: c.name, service: String(c.service || "") };
    for (const k of NUM) {
      const v = Number(c[k] || 0);
      if (!Number.isFinite(v) || v < 0) throw new Error(`${c.name}: ${k} må være et tall`);
      out[k] = v;
    }
    out.viewsPerPost = out.posts ? Math.round((out.views / out.posts) * 10) / 10 : 0;
    return out;
  });
  const totals = { posts: 0, views: 0, reach: 0, reactions: 0, comments: 0, clicks: 0, shares: 0 };
  for (const c of channels) for (const k of NUM) totals[k] += c[k];
  const flags = [];
  for (const c of channels) {
    if (c.posts >= 3 && c.viewsPerPost < LOW_VIEWS_PER_POST) flags.push({ typ: "rekkevidde", tekst: `${c.name}: ${c.viewsPerPost} visninger per post (${c.posts} poster)` });
  }
  const repeated = Number(p.repeatedTexts || 0);
  if (repeated >= 3) flags.push({ typ: "gjentakelse", tekst: `${repeated} poster er gjentakelser av samme tekst` });
  return {
    period: p.period && p.period.from && p.period.to ? { from: String(p.period.from), to: String(p.period.to) } : null,
    channels, totals, flags,
    recommendation: p.recommendation ? String(p.recommendation).slice(0, 800) : "",
    source: "Buffer",
  };
}

function checkSosial(result) {
  if (!result || !result.totals || !Array.isArray(result.channels)) return ["totals mangler"];
  return [];
}

module.exports = { assessSosial, checkSosial };
JS_EOF
echo "sosialAgent.js skrevet"

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
  ('const { assessFronter, checkFronter } = require("./handlers/fronterAgent");', 'const { assessFronter, checkFronter } = require("./handlers/fronterAgent");\nconst { assessSosial, checkSosial } = require("./handlers/sosialAgent");'),
  ('  fronter: (payload) => assessFronter(payload),\n', '  fronter: (payload) => assessFronter(payload),\n  sosial: (payload) => assessSosial(payload),\n'),
  ('  } else if (type === "fronter") {', '  } else if (type === "sosial") {\n    problems.push(...checkSosial(result));\n  } else if (type === "fronter") {'),
], 'assessSosial')

patch('src/agents/briefing.js', [
  ('  const rapport = latest.rapport && latest.rapport.result ? latest.rapport.result : null;\n', '  const rapport = latest.rapport && latest.rapport.result ? latest.rapport.result : null;\n  const sosial = latest.sosial && latest.sosial.result ? latest.sosial.result : null;\n'),
  ('    makeAnnonser: null,', '    sosial: sosial ? { period: sosial.period, totals: sosial.totals, channels: sosial.channels, flags: sosial.flags, recommendation: sosial.recommendation, sistOppdatert: latest.sosial.finishedAt } : null,\n    makeAnnonser: null,'),
  ('["gmail", "calendar", "gold", "stripe", "fronter", "rapport"].filter', '["gmail", "calendar", "gold", "stripe", "fronter", "rapport", "sosial"].filter'),
  ('  lines.push("📣 Make-annonser', '''  lines.push("📱 Sosiale medier (siste uke)");
  if (!s.sosial) lines.push("  Ingen data ennå (kommer hver mandag).");
  else {
    const t = s.sosial.totals;
    lines.push(`  ${t.posts} poster, ${t.views} visninger, ${t.reactions} likes, ${t.comments} kommentarer, ${t.clicks} klikk`);
    for (const c of s.sosial.channels) lines.push(`  • ${c.name}: ${c.posts} poster, ${c.views} visninger`);
    for (const f of s.sosial.flags) lines.push(`  ⚠️ ${f.tekst}`);
    if (s.sosial.recommendation) lines.push("  💡 " + s.sosial.recommendation);
  }
  lines.push("");

  lines.push("📣 Make-annonser'''),
], 'sosial')

patch('public/dashboard/jarvis.html', [
  ('fronter: "Fronter"};', 'fronter: "Fronter", sosial: "Sosiale medier"};'),
  ('  if(t.type === "fronter" && t.result && t.result.counts', '''  if(t.type === "sosial" && t.result && t.result.totals && t.status !== "failed"){
    const x = t.result.totals;
    return x.views + " visninger · " + x.posts + " poster";
  }
  if(t.type === "fronter" && t.result && t.result.counts'''),
  ('    if(a.type === "fronter"){', '    if(a.type === "sosial"){ el.style.cursor = "pointer"; el.title = "Vis sosiale medier"; el.addEventListener("click", openSosial); }\n    if(a.type === "fronter"){'),
  ('// Oppdater: kjør gull + rapport på nytt', '''// Sosiale medier: ukentlige tall fra Buffer og kort anbefaling.
function openSosial(){
  const box = document.getElementById("rp"), body = document.getElementById("rpbody");
  document.querySelector("#rp h2").textContent = "Sosiale medier";
  box.hidden = false;
  const t = LAST_TASKS.find(x => x.type === "sosial" && x.result && x.result.channels);
  if(!t){ body.textContent = "Ingen data ennå. Jobben kjører hver mandag morgen."; return; }
  const r = t.result;
  const rows = r.channels.map(c => `<tr><td>${esc(c.name)}</td><td>${c.posts}</td><td>${c.views}</td><td>${c.reach}</td><td>${c.reactions}</td><td>${c.comments}</td><td>${c.clicks}</td></tr>`).join("");
  const flags = r.flags.map(f => `<p class="st-warn">⚠ ${esc(f.tekst)}</p>`).join("");
  const per = r.period ? `${esc(r.period.from)} til ${esc(r.period.to)}` : "";
  body.innerHTML = `<p>${per}</p><table><tr><th>Kanal</th><th>Poster</th><th>Visninger</th><th>Nådd</th><th>Likes</th><th>Komm.</th><th>Klikk</th></tr>${rows}</table>${flags}` + (r.recommendation ? `<h3>Anbefaling</h3><p>${esc(r.recommendation)}</p>` : "");
}

// Oppdater: kjør gull + rapport på nytt'''),
], 'openSosial')
PY

cat > scripts/test_sosial.js <<'JS_EOF'
const assert = require("assert");
const { assessSosial, checkSosial } = require("../src/agents/handlers/sosialAgent");
const { buildBriefing } = require("../src/agents/briefing");
const coordinator = require("../src/agents/coordinator");
(async () => {
  const r = assessSosial({
    period: { from: "2026-11-17", to: "2026-11-24" },
    channels: [
      { name: "Facebook", service: "facebook", posts: 14, views: 29, reach: 12, reactions: 0, comments: 0, clicks: 0, shares: 0 },
      { name: "TikTok", service: "tiktok", posts: 14, views: 1, reach: 1 },
      { name: "Threads", service: "threads", posts: 12, views: 33, reactions: 2 },
    ],
    repeatedTexts: 20, recommendation: "Bytt ut gjentatte poster.",
  });
  assert.strictEqual(r.totals.posts, 40);
  assert.strictEqual(r.totals.views, 63);
  assert.strictEqual(r.flags.filter((f) => f.typ === "rekkevidde").length, 3);
  assert.ok(r.flags.some((f) => f.typ === "gjentakelse"));
  assert.deepStrictEqual(checkSosial(r), []);
  assert.throws(() => assessSosial({ channels: [] }));
  assert.throws(() => assessSosial({ channels: [{ name: "x", posts: -1 }] }));
  assert.ok(coordinator.agentTypes().includes("sosial"));
  const t = coordinator.submit("sosial", { channels: [{ name: "A", posts: 1, views: 2 }] });
  await new Promise((res) => setTimeout(res, 300));
  assert.strictEqual(coordinator.get(t.id).status, "done");
  const b = buildBriefing({ sosial: { result: r, finishedAt: new Date().toISOString() } });
  assert.ok(b.tekst.includes("Sosiale medier") && b.tekst.includes("40 poster, 63 visninger") && b.tekst.includes("Bytt ut"));
  console.log("sosial OK"); process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
JS_EOF
for t in sosial fronter rapport laas; do node scripts/test_$t.js; done
node -e 'const h=require("fs").readFileSync("public/dashboard/jarvis.html","utf8");new Function(h.match(/<script>([\s\S]*)<\/script>/)[1]);console.log("jarvis.html kompilerer")'
echo "✅ Script 24 ferdig"
