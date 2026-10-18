// Stripe-agent: oppsummerer betalinger siste døgn. Ingen Stripe-kall her.
// Dataene leveres i payload fra en planlagt jobb (Stripe-connector):
//   charges:  [{ id, amount, currency, status, created, refunded, disputed, failure_message? }]
//   refunds:  [{ id, amount, currency, created }]
//   disputes: [{ id, amount, currency, status, created, reason? }]
//   balance:  { available: [{amount,currency}], pending: [{amount,currency}] }   (valgfri)
// Beløp er i minste enhet (øre), som hos Stripe. Ingen penger flyttes eller endres herfra.

const FAILED_ALERT_SHARE = 0.2; // over 20 % mislykkede betalinger flagges
const MIN_CHARGES_FOR_SHARE = 5;

function sumByCurrency(items) {
  const out = {};
  for (const it of items) {
    const cur = String(it.currency || "nok").toUpperCase();
    out[cur] = (out[cur] || 0) + Number(it.amount || 0);
  }
  return out;
}

function analyseStripe(p) {
  if (!p || typeof p !== "object") throw new Error("payload mangler");
  const charges = Array.isArray(p.charges) ? p.charges : [];
  const refunds = Array.isArray(p.refunds) ? p.refunds : [];
  const disputes = Array.isArray(p.disputes) ? p.disputes : [];

  const succeeded = charges.filter((c) => c.status === "succeeded");
  const failed = charges.filter((c) => c.status === "failed");
  const openDisputes = disputes.filter((d) => d.status && !/won|lost|closed/i.test(d.status));

  const flags = [];
  if (openDisputes.length > 0) flags.push({ typ: "dispute", tekst: `${openDisputes.length} åpen(e) dispute(r) i Stripe` });
  if (charges.length >= MIN_CHARGES_FOR_SHARE && failed.length / charges.length > FAILED_ALERT_SHARE) {
    flags.push({ typ: "feil", tekst: `${failed.length} av ${charges.length} betalinger feilet (${Math.round((100 * failed.length) / charges.length)} %)` });
  }

  return {
    counts: {
      charges: charges.length,
      succeeded: succeeded.length,
      failed: failed.length,
      refunds: refunds.length,
      disputes: disputes.length,
      openDisputes: openDisputes.length,
    },
    volume: sumByCurrency(succeeded),
    refunded: sumByCurrency(refunds),
    balance: p.balance || null,
    flags,
    failedSamples: failed.slice(0, 5).map((c) => ({ id: c.id, amount: c.amount, currency: c.currency, message: c.failure_message || null })),
    note: "Oppsummering og flagg. Ingen refusjon, ingen endring i Stripe.",
  };
}

function checkStripe(result) {
  const problems = [];
  if (!result.counts || !Number.isFinite(result.counts.charges)) problems.push("counts mangler");
  if (!result.volume || typeof result.volume !== "object") problems.push("volume mangler");
  return problems;
}

module.exports = { analyseStripe, checkStripe };
