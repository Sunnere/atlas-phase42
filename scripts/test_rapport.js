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
