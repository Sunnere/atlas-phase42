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
