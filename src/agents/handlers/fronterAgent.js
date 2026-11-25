// Fronter-agent: samler driftsstatus fra Make-scenarioer og Railway-tjenester, gruppert per front.
// Ingen eksterne kall her. Dataene leveres i payload fra en planlagt jobb:
//   items: [{ front, name, kind: "make"|"railway", status: "ok"|"warn"|"error"|"paused", detail?, next? }]
const STATUSES = ["ok", "warn", "error", "paused"];

function emptyCounts() {
  return { ok: 0, warn: 0, error: 0, paused: 0, total: 0 };
}

function assessFronter(p) {
  if (!p || typeof p !== "object") throw new Error("payload mangler");
  if (!Array.isArray(p.items)) throw new Error("items må være en liste");
  const counts = emptyCounts();
  const byFront = {};
  const items = [];
  for (const it of p.items) {
    if (!it || typeof it.name !== "string" || !STATUSES.includes(it.status)) {
      throw new Error("hvert element trenger name og status (ok/warn/error/paused): " + JSON.stringify(it));
    }
    const front = String(it.front || "Annet");
    const kind = it.kind === "railway" ? "railway" : "make";
    const item = { front, name: it.name, kind, status: it.status, detail: it.detail ? String(it.detail).slice(0, 200) : "", next: it.next || null };
    items.push(item);
    counts[it.status]++; counts.total++;
    byFront[front] = byFront[front] || emptyCounts();
    byFront[front][it.status]++; byFront[front].total++;
  }
  const attention = items.filter((i) => i.status === "error" || i.status === "warn");
  return { counts, byFront, items, attention, source: "Make + Railway" };
}

function checkFronter(result) {
  const problems = [];
  if (!result || !result.counts || !Number.isFinite(result.counts.total)) return ["counts mangler"];
  if (result.counts.total === 0) problems.push("ingen elementer");
  if (result.counts.error > 0) problems.push(result.counts.error + " med feil: " + result.attention.filter((i) => i.status === "error").map((i) => i.name).join(", "));
  return problems;
}

module.exports = { assessFronter, checkFronter };
