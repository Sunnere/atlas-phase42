// Sosiale medier-agent. Ingen eksterne kall her. Dataene leveres av en planlagt ukentlig jobb (Buffer):
//   period: { from, to }  (YYYY-MM-DD)
//   channels: [{ name, service, posts, views, reach, reactions, comments, clicks, shares }]
//   repeatedTexts: antall poster som er gjentakelser av samme tekst (valgfri)
//   recommendation: kort anbefaling som tekst (valgfri, maks 800 tegn)
const NUM = ["posts", "views", "reach", "reactions", "comments", "clicks", "shares"];
const LOW_VIEWS_PER_POST = 5;

function assessSosial(p) {
  if (!p || typeof p !== "object") throw new Error("payload mangler");
  if (!Array.isArray(p.channels) || p.channels.length === 0) throw new Error("channels må være en liste med minst én kanal");
  const channels = p.channels.map((c) => {
    if (!c || typeof c.name !== "string" || !c.name) throw new Error("hver kanal trenger name");
    const out = { name: c.name, service: String(c.service || "") };
    for (const k of NUM) {
      const v = Number(c[k] || 0);
      if (!Number.isFinite(v) || v < 0) throw new Error(`${c.name}: ${k} må være et tall`);
      out[k] = v;
    }
    out.viewsPerPost = out.posts ? Math.round((out.views / out.posts) * 10) / 10 : 0;
    return out;
  });
  const totals = { posts: 0, views: 0, reach: 0, reactions: 0, comments: 0, clicks: 0, shares: 0 };
  for (const c of channels) for (const k of NUM) totals[k] += c[k];
  const flags = [];
  for (const c of channels) {
    if (c.posts >= 3 && c.viewsPerPost < LOW_VIEWS_PER_POST) flags.push({ typ: "rekkevidde", tekst: `${c.name}: ${c.viewsPerPost} visninger per post (${c.posts} poster)` });
  }
  const repeated = Number(p.repeatedTexts || 0);
  if (repeated >= 3) flags.push({ typ: "gjentakelse", tekst: `${repeated} poster er gjentakelser av samme tekst` });
  return {
    period: p.period && p.period.from && p.period.to ? { from: String(p.period.from), to: String(p.period.to) } : null,
    channels, totals, flags,
    recommendation: p.recommendation ? String(p.recommendation).slice(0, 800) : "",
    source: "Buffer",
  };
}

function checkSosial(result) {
  if (!result || !result.totals || !Array.isArray(result.channels)) return ["totals mangler"];
  return [];
}

module.exports = { assessSosial, checkSosial };
