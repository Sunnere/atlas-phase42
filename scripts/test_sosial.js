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
