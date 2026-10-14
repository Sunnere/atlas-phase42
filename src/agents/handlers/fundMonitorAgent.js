// Fond-monitor: nøkkeltall fra månedlige sluttkurser. Samme regler som scripts/fund_score.py.
// Kun kursavkastning, uten utbytte. Score er et sorteringsverktøy, ikke et kjøpsråd.

const MIN_MONTHS = 36;
const GREEN_MIN_ANN = 6.0;
const GREEN_MAX_DD = -30.0;
const GREEN_MAX_VOL = 20.0;

function rating(m) {
  if (m.months < MIN_MONTHS) return "GRÅ (for kort historikk)";
  if (m.ann < 0) return "RØD";
  if (m.ann >= GREEN_MIN_ANN && m.mdd > GREEN_MAX_DD && m.vol < GREEN_MAX_VOL) return "GRØNN";
  return "ORANSJE";
}

function analyseFund(p) {
  if (!p || typeof p.name !== "string" || !p.name) throw new Error("name mangler");
  if (!Array.isArray(p.closes) || p.closes.length < 2) throw new Error("closes må ha minst to månedlige sluttkurser");

  const rows = p.closes
    .map((r) => {
      if (!r || !/^\d{4}-\d{2}$/.test(r.date) || !(Number(r.close) > 0)) {
        throw new Error("ugyldig rad: " + JSON.stringify(r));
      }
      return [r.date, Number(r.close)];
    })
    .sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0));

  const closes = rows.map((r) => r[1]);
  const months = closes.length - 1;
  const years = months / 12;
  const last = closes[closes.length - 1];
  const total = (last / closes[0] - 1) * 100;
  const ann = (Math.pow(last / closes[0], 1 / years) - 1) * 100;

  const rets = [];
  for (let i = 1; i < closes.length; i++) rets.push(closes[i] / closes[i - 1] - 1);
  const mean = rets.reduce((a, b) => a + b, 0) / rets.length;
  let vol = 0;
  if (rets.length > 1) {
    const variance = rets.reduce((s, r) => s + Math.pow(r - mean, 2), 0) / (rets.length - 1);
    vol = Math.sqrt(variance) * Math.sqrt(12) * 100;
  }

  let peak = closes[0];
  let mdd = 0;
  for (const c of closes) {
    if (c > peak) peak = c;
    const dd = (c / peak - 1) * 100;
    if (dd < mdd) mdd = dd;
  }

  const m = { months, ann, vol, mdd };
  return {
    name: p.name,
    rating: rating(m),
    start: rows[0][0],
    end: rows[rows.length - 1][0],
    months,
    total,
    ann,
    vol,
    mdd,
    note: "Kun kursavkastning, uten utbytte. Sorteringsverktøy, ikke kjøpsråd.",
  };
}

module.exports = { analyseFund, rating };
