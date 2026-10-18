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
