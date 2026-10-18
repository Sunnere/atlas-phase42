#!/usr/bin/env bash
# 19_morning_briefing.sh — legger til "oppdater meg"-morgenoppdatering i ATLAS-koordinatoren.
# Kjør fra repo-roten:  bash scripts/19_morning_briefing.sh
set -euo pipefail

if [ ! -f "16_railway-backend-phase42.js" ] || [ ! -d "src/agents" ]; then
  echo "FEIL: kjør fra repo-roten (der 16_railway-backend-phase42.js ligger)." >&2
  exit 1
fi
if [ ! -f "src/routes/coordinatorRoutes.js" ]; then
  echo "FEIL: src/routes/coordinatorRoutes.js finnes ikke. Kjør 18_coordinator_schedule.sh først." >&2
  exit 1
fi

mkdir -p src/agents
cat > src/agents/briefing.js <<'ROY_EOF_BRIEF'
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

  const todo = [];
  if (gmail) {
    for (const m of gmail.haster) todo.push({ typ: "haster", tekst: `${m.subject} (fra ${m.from})` });
    for (const m of gmail.partner) todo.push({ typ: "partner", tekst: `${m.subject} (fra ${m.from})` });
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
    makeAnnonser: null, // kobles inn når Zernio-post-ID-er lagres i datastore
  };

  const mangler = ["gmail", "calendar", "gold"].filter((t) => !latest[t]);

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

  lines.push("📣 Make-annonser (visninger, likes, kommentarer)");
  lines.push("  Ikke koblet ennå. Venter på at Zernio-post-ID-er lagres.");

  if (mangler.length) {
    lines.push("");
    lines.push(`ℹ️ Ingen resultat ennå fra: ${mangler.join(", ")}`);
  }
  return lines.join("\n");
}

module.exports = { buildBriefing };
ROY_EOF_BRIEF

python3 - <<'ROY_PY'
p = "src/routes/coordinatorRoutes.js"
s = open(p, encoding="utf-8").read()
if '/api/coordinator/briefing' in s:
    print("routes: briefing finnes allerede, hopper over")
else:
    anchor = '  app.get("/api/coordinator/tasks", (req, res) => {'
    assert s.count(anchor) == 1, "fant ikke ankerpunkt i coordinatorRoutes.js"
    block = (
        '  // "Oppdater meg": samlet morgenoppdatering (gjøremål, e-post, kalender, gull, Make-plassholder).\n'
        '  app.get("/api/coordinator/briefing", (req, res) => {\n'
        '    const { buildBriefing } = require("../agents/briefing");\n'
        '    res.json({ success: true, data: buildBriefing(coordinator.latest()) });\n'
        '  });\n\n'
    )
    s = s.replace(anchor, block + anchor)
    open(p, "w", encoding="utf-8").write(s)
    print("routes: lagt til /api/coordinator/briefing")
ROY_PY

node --check src/agents/briefing.js
node --check src/routes/coordinatorRoutes.js
echo "OK: 19_morning_briefing installert."
echo "Neste: git add src/agents/briefing.js src/routes/coordinatorRoutes.js scripts/19_morning_briefing.sh && git commit -m \"Morgenoppdatering: /api/coordinator/briefing\" && git push origin master"
