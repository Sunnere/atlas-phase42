/**
 * Phase 4.6: Webhook Listener & Real-Time Event Streaming
 * Handles external risk event webhooks and broadcasts to connected WebSocket clients
 */

const WebSocket = require("ws");
const EventEmitter = require("events");

class WebhookListener extends EventEmitter {
  constructor(httpServer) {
    super();
    this.httpServer = httpServer;
    this.wss = null;
    this.eventQueue = [];
    this.clients = new Set();
    this.eventHistory = [];
    this.maxHistorySize = 100;
    this.isProcessing = false;
  }

  initialize() {
    this.wss = new WebSocket.Server({ server: this.httpServer, path: "/api/risk/stream" });

    this.wss.on("connection", (ws) => {
      console.log("✅ WebSocket client connected");
      this.clients.add(ws);

      ws.send(
        JSON.stringify({
          type: "history",
          events: this.eventHistory.slice(-20),
          timestamp: new Date().toISOString(),
        })
      );

      ws.on("message", (msg) => {
        try {
          const data = JSON.parse(msg);
          if (data.type === "ping") {
            ws.send(JSON.stringify({ type: "pong", timestamp: new Date().toISOString() }));
          }
        } catch (e) {
          console.error("WebSocket message parse error:", e.message);
        }
      });

      ws.on("close", () => {
        console.log("✅ WebSocket client disconnected");
        this.clients.delete(ws);
      });

      ws.on("error", (err) => {
        console.error("WebSocket error:", err.message);
        this.clients.delete(ws);
      });
    });

    console.log("✅ WebSocket server initialized at /api/risk/stream");
  }

  handleWebhookEvent(eventData) {
    const event = {
      webhookId: eventData.id || `webhook-${Date.now()}`,
      transactionId: eventData.id,
      userId: eventData.userId,
      amount: eventData.amount,
      merchant: eventData.merchant,
      category: eventData.category,
      timestamp: eventData.timestamp || Date.now(),
      priority: eventData.priority || "normal",
      receivedAt: Date.now(),
      status: "queued",
    };

    this.eventQueue.push(event);
    this.sortEventQueue();
    this.processQueue();

    return event;
  }

  sortEventQueue() {
    const priorityOrder = { high: 0, normal: 1, low: 2 };
    this.eventQueue.sort(
      (a, b) => priorityOrder[a.priority] - priorityOrder[b.priority]
    );
  }

  async processQueue() {
    if (this.isProcessing || this.eventQueue.length === 0) return;

    this.isProcessing = true;

    while (this.eventQueue.length > 0) {
      const event = this.eventQueue.shift();

      try {
        this.emit("assessmentRequired", event);
        event.status = "processing";

        this.broadcast({
          type: "riskAssessmentStarted",
          event,
          timestamp: new Date().toISOString(),
        });
      } catch (err) {
        console.error("Error processing webhook event:", err);
        event.status = "error";
        event.error = err.message;
      }

      await new Promise((resolve) => setTimeout(resolve, 10));
    }

    this.isProcessing = false;
  }

  notifyAssessmentComplete(webhookId, riskAssessment) {
    const event = {
      type: "riskAssessmentComplete",
      webhookId,
      assessment: riskAssessment,
      timestamp: new Date().toISOString(),
    };

    this.eventHistory.push(event);
    if (this.eventHistory.length > this.maxHistorySize) {
      this.eventHistory.shift();
    }

    this.broadcast(event);
  }

  broadcast(message) {
    const msgStr = JSON.stringify(message);
    let successCount = 0;

    for (const client of this.clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(msgStr);
        successCount++;
      }
    }

    if (successCount > 0) {
      console.log(`📡 Broadcasted to ${successCount} clients:`, message.type);
    }
  }

  getStats() {
    return {
      connectedClients: this.clients.size,
      queuedEvents: this.eventQueue.length,
      eventHistorySize: this.eventHistory.length,
      wsServerRunning: this.wss !== null,
    };
  }
}

module.exports = WebhookListener;
