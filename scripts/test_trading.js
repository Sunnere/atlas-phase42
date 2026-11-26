const assert = require("assert");
const { assessTrading, checkTrading } = require("../src/agents/handlers/tradingAgent");
const { buildBriefing } = require("../src/agents/briefing");
const coordinator = require("../src/agents/coordinator");
const base = () => ({
  asOf: "2026-11-26T16:00:00", usdNok: 10,
  totals: { costUsd: 3117, valueUsd: 2969, spyUsd: 2988 },
  positions: [
    { sym: "TM", qty: 2, costUsd: 433, valueUsd: 432, priced: true },
    { sym: "TSM", qty: 1, costUsd: 417, valueUsd: 342, priced: true },
  ],
  sold: [{ sym: "BABA", qty: 1, costUsd: 103, proceedsUsd: 81 }],
  health: { lastRunStatus: "ingen_handler", lastRunMessage: "Ingen handler i dag.", hoursSinceRun: 2, signalsAgeHours: 3, signalRows: 50, hoursSinceOrder: 30 },
});
(async () => {
  const r = assessTrading(base());
  assert.strictEqual(r.roboPct, -4.7);
  assert.strictEqual(r.spyPct, -4.1);
  assert.strictEqual(r.diffUsd, -19);
  assert.strictEqual(r.diffNok, -190);
  assert.strictEqual(r.worst.sym, "TSM");
  assert.strictEqual(r.worst.pnlPct, -18);
  assert.ok(r.flags.some((f) => f.typ === "tap" && f.tekst.includes("TSM")));
  assert.ok(!r.flags.some((f) => f.typ === "drift"));
  assert.deepStrictEqual(checkTrading(r), []);

  const d = base();
  d.health = { lastRunStatus: "ikke_innlogget", signalsAgeHours: 50, signalRows: 4, hoursSinceRun: 100 };
  const rd = assessTrading(d);
  assert.strictEqual(rd.flags.filter((f) => f.typ === "drift").length, 4);

  const u = base(); u.positions[0].priced = false;
  assert.ok(assessTrading(u).flags.some((f) => f.typ === "kurs"));
  assert.throws(() => assessTrading({}));
  assert.throws(() => assessTrading({ totals: { costUsd: 0, valueUsd: 0, spyUsd: 0 } }));
  assert.throws(() => assessTrading({ totals: { costUsd: "x", valueUsd: 1, spyUsd: 1 } }));
  assert.ok(assessTrading({ totals: { costUsd: 100, valueUsd: 110, spyUsd: 105 } }).roboPct === 10);

  assert.ok(coordinator.agentTypes().includes("trading"));
  const t = coordinator.submit("trading", base());
  await new Promise((res) => setTimeout(res, 300));
  assert.strictEqual(coordinator.get(t.id).status, "done");
  const b = buildBriefing({ trading: { result: rd, finishedAt: new Date().toISOString() } });
  assert.ok(b.tekst.includes("Trading (papirkonto)") && b.dagensGjoremal.some((x) => x.typ === "trading"));
  console.log("trading OK"); process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
