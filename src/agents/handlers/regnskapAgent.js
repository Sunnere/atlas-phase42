// Regnskapsagent: regelbasert kategorisering av én postering.
// Ingen eksterne kall. Ukjente poster flagges for gjennomgang i stedet for å gjettes.

const TYPES = ["income", "expense"];

function assessRegnskap(p) {
  const problems = [];
  if (!p || typeof p !== "object") throw new Error("payload mangler");
  if (!TYPES.includes(p.type)) problems.push("type må være income eller expense");
  if (!Number.isFinite(p.amount) || p.amount <= 0) problems.push("beløp må være et positivt tall");
  if (typeof p.date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(p.date)) problems.push("dato må være YYYY-MM-DD");
  if (problems.length) throw new Error(problems.join("; "));

  const src = String(p.source || "").toLowerCase();
  let category;
  if (p.type === "income") {
    if (src.includes("airbnb")) category = "Utleieinntekt (kortidsutleie)";
    else if (src.includes("stripe")) category = "Salgsinntekt (Stripe)";
    else if (src.includes("adtraction")) category = "Provisjonsinntekt (affiliate)";
    else category = "Annen inntekt";
  } else {
    category = "Driftsutgift (ukategorisert)";
  }

  const notes = [];
  if (p.type === "income") {
    notes.push("Momsgrensen (50 000 kr) gjelder akkumulert omsetning per år. Følges opp samlet, ikke per postering.");
  }

  return {
    type: p.type,
    amount: p.amount,
    date: p.date,
    category,
    needsReview: category.startsWith("Annen") || category.includes("ukategorisert"),
    notes,
  };
}

module.exports = { assessRegnskap };
