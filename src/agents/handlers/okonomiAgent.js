// Økonomi-agent: inntekt hittil i år per kilde, målt mot momsgrensen (50 000 kr omsetning per år).
// Ingen eksterne kall her. Dataene leveres av en planlagt jobb:
//   year: 2026
//   sources: [{ name, amountNok, count, status: "ok"|"mangler", note? }]   (beløp i hele kroner)
// Ingen bokføring og ingen råd; tallene er et varsel om hvor du er i forhold til grensen.
const VAT_LIMIT = 50000;

function assessOkonomi(p) {
  if (!p || typeof p !== "object") throw new Error("payload mangler");
  if (!Number.isInteger(p.year)) throw new Error("year må være et heltall");
  if (!Array.isArray(p.sources) || p.sources.length === 0) throw new Error("sources må være en liste med minst én kilde");
  const sources = p.sources.map((s) => {
    if (!s || typeof s.name !== "string" || !s.name) throw new Error("hver kilde trenger name");
    const status = s.status === "mangler" ? "mangler" : "ok";
    const amount = Number(s.amountNok || 0);
    if (!Number.isFinite(amount) || amount < 0) throw new Error(`${s.name}: amountNok må være et tall`);
    return { name: s.name, amountNok: Math.round(amount), count: Number(s.count || 0), status, note: s.note ? String(s.note).slice(0, 200) : "" };
  });
  const total = sources.reduce((a, s) => a + s.amountNok, 0);
  const percent = Math.round((total / VAT_LIMIT) * 1000) / 10;
  const flags = [];
  if (percent >= 90) flags.push({ typ: "moms", tekst: `Omsetning ${total} kr er ${percent} % av momsgrensen på ${VAT_LIMIT} kr. Sjekk registrering i Merverdiavgiftsregisteret.` });
  else if (percent >= 70) flags.push({ typ: "moms", tekst: `Omsetning ${total} kr er ${percent} % av momsgrensen på ${VAT_LIMIT} kr.` });
  const missing = sources.filter((s) => s.status === "mangler").map((s) => s.name);
  if (missing.length) flags.push({ typ: "mangler", tekst: "Mangler data fra: " + missing.join(", ") });
  return { year: p.year, sources, total, vatLimit: VAT_LIMIT, percent, flags, source: "Stripe + e-post" };
}

function checkOkonomi(result) {
  if (!result || !Number.isFinite(result.total) || !Array.isArray(result.sources)) return ["total mangler"];
  return [];
}

module.exports = { assessOkonomi, checkOkonomi, VAT_LIMIT };
