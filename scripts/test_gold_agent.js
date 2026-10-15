// Tester gull-agenten uten nettverk. Kjør: node scripts/test_gold_agent.js
const assert = require("assert");
const { analyseGold, checkGold } = require("../src/agents/handlers/goldAgent");
const { check, agentTypes } = require("../src/agents/coordinator");

const okBody = {
  symbol: "XAU/USD", name: "Gold Spot / US Dollar", close: "4137.7948",
  previous_close: "4101.65932", change: "36.13548", percent_change: "0.88099662",
  high: "4164.02226", low: "4096.84952", datetime: "2026-10-15", is_market_open: true,
};
const fakeFetch = (body, status = 200) => async () => ({ ok: status < 400, status, json: async () => body });

(async () => {
  const r = await analyseGold({}, { apiKey: "test", fetch: fakeFetch(okBody) });
  assert.strictEqual(r.price, 4137.7948);
  assert.strictEqual(r.percentChange, 0.88099662);
  assert.strictEqual(r.source, "Twelve Data");
  assert.deepStrictEqual(checkGold(r), []);

  await assert.rejects(analyseGold({}, { apiKey: "", fetch: fakeFetch(okBody) }), /TWELVE_DATA_API_KEY/);
  await assert.rejects(
    analyseGold({}, { apiKey: "test", fetch: fakeFetch({ status: "error", message: "run out of credits" }, 429) }),
    /run out of credits/
  );
  await assert.rejects(analyseGold({}, { apiKey: "test", fetch: fakeFetch({ close: "0" }) }), /ugyldig kurs/);

  assert.strictEqual(check("gold", r).ok, true);
  assert.strictEqual(check("gold", { price: -1, percentChange: 0 }).ok, false);
  assert.ok(agentTypes().includes("gold"));
  console.log("ALLE GULL-TESTER BESTÅTT");
})().catch((e) => { console.error("FEIL:", e.message); process.exit(1); });
