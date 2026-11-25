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
