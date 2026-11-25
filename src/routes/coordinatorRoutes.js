const crypto = require("crypto");
const coordinator = require("../agents/coordinator");

function sameKey(got, want) {
  const a = Buffer.from(String(got || ""));
  const b = Buffer.from(String(want || ""));
  return a.length === b.length && a.length > 0 && crypto.timingSafeEqual(a, b);
}

// Krever x-atlas-key = ATLAS_DASH_KEY. Er nøkkelen ikke satt på serveren, slippes alt gjennom (som før).
function requireKey(req, res, next) {
  const want = process.env.ATLAS_DASH_KEY;
  if (!want) return next();
  if (sameKey(req.get("x-atlas-key"), want)) return next();
  res.status(401).json({ success: false, error: "Krever nøkkel" });
}

// POST: krever nøkkel bare hvis ATLAS_POST_KEY er satt, så planlagte oppgaver ikke slutter å virke uten varsel.
function requirePostKey(req, res, next) {
  const post = process.env.ATLAS_POST_KEY;
  if (!post) return next();
  const got = req.get("x-atlas-key");
  if (sameKey(got, post) || sameKey(got, process.env.ATLAS_DASH_KEY)) return next();
  res.status(401).json({ success: false, error: "Krever nøkkel" });
}

function setupCoordinatorRoutes(app) {
  app.get("/api/coordinator/agents", (req, res) => {
    res.json({ success: true, data: coordinator.agentTypes() });
  });

  // Siste ferdige resultat per agent, også etter restart. Brukes til "oppdater meg"-oversikten.
  app.get("/api/coordinator/summary", requireKey, (req, res) => {
    res.json({ success: true, data: coordinator.latest() });
  });

  // "Oppdater meg": samlet morgenoppdatering (gjøremål, e-post, kalender, gull, Make-plassholder).
  app.get("/api/coordinator/briefing", requireKey, (req, res) => {
    const { buildBriefing } = require("../agents/briefing");
    res.json({ success: true, data: buildBriefing(coordinator.latest()) });
  });

  app.get("/api/coordinator/tasks", requireKey, (req, res) => {
    res.json({ success: true, data: coordinator.list() });
  });

  app.get("/api/coordinator/tasks/:id", requireKey, (req, res) => {
    const task = coordinator.get(req.params.id);
    if (!task) return res.status(404).json({ success: false, error: "Ikke funnet" });
    res.json({ success: true, data: task });
  });

  // Saksliste fra ATLAS Rapport. Siden er offentlig, så denne krever nøkkel i headeren x-atlas-key.
  app.get("/api/rapport/saker", async (req, res) => {
    const want = process.env.ATLAS_DASH_KEY;
    if (!want) return res.status(503).json({ success: false, error: "ATLAS_DASH_KEY er ikke satt på serveren" });
    if (!sameKey(req.get("x-atlas-key"), want)) return res.status(401).json({ success: false, error: "Feil nøkkel" });
    try {
      res.set("Cache-Control", "no-store");
      res.json({ success: true, data: await require("../agents/handlers/rapportAgent").getCases() });
    } catch (err) {
      res.status(502).json({ success: false, error: err.message });
    }
  });

  app.post("/api/coordinator/tasks", requirePostKey, (req, res) => {
    const { type, payload } = req.body || {};
    if (!type || !payload || typeof payload !== "object") {
      return res.status(400).json({ success: false, error: "Krever type og payload (objekt)" });
    }
    if (!coordinator.agentTypes().includes(type)) {
      return res.status(400).json({ success: false, error: `Ukjent agenttype: ${type}` });
    }
    const task = coordinator.submit(type, payload);
    res.status(202).json({ success: true, data: task });
  });
}

module.exports = { setupCoordinatorRoutes };
