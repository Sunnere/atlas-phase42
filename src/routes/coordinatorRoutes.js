const coordinator = require("../agents/coordinator");

function setupCoordinatorRoutes(app) {
  app.get("/api/coordinator/agents", (req, res) => {
    res.json({ success: true, data: coordinator.agentTypes() });
  });

  // Siste ferdige resultat per agent, også etter restart. Brukes til "oppdater meg"-oversikten.
  app.get("/api/coordinator/summary", (req, res) => {
    res.json({ success: true, data: coordinator.latest() });
  });

  // "Oppdater meg": samlet morgenoppdatering (gjøremål, e-post, kalender, gull, Make-plassholder).
  app.get("/api/coordinator/briefing", (req, res) => {
    const { buildBriefing } = require("../agents/briefing");
    res.json({ success: true, data: buildBriefing(coordinator.latest()) });
  });

  app.get("/api/coordinator/tasks", (req, res) => {
    res.json({ success: true, data: coordinator.list() });
  });

  app.get("/api/coordinator/tasks/:id", (req, res) => {
    const task = coordinator.get(req.params.id);
    if (!task) return res.status(404).json({ success: false, error: "Ikke funnet" });
    res.json({ success: true, data: task });
  });

  // Saksliste fra ATLAS Rapport. Siden er offentlig, så denne krever nøkkel i headeren x-atlas-key.
  app.get("/api/rapport/saker", async (req, res) => {
    const want = process.env.ATLAS_DASH_KEY;
    if (!want) return res.status(503).json({ success: false, error: "ATLAS_DASH_KEY er ikke satt på serveren" });
    const crypto = require("crypto");
    const got = Buffer.from(String(req.get("x-atlas-key") || ""));
    const exp = Buffer.from(want);
    if (got.length !== exp.length || !crypto.timingSafeEqual(got, exp)) {
      return res.status(401).json({ success: false, error: "Feil nøkkel" });
    }
    try {
      res.set("Cache-Control", "no-store");
      res.json({ success: true, data: await require("../agents/handlers/rapportAgent").getCases() });
    } catch (err) {
      res.status(502).json({ success: false, error: err.message });
    }
  });

  app.post("/api/coordinator/tasks", (req, res) => {
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
