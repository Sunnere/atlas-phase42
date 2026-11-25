// Rapport-agent: teller saker i ATLAS Rapport-instansene (Øyer, Lillehammer, privat osv.).
// Resultatet havner i /api/coordinator/tasks som er åpent, så det inneholder BARE tall og tidspunkt.
// Sakslisten med titler hentes fra /api/rapport/saker, som krever ATLAS_DASH_KEY.
// Instanser settes i RAPPORT_INSTANCES (JSON): [{"name":"Øyer","url":"https://…","token":"…"}]

const TIMEOUT_MS = 10000;
const CACHE_MS = 60 * 1000;
let cache = { at: 0, instances: [], cases: [] };

function instances() {
  try {
    const a = JSON.parse(process.env.RAPPORT_INSTANCES || "[]");
    return Array.isArray(a) ? a.filter((i) => i && i.name && /^https?:\/\//.test(i.url || "") && i.token) : [];
  } catch (_) {
    return [];
  }
}

async function fetchOne(inst, fetchFn) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    const res = await fetchFn(String(inst.url).replace(/\/$/, "") + "/api/meetings", {
      headers: { Authorization: "Bearer " + inst.token },
      signal: ctrl.signal,
    });
    if (!res.ok) return { name: inst.name, ok: false, error: "HTTP " + res.status, cases: [] };
    const list = await res.json();
    if (!Array.isArray(list)) return { name: inst.name, ok: false, error: "uventet svar", cases: [] };
    return { name: inst.name, ok: true, cases: list };
  } catch (err) {
    return { name: inst.name, ok: false, error: err.name === "AbortError" ? "tidsavbrudd" : "ikke nådd", cases: [] };
  } finally {
    clearTimeout(timer);
  }
}

async function collect(deps = {}) {
  const fetchFn = deps.fetch || fetch;
  const list = instances();
  if (!list.length) throw new Error("RAPPORT_INSTANCES mangler i miljøet");
  const results = await Promise.all(list.map((i) => fetchOne(i, fetchFn)));
  const summary = results.map((r) => {
    const kinds = {};
    for (const c of r.cases) kinds[c.kind || "meeting"] = (kinds[c.kind || "meeting"] || 0) + 1;
    const last = r.cases.map((c) => c.createdAt).filter(Boolean).sort().pop() || null;
    return { name: r.name, ok: r.ok, total: r.cases.length, kinds, last, error: r.error || null };
  });
  const cases = [];
  for (const r of results) {
    for (const c of r.cases) cases.push({ instance: r.name, id: c.id, title: c.title, kind: c.kind || "meeting", status: c.status, createdAt: c.createdAt });
  }
  cases.sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
  cache = { at: Date.now(), instances: summary, cases };
  return summary;
}

// Tall til koordinatoren. Ingen titler, ingen tokens.
async function assessRapport(_payload, deps = {}) {
  const summary = await collect(deps);
  return {
    instances: summary,
    total: summary.reduce((s, i) => s + i.total, 0),
    instancesOk: summary.filter((i) => i.ok).length,
    instancesTotal: summary.length,
    source: "ATLAS Rapport",
  };
}

function checkRapport(result) {
  const problems = [];
  if (!result || typeof result !== "object") return ["tomt svar"];
  if (!Array.isArray(result.instances)) problems.push("instances mangler");
  else if (result.instancesOk < result.instancesTotal) {
    const bad = result.instances.filter((i) => !i.ok).map((i) => i.name + " (" + i.error + ")");
    problems.push("ikke nådd: " + bad.join(", "));
  }
  return problems;
}

// For den beskyttede sakslisten. Bruker cache i 60 sekunder.
async function getCases(deps = {}) {
  if (Date.now() - cache.at > CACHE_MS) await collect(deps);
  return { at: new Date(cache.at).toISOString(), instances: cache.instances, cases: cache.cases };
}

module.exports = { assessRapport, checkRapport, getCases, instances };
