// Trading-agent: leser tall fra aksjeroboten (papirkonto) og måler den mot S&P 500 (SPY).
// Ingen eksterne kall her. Dataene leveres av tools/trading/atlas_feed.py på Macen:
//   asOf: ISO-tid
//   usdNok: kurs (valgfri)
//   totals: { costUsd, valueUsd, spyUsd }
//   positions: [{ sym, qty, costUsd, valueUsd, priced }]
//   sold: [{ sym, qty, costUsd, proceedsUsd, spyUsd }]
//   health: { lastRunStatus, lastRunMessage, hoursSinceRun, signalsAgeHours, signalRows, hoursSinceOrder }
// Kun måling og varsler. Ingen handelsråd.
const RUN_PROBLEMS = {
  ikke_innlogget: "IB Gateway er ikke innlogget. Roboten handler ikke før den er logget inn (husk ⌘Q på IBKR Desktop).",
  ibkr_stille: "IBKR svarte ikke ved siste kjøring.",
  signaler: "Signalene kunne ikke hentes ved siste kjøring.",
  feil: "Roboten feilet ved siste kjøring. Se loggen i aksjesignaler/logs.",
};
const MAX_SIGNAL_AGE_H = 36;
const MIN_SIGNAL_ROWS = 10;
const STALE_RUN_H = 80; // helg + litt slingringsmonn
const BIG_LOSS_PCT = -15;

function num(v, name) {
  const n = Number(v);
  if (!Number.isFinite(n)) throw new Error(`${name} må være et tall`);
  return n;
}
const r1 = (x) => Math.round(x * 10) / 10;
const r0 = (x) => Math.round(x);

function assessTrading(p) {
  if (!p || typeof p !== "object") throw new Error("payload mangler");
  if (!p.totals || typeof p.totals !== "object") throw new Error("totals mangler");
  const cost = num(p.totals.costUsd, "totals.costUsd");
  const value = num(p.totals.valueUsd, "totals.valueUsd");
  const spy = num(p.totals.spyUsd, "totals.spyUsd");
  if (cost <= 0) throw new Error("totals.costUsd må være over 0");
  const usdNok = p.usdNok === undefined ? 10 : num(p.usdNok, "usdNok");

  const positions = (Array.isArray(p.positions) ? p.positions : []).map((x) => {
    if (!x || typeof x.sym !== "string" || !x.sym) throw new Error("hver posisjon trenger sym");
    const c = num(x.costUsd, `${x.sym}.costUsd`);
    const v = num(x.valueUsd, `${x.sym}.valueUsd`);
    return { sym: x.sym, qty: Number(x.qty || 0), costUsd: r0(c), valueUsd: r0(v), pnlPct: c > 0 ? r1((v / c - 1) * 100) : 0, priced: x.priced !== false };
  });
  const sold = (Array.isArray(p.sold) ? p.sold : []).map((x) => {
    if (!x || typeof x.sym !== "string" || !x.sym) throw new Error("hver solgt post trenger sym");
    const c = num(x.costUsd, `${x.sym}.costUsd`);
    const f = num(x.proceedsUsd, `${x.sym}.proceedsUsd`);
    return { sym: x.sym, qty: Number(x.qty || 0), costUsd: r0(c), proceedsUsd: r0(f), pnlPct: c > 0 ? r1((f / c - 1) * 100) : 0 };
  });

  const h = p.health && typeof p.health === "object" ? p.health : {};
  const health = {
    lastRunStatus: typeof h.lastRunStatus === "string" ? h.lastRunStatus : "ukjent",
    lastRunMessage: h.lastRunMessage ? String(h.lastRunMessage).slice(0, 200) : "",
    hoursSinceRun: Number.isFinite(Number(h.hoursSinceRun)) && h.hoursSinceRun !== null ? r1(Number(h.hoursSinceRun)) : null,
    signalsAgeHours: Number.isFinite(Number(h.signalsAgeHours)) && h.signalsAgeHours !== null ? r1(Number(h.signalsAgeHours)) : null,
    signalRows: Number.isFinite(Number(h.signalRows)) && h.signalRows !== null ? Number(h.signalRows) : null,
    hoursSinceOrder: Number.isFinite(Number(h.hoursSinceOrder)) && h.hoursSinceOrder !== null ? r1(Number(h.hoursSinceOrder)) : null,
  };

  const roboPct = r1((value / cost - 1) * 100);
  const spyPct = r1((spy / cost - 1) * 100);
  const diffUsd = r0(value - spy);
  const diffPct = spy > 0 ? r1((value / spy - 1) * 100) : 0;

  const flags = [];
  if (RUN_PROBLEMS[health.lastRunStatus]) flags.push({ typ: "drift", tekst: RUN_PROBLEMS[health.lastRunStatus] });
  if (health.hoursSinceRun !== null && health.hoursSinceRun > STALE_RUN_H) flags.push({ typ: "drift", tekst: `Roboten har ikke kjørt på ${Math.round(health.hoursSinceRun)} timer.` });
  if (health.signalsAgeHours !== null && health.signalsAgeHours > MAX_SIGNAL_AGE_H) flags.push({ typ: "drift", tekst: `Signalfilen er ${Math.round(health.signalsAgeHours)} timer gammel (grense ${MAX_SIGNAL_AGE_H}).` });
  if (health.signalRows !== null && health.signalRows < MIN_SIGNAL_ROWS) flags.push({ typ: "drift", tekst: `Signallisten har bare ${health.signalRows} rader (roboten nekter under ${MIN_SIGNAL_ROWS}).` });
  for (const x of positions.filter((y) => y.pnlPct <= BIG_LOSS_PCT)) flags.push({ typ: "tap", tekst: `${x.sym} er ${x.pnlPct} % fra kjøpskurs.` });
  for (const x of positions.filter((y) => !y.priced)) flags.push({ typ: "kurs", tekst: `Mangler kurs for ${x.sym}, verdsatt til kjøpspris.` });
  if (diffPct <= -2) flags.push({ typ: "marked", tekst: `Roboten ligger ${Math.abs(diffPct)} % under S&P 500 (${diffUsd} USD).` });

  const worst = positions.length ? positions.reduce((a, b) => (b.pnlPct < a.pnlPct ? b : a)) : null;
  return {
    asOf: typeof p.asOf === "string" ? p.asOf : null,
    usdNok,
    totals: { costUsd: r0(cost), valueUsd: r0(value), spyUsd: r0(spy) },
    roboPct, spyPct, diffUsd, diffPct, diffNok: r0(diffUsd * usdNok),
    positions, sold, worst, health, flags,
    source: "IBKR papirkonto + Nordnet-kurser",
  };
}

function checkTrading(result) {
  const problems = [];
  if (!result || !result.totals || !Number.isFinite(result.totals.costUsd) || result.totals.costUsd <= 0) problems.push("totals mangler");
  if (!result || !Number.isFinite(result.roboPct)) problems.push("avkastning mangler");
  return problems;
}

module.exports = { assessTrading, checkTrading };
