// Gull-agent: spotkurs XAU/USD (USD per troy unse) fra Twelve Data.
// Rapporterer kurs og døgnendring. Gir ingen kjøps- eller salgsråd.

const SYMBOL = "XAU/USD";
const ENDPOINT = "https://api.twelvedata.com/quote";

// deps gjør testing mulig uten nettverk: { fetch, apiKey }
async function analyseGold(_payload, deps = {}) {
  const fetchFn = deps.fetch || fetch;
  const apiKey = deps.apiKey || process.env.TWELVE_DATA_API_KEY;
  if (!apiKey) throw new Error("TWELVE_DATA_API_KEY mangler i miljøet");

  const url = `${ENDPOINT}?symbol=${encodeURIComponent(SYMBOL)}&apikey=${encodeURIComponent(apiKey)}`;
  const res = await fetchFn(url);
  const j = await res.json();
  if (!res.ok || j.status === "error") {
    throw new Error("Twelve Data: " + (j.message || `HTTP ${res.status}`));
  }

  const price = Number(j.close);
  if (!(price > 0)) throw new Error("ugyldig kurs fra Twelve Data");

  return {
    symbol: SYMBOL,
    name: j.name || "Gold Spot / US Dollar",
    price,
    previousClose: Number(j.previous_close),
    change: Number(j.change),
    percentChange: Number(j.percent_change),
    dayHigh: Number(j.high),
    dayLow: Number(j.low),
    datetime: j.datetime,
    isMarketOpen: j.is_market_open === true,
    source: "Twelve Data",
    note: "Spotkurs. Ikke et kjøps- eller salgsråd.",
  };
}

function checkGold(result) {
  const problems = [];
  if (!result || typeof result !== "object") return ["tomt svar"];
  if (!(Number.isFinite(result.price) && result.price > 0)) problems.push("kurs mangler eller er ugyldig");
  if (!Number.isFinite(result.percentChange)) problems.push("døgnendring mangler");
  return problems;
}

module.exports = { analyseGold, checkGold, SYMBOL };
