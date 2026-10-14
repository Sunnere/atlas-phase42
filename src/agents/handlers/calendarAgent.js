// Kalender-agent: kommende hendelser (48 t) og overlapp. Ingen Google-kall her.
// Dataene leveres i payload: events = [{ summary, start, end }] med ISO 8601-tider,
// og now (valgfri ISO-tid, standard er nå).

const HOURS_AHEAD = 48;

function assessCalendar(p) {
  if (!p || typeof p !== "object") throw new Error("payload mangler");
  if (!Array.isArray(p.events)) throw new Error("events må være en liste");

  const now = p.now ? Date.parse(p.now) : Date.now();
  if (!Number.isFinite(now)) throw new Error("now må være gyldig ISO-tid");

  const events = p.events.map((e) => {
    const start = Date.parse(e && e.start);
    const end = Date.parse(e && e.end);
    if (!Number.isFinite(start) || !Number.isFinite(end) || end < start) {
      throw new Error("hver hendelse trenger gyldig start og end: " + JSON.stringify(e));
    }
    return { summary: String(e.summary || "(uten tittel)"), start, end };
  });

  const horizon = now + HOURS_AHEAD * 3600 * 1000;
  const upcoming = events
    .filter((e) => e.end >= now && e.start <= horizon)
    .sort((a, b) => a.start - b.start)
    .map((e) => ({
      summary: e.summary,
      start: new Date(e.start).toISOString(),
      end: new Date(e.end).toISOString(),
      airbnb: /airbnb/i.test(e.summary),
    }));

  const conflicts = [];
  for (let i = 1; i < upcoming.length; i++) {
    const a = upcoming[i - 1];
    const b = upcoming[i];
    if (Date.parse(b.start) < Date.parse(a.end)) {
      conflicts.push({ a: a.summary, b: b.summary, start: b.start });
    }
  }

  return {
    windowHours: HOURS_AHEAD,
    upcoming,
    conflicts,
    counts: { upcoming: upcoming.length, conflicts: conflicts.length },
  };
}

module.exports = { assessCalendar };
