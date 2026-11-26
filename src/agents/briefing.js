// Morgenoppdatering ("oppdater meg"): setter sammen siste resultat fra alle agenter
// til én oversikt. Ren funksjon over latest() — ingen eksterne kall.
// Make-annonsetall er med som plassholder til Zernio-post-ID-ene er lagret.

function fmtTime(iso) {
  if (!iso) return "";
  return new Date(iso).toLocaleString("nb-NO", { timeZone: "Europe/Oslo", dateStyle: "short", timeStyle: "short" });
}

function buildBriefing(latest, now = new Date()) {
  const gmail = latest.gmail && latest.gmail.result ? latest.gmail.result : null;
  const calendar = latest.calendar && latest.calendar.result ? latest.calendar.result : null;
  const gold = latest.gold && latest.gold.result ? latest.gold.result : null;
  const stripe = latest.stripe && latest.stripe.result ? latest.stripe.result : null;
  const fronter = latest.fronter && latest.fronter.result ? latest.fronter.result : null;
  const rapport = latest.rapport && latest.rapport.result ? latest.rapport.result : null;
  const sosial = latest.sosial && latest.sosial.result ? latest.sosial.result : null;
  const okonomi = latest.okonomi && latest.okonomi.result ? latest.okonomi.result : null;
  const trading = latest.trading && latest.trading.result ? latest.trading.result : null;

  const todo = [];
  if (gmail) {
    for (const m of gmail.haster) todo.push({ typ: "haster", tekst: `${m.subject} (fra ${m.from})` });
    for (const m of gmail.partner) todo.push({ typ: "partner", tekst: `${m.subject} (fra ${m.from})` });
  }
  if (stripe) {
    for (const f of stripe.flags) todo.push({ typ: "stripe", tekst: f.tekst });
  }
  if (fronter) {
    for (const a of fronter.attention) todo.push({ typ: a.status === "error" ? "feil" : "obs", tekst: `${a.front}: ${a.name}${a.detail ? " – " + a.detail : ""}` });
  }
  if (trading) {
    for (const f of trading.flags.filter((x) => x.typ === "drift")) todo.push({ typ: "trading", tekst: f.tekst });
  }
  if (okonomi) {
    for (const f of okonomi.flags.filter((x) => x.typ === "moms")) todo.push({ typ: "moms", tekst: f.tekst });
  }
  if (calendar) {
    for (const c of calendar.conflicts) todo.push({ typ: "kalender", tekst: `Overlapp: ${c.a} / ${c.b}` });
  }

  const sections = {
    gull: gold
      ? { pris: gold.price, endringProsent: gold.percentChange, tidspunkt: gold.datetime, kilde: gold.source, sjekket: latest.gold.finishedAt }
      : null,
    epost: gmail
      ? { counts: gmail.counts, haster: gmail.haster, partner: gmail.partner, info: gmail.info, sistOppdatert: latest.gmail.finishedAt }
      : null,
    kalender: calendar
      ? { counts: calendar.counts, neste48t: calendar.upcoming, konflikter: calendar.conflicts, sistOppdatert: latest.calendar.finishedAt }
      : null,
    stripe: stripe
      ? { counts: stripe.counts, volume: stripe.volume, refunded: stripe.refunded, flags: stripe.flags, sistOppdatert: latest.stripe.finishedAt }
      : null,
    fronter: fronter ? { counts: fronter.counts, byFront: fronter.byFront, attention: fronter.attention, sistOppdatert: latest.fronter.finishedAt } : null,
    rapport: rapport ? { total: rapport.total, instances: rapport.instances, sistOppdatert: latest.rapport.finishedAt } : null,
    sosial: sosial ? { period: sosial.period, totals: sosial.totals, channels: sosial.channels, flags: sosial.flags, recommendation: sosial.recommendation, sistOppdatert: latest.sosial.finishedAt } : null,
    okonomi: okonomi ? { year: okonomi.year, total: okonomi.total, percent: okonomi.percent, vatLimit: okonomi.vatLimit, sources: okonomi.sources, flags: okonomi.flags, sistOppdatert: latest.okonomi.finishedAt } : null,
    trading: trading ? { roboPct: trading.roboPct, spyPct: trading.spyPct, diffUsd: trading.diffUsd, diffNok: trading.diffNok, totals: trading.totals, positions: trading.positions.length, flags: trading.flags, sistOppdatert: latest.trading.finishedAt } : null,
    makeAnnonser: null, // kobles inn når Zernio-post-ID-er lagres i datastore
  };

  const mangler = ["gmail", "calendar", "gold", "stripe", "fronter", "rapport", "sosial", "okonomi", "trading"].filter((t) => !latest[t]);

  return {
    generatedAt: now.toISOString(),
    dagensGjoremal: todo,
    seksjoner: sections,
    mangler,
    tekst: renderText(sections, todo, mangler, now),
  };
}

function renderText(s, todo, mangler, now) {
  const lines = [];
  lines.push(`☀️ Oppdatering ${fmtTime(now.toISOString())}`);
  lines.push("");

  lines.push("✅ Dagens gjøremål");
  if (todo.length === 0) lines.push("  Ingenting akutt registrert.");
  for (const t of todo) lines.push(`  • [${t.typ}] ${t.tekst}`);
  lines.push("");

  lines.push("📧 E-post");
  if (!s.epost) lines.push("  Ingen data ennå (morgenjobben kl. 07:03 henter den).");
  else {
    lines.push(`  ${s.epost.counts.total} uleste siste døgn: ${s.epost.counts.haster} å være obs på, ${s.epost.counts.partner} partner, ${s.epost.counts.info} info`);
    for (const m of s.epost.haster) lines.push(`  ⚠️ ${m.subject} (${m.from})`);
  }
  lines.push("");

  lines.push("📅 Neste 48 timer");
  if (!s.kalender) lines.push("  Ingen data ennå.");
  else if (s.kalender.neste48t.length === 0) lines.push("  Ingen hendelser.");
  else for (const c of s.kalender.neste48t) lines.push(`  • ${fmtTime(c.start)}: ${c.summary}`);
  lines.push("");

  lines.push("🥇 Gull (XAU/USD)");
  if (!s.gull) lines.push("  Ingen data ennå.");
  else lines.push(`  ${s.gull.pris} USD (${s.gull.endringProsent >= 0 ? "+" : ""}${Number(s.gull.endringProsent).toFixed(2)} %) — sjekket ${fmtTime(s.gull.sjekket)}`);
  lines.push("");

  lines.push("💳 Stripe (siste døgn)");
  if (!s.stripe) lines.push("  Ingen data ennå.");
  else {
    const vol = Object.entries(s.stripe.volume).map(([c, v]) => `${(v / 100).toFixed(2)} ${c}`).join(", ") || "0";
    lines.push(`  ${s.stripe.counts.succeeded} vellykkede (${vol}), ${s.stripe.counts.failed} feilet, ${s.stripe.counts.refunds} refusjoner, ${s.stripe.counts.openDisputes} åpne disputer`);
  }
  lines.push("");

  lines.push("🧭 Fronter (Make + Railway)");
  if (!s.fronter) lines.push("  Ingen data ennå.");
  else {
    const c = s.fronter.counts;
    lines.push(`  ${c.ok} i orden, ${c.warn} obs, ${c.error} feil, ${c.paused} pauset av ${c.total}`);
    for (const [f, v] of Object.entries(s.fronter.byFront)) lines.push(`  • ${f}: ${v.ok}/${v.total} i orden${v.error ? `, ${v.error} feil` : ""}`);
  }
  lines.push("");

  lines.push("📝 ATLAS Rapport");
  if (!s.rapport) lines.push("  Ingen data ennå.");
  else lines.push("  " + s.rapport.instances.map((i) => `${i.name}: ${i.ok ? i.total + " saker" : "ikke nådd"}`).join(" · "));
  lines.push("");

  lines.push("📈 Trading (papirkonto)");
  if (!s.trading) lines.push("  Ingen data ennå.");
  else {
    const t = s.trading;
    lines.push(`  Roboten ${t.roboPct} % mot S&P 500 ${t.spyPct} % (${t.diffUsd >= 0 ? "+" : ""}${t.diffUsd} USD, ca. ${t.diffNok} kr), ${t.positions} posisjoner`);
    for (const f of t.flags) lines.push(`  ⚠️ ${f.tekst}`);
  }
  lines.push("");

  lines.push("💰 Økonomi (hittil i år)");
  if (!s.okonomi) lines.push("  Ingen data ennå.");
  else {
    lines.push(`  Omsetning ${s.okonomi.total} kr, ${s.okonomi.percent} % av momsgrensen (${s.okonomi.vatLimit} kr)`);
    for (const src of s.okonomi.sources) lines.push(`  • ${src.name}: ${src.status === "ok" ? src.amountNok + " kr (" + src.count + ")" : "mangler data"}`);
    for (const f of s.okonomi.flags.filter((x) => x.typ === "moms")) lines.push(`  ⚠️ ${f.tekst}`);
  }
  lines.push("");

  lines.push("📱 Sosiale medier (siste uke)");
  if (!s.sosial) lines.push("  Ingen data ennå (kommer hver mandag).");
  else {
    const t = s.sosial.totals;
    lines.push(`  ${t.posts} poster, ${t.views} visninger, ${t.reactions} likes, ${t.comments} kommentarer, ${t.clicks} klikk`);
    for (const c of s.sosial.channels) lines.push(`  • ${c.name}: ${c.posts} poster, ${c.views} visninger`);
    for (const f of s.sosial.flags) lines.push(`  ⚠️ ${f.tekst}`);
    if (s.sosial.recommendation) lines.push("  💡 " + s.sosial.recommendation);
  }
  lines.push("");

  lines.push("📣 Make-annonser (visninger, likes, kommentarer)");
  lines.push("  Ikke koblet ennå. Venter på at Zernio-post-ID-er lagres.");

  if (mangler.length) {
    lines.push("");
    lines.push(`ℹ️ Ingen resultat ennå fra: ${mangler.join(", ")}`);
  }
  return lines.join("\n");
}

module.exports = { buildBriefing };
