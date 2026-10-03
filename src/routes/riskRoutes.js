const RiskAgent = require("../agents/RiskAgent");

function setupRiskRoutes(app) {
  const agent = new RiskAgent(process.env.ANTHROPIC_API_KEY);

  app.post("/api/risk/assess", async (req, res) => {
    try {
      const { id, userId, amount, merchant, category, timestamp } = req.body;
      if (!id || !userId || !amount || !merchant || !category) {
        return res.status(400).json({ error: "Missing required fields" });
      }
      const transaction = { id, userId, amount, merchant, category, timestamp: timestamp || Date.now() };
      const assessment = await agent.assessTransaction(transaction);
      res.json({ success: true, data: assessment });
    } catch (error) {
      res.status(500).json({ error: "Risk assessment failed", message: error.message });
    }
  });

  app.get("/api/risk/history/:userId", (req, res) => {
    try {
      const { userId } = req.params;
      const days = parseInt(req.query.days) || 7;
      const history = agent.getHistoricalRisks(userId, days);
      res.json({ success: true, data: { userId, days, history } });
    } catch (error) {
      res.status(500).json({ error: "History retrieval failed" });
    }
  });

  app.get("/api/risk/patterns/:merchant", (req, res) => {
    try {
      const { merchant } = req.params;
      const pattern = agent.getMerchantPattern(merchant);
      if (!pattern) return res.status(404).json({ error: "No pattern data" });
      res.json({ success: true, data: { merchant, pattern } });
    } catch (error) {
      res.status(500).json({ error: "Pattern retrieval failed" });
    }
  });

  app.get("/api/risk/stats", (req, res) => {
    try {
      const txCount = agent.transactionHistory.length;
      const highRiskCount = agent.transactionHistory.filter((tx) => tx.riskAssessment?.riskLevel === "high").length;
      const merchantCount = Object.keys(agent.merchantPatterns).length;
      const averageScore = txCount > 0 ? (agent.transactionHistory.reduce((sum, tx) => sum + (tx.riskAssessment?.riskScore || 0), 0) / txCount).toFixed(1) : 0;
      res.json({ success: true, data: { totalTransactions: txCount, highRiskTransactions: highRiskCount, highRiskPercentage: txCount > 0 ? ((highRiskCount / txCount) * 100).toFixed(1) : 0, merchantPatterns: merchantCount, averageRiskScore: averageScore, lastUpdated: new Date().toISOString() } });
    } catch (error) {
      res.status(500).json({ error: "Stats retrieval failed" });
    }
  });

  return agent;
}

module.exports = { setupRiskRoutes };
