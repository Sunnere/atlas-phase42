// Gmail-agent: grupperer uleste e-poster. Ingen Google-kall her.
// Dataene leveres i payload: messages = [{ from, subject, date, snippet? }].
// Regler følger morgenbrief-spesifikasjonen: sikkerhet og penger først, partnere alltid med,
// alt annet som info. Ingen e-post sendes eller slettes herfra.

const SECURITY = /verify|verif|bekreft|sikkerhet|security|passord|password|innlogging|login|logg inn|påminnelse|purring|forfall|final notice|avslutt|kontoslett|account|konto|suspend|sperr|deaktivert|faktura|invoice|betaling|payment/i;
const PARTNER_FROM = /adtraction\.com/i;

function assessGmail(p) {
  if (!p || typeof p !== "object") throw new Error("payload mangler");
  if (!Array.isArray(p.messages)) throw new Error("messages må være en liste");

  const haster = [];
  const partner = [];
  const info = [];
  for (const m of p.messages) {
    if (!m || typeof m.from !== "string" || typeof m.subject !== "string") {
      throw new Error("hver melding trenger from og subject");
    }
    const text = `${m.subject} ${m.snippet || ""}`;
    const item = { from: m.from, subject: m.subject, date: m.date || null };
    if (PARTNER_FROM.test(m.from)) partner.push(item);
    else if (SECURITY.test(text)) haster.push(item);
    else info.push(item);
  }

  return {
    counts: { haster: haster.length, partner: partner.length, info: info.length, total: p.messages.length },
    haster,
    partner,
    info,
    note: "Sikkerhetsvarsler og penger flagges, aldri konklusjon. Roy avgjør selv.",
  };
}

module.exports = { assessGmail };
