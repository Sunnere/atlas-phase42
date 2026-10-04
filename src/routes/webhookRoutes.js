/**
 * Phase 4.6: Webhook Routes
 * External API for triggering risk assessments
 */

function setupWebhookRoutes(app, webhookListener, riskAgentModule) {
  // Get RiskAgent class
  const RiskAgent = riskAgentModule;

  /**
   * POST /api/webhooks/risk-event
   * Trigger risk assessment via webhook
   */
  app.post("/api/webhooks/risk-event", async (req, res) => {
    try {
      const { id, userId, amount, merchant, category, timestamp, priority } = req.body;

      if (!id || !userId || !amount || !merchant || !category) {
        return res.status(400).json({
          error: "Missing required fields: id, userId, amount, merchant, category",
        });
      }

      // Enqueue webhook event
      const queuedEvent = webhookListener.handleWebhookEvent({
        id,
        userId,
        amount,
        merchant,
        category,
        timestamp,
        priority,
      });

      res.json({
        success: true,
        webhookId: queuedEvent.webhookId,
        status: queuedEvent.status,
        message: "Risk assessment queued for processing",
      });
    } catch (error) {
      console.error("Webhook error:", error);
      res.status(500).json({
        error: "Webhook processing failed",
        message: error.message,
      });
    }
  });

  /**
   * GET /api/webhooks/stats
   */
  app.get("/api/webhooks/stats", (req, res) => {
    try {
      const stats = webhookListener.getStats();
      res.json({
        success: true,
        data: stats,
      });
    } catch (error) {
      res.status(500).json({
        error: "Failed to retrieve webhook stats",
        message: error.message,
      });
    }
  });

  // Listen for assessment completion
  webhookListener.on("assessmentRequired", async (event) => {
    try {
      const agent = new RiskAgent(process.env.ANTHROPIC_API_KEY);
      const assessment = await agent.assessTransaction({
        id: event.transactionId,
        userId: event.userId,
        amount: event.amount,
        merchant: event.merchant,
        category: event.category,
        timestamp: event.timestamp,
      });

      webhookListener.notifyAssessmentComplete(event.webhookId, assessment);
    } catch (err) {
      console.error("Assessment processing error:", err);
      webhookListener.notifyAssessmentComplete(event.webhookId, {
        transactionId: event.transactionId,
        riskScore: 50,
        riskLevel: "medium",
        recommendation: "MONITOR",
        factors: { error: err.message },
        reasoning: "Assessment failed",
        timestamp: new Date().toISOString(),
      });
    }
  });

  console.log("✅ Webhook routes initialized");
}

module.exports = { setupWebhookRoutes };
