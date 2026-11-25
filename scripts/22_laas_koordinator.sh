#!/usr/bin/env bash
# Låser koordinator-API-et bak nøkkel, så Gmail/Stripe/rapport-data ikke ligger åpent.
#  - GET /api/coordinator/{summary,briefing,tasks,tasks/:id} krever header x-atlas-key = ATLAS_DASH_KEY
#    (er ATLAS_DASH_KEY ikke satt, er alt åpent som før, så ingenting går i stykker)
#  - /api/coordinator/agents forblir åpen (bare agentnavn)
#  - POST /api/coordinator/tasks krever nøkkel hvis ATLAS_POST_KEY er satt (x-atlas-key = ATLAS_POST_KEY eller ATLAS_DASH_KEY)
#  - jarvis.html sender koden og ber om den når serveren svarer 401
# Kjør fra roten av atlas-phase42:  bash scripts/22_laas_koordinator.sh
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f src/routes/coordinatorRoutes.js ] && [ -f public/dashboard/jarvis.html ] || { echo "Feil: kjør fra roten av atlas-phase42"; exit 1; }

python3 - <<'PY'
import pathlib
p = pathlib.Path('src/routes/coordinatorRoutes.js'); s = p.read_text()
if 'requireKey' not in s:
    def rep(old, new):
        global s
        assert s.count(old) == 1, 'fant ikke: ' + old[:50]
        s = s.replace(old, new)
    rep('const coordinator = require("../agents/coordinator");\n', '''const crypto = require("crypto");
const coordinator = require("../agents/coordinator");

function sameKey(got, want) {
  const a = Buffer.from(String(got || ""));
  const b = Buffer.from(String(want || ""));
  return a.length === b.length && a.length > 0 && crypto.timingSafeEqual(a, b);
}

// Krever x-atlas-key = ATLAS_DASH_KEY. Er nøkkelen ikke satt på serveren, slippes alt gjennom (som før).
function requireKey(req, res, next) {
  const want = process.env.ATLAS_DASH_KEY;
  if (!want) return next();
  if (sameKey(req.get("x-atlas-key"), want)) return next();
  res.status(401).json({ success: false, error: "Krever nøkkel" });
}

// POST: krever nøkkel bare hvis ATLAS_POST_KEY er satt, så planlagte oppgaver ikke slutter å virke uten varsel.
function requirePostKey(req, res, next) {
  const post = process.env.ATLAS_POST_KEY;
  if (!post) return next();
  const got = req.get("x-atlas-key");
  if (sameKey(got, post) || sameKey(got, process.env.ATLAS_DASH_KEY)) return next();
  res.status(401).json({ success: false, error: "Krever nøkkel" });
}
''')
    rep('app.get("/api/coordinator/summary", (req', 'app.get("/api/coordinator/summary", requireKey, (req')
    rep('app.get("/api/coordinator/briefing", (req', 'app.get("/api/coordinator/briefing", requireKey, (req')
    rep('app.get("/api/coordinator/tasks", (req', 'app.get("/api/coordinator/tasks", requireKey, (req')
    rep('app.get("/api/coordinator/tasks/:id", (req', 'app.get("/api/coordinator/tasks/:id", requireKey, (req')
    rep('app.post("/api/coordinator/tasks", (req', 'app.post("/api/coordinator/tasks", requirePostKey, (req')
    # gjenbruk i saker-endepunktet
    rep('''    const want = process.env.ATLAS_DASH_KEY;
    if (!want) return res.status(503).json({ success: false, error: "ATLAS_DASH_KEY er ikke satt på serveren" });
    const crypto = require("crypto");
    const got = Buffer.from(String(req.get("x-atlas-key") || ""));
    const exp = Buffer.from(want);
    if (got.length !== exp.length || !crypto.timingSafeEqual(got, exp)) {
      return res.status(401).json({ success: false, error: "Feil nøkkel" });
    }
''', '''    const want = process.env.ATLAS_DASH_KEY;
    if (!want) return res.status(503).json({ success: false, error: "ATLAS_DASH_KEY er ikke satt på serveren" });
    if (!sameKey(req.get("x-atlas-key"), want)) return res.status(401).json({ success: false, error: "Feil nøkkel" });
''')
    p.write_text(s); print('coordinatorRoutes.js låst')
else: print('coordinatorRoutes.js: allerede oppdatert')

p = pathlib.Path('public/dashboard/jarvis.html'); s = p.read_text()
if 'askKey' not in s:
    def rep(old, new):
        global s
        assert s.count(old) == 1, 'fant ikke: ' + old[:50]
        s = s.replace(old, new)
    rep('''  const r = await fetch(BASE + path, {cache: "no-store"});
  if(!r.ok) throw new Error(path + " " + r.status);''', '''  const k = lsGet();
  const r = await fetch(BASE + path, {cache: "no-store", headers: k ? {"x-atlas-key": k} : {}});
  if(!r.ok) throw new Error(path + " " + r.status);''')
    rep('''    try{ tasks = await getJson("/api/coordinator/tasks"); }catch(e){ note = "Oppgaver kunne ikke hentes"; }''',
        '''    try{ tasks = await getJson("/api/coordinator/tasks"); }
    catch(e){ note = / 401$/.test(e.message) ? "Låst · trykk her og skriv inn koden" : "Oppgaver kunne ikke hentes"; locked = / 401$/.test(e.message); }''')
    rep('let types, tasks = [], live = false, note = "";', 'let types, tasks = [], live = false, note = "", locked = false;')
    rep('''    ? (note || `Live fra koordinatoren''', '''    ? (note || `Live fra koordinatoren''')
    rep('''// ATLAS Rapport: saksliste bak nøkkel''', '''function askKey(){
  const v = prompt("Kode for ATLAS Matrix:");
  if(v){ lsSet(v.trim()); load(); }
}
document.getElementById("foot").addEventListener("click", () => { if(/Låst/.test(document.getElementById("foot").textContent)) askKey(); });

// ATLAS Rapport: saksliste bak nøkkel''')
    p.write_text(s); print('jarvis.html sender kode')
else: print('jarvis.html: allerede oppdatert')
PY

cat > scripts/test_laas.js <<'JS_EOF'
const assert = require("assert");
const express = require("express");
(async () => {
  process.env.ATLAS_DASH_KEY = "dashkode-123456";
  const { setupCoordinatorRoutes } = require("../src/routes/coordinatorRoutes");
  const app = express(); app.use(express.json()); setupCoordinatorRoutes(app);
  const srv = await new Promise((r) => { const s = app.listen(0, () => r(s)); });
  const B = "http://127.0.0.1:" + srv.address().port;
  const st = async (path, opt) => (await fetch(B + path, opt)).status;
  const key = { headers: { "x-atlas-key": "dashkode-123456" } };
  assert.strictEqual(await st("/api/coordinator/agents"), 200);
  for (const p of ["/api/coordinator/tasks", "/api/coordinator/summary", "/api/coordinator/briefing"]) {
    assert.strictEqual(await st(p), 401, p + " uten nøkkel");
    assert.strictEqual(await st(p, { headers: { "x-atlas-key": "feil" } }), 401);
    assert.strictEqual(await st(p, key), 200, p + " med nøkkel");
  }
  const post = (h) => ({ method: "POST", headers: Object.assign({ "content-type": "application/json" }, h), body: JSON.stringify({ type: "gold", payload: {} }) });
  assert.strictEqual(await st("/api/coordinator/tasks", post({})), 202, "POST åpen uten ATLAS_POST_KEY");
  process.env.ATLAS_POST_KEY = "postkode-654321";
  assert.strictEqual(await st("/api/coordinator/tasks", post({})), 401);
  assert.strictEqual(await st("/api/coordinator/tasks", post({ "x-atlas-key": "postkode-654321" })), 202);
  assert.strictEqual(await st("/api/coordinator/tasks", post({ "x-atlas-key": "dashkode-123456" })), 202);
  delete process.env.ATLAS_DASH_KEY; delete process.env.ATLAS_POST_KEY;
  assert.strictEqual(await st("/api/coordinator/tasks"), 200, "åpen når nøkkel ikke er satt");
  srv.close(); console.log("lås OK"); process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
JS_EOF
node scripts/test_laas.js
node scripts/test_rapport.js
node -e 'const h=require("fs").readFileSync("public/dashboard/jarvis.html","utf8");new Function(h.match(/<script>([\s\S]*)<\/script>/)[1]);console.log("jarvis.html kompilerer")'
echo "✅ Script 22 ferdig"
