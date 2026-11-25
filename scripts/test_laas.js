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
