/**
 * Phase 4.6: Dashboard WebSocket Client
 * Real-time connection to /api/risk/stream for live risk updates
 */

class RiskStreamClient {
  constructor(dashboardElement) {
    this.dashboardElement = dashboardElement;
    this.ws = null;
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 5;
    this.reconnectDelay = 2000;
    this.isConnecting = false;
    this.messageBuffer = [];
  }

  /**
   * Connect to WebSocket server
   */
  connect(url = `wss://${window.location.host}/api/risk/stream`) {
    if (this.isConnecting || this.ws) return;

    this.isConnecting = true;
    console.log(`[RiskStream] Connecting to ${url}...`);

    try {
      this.ws = new WebSocket(url);

      this.ws.onopen = () => {
        console.log("[RiskStream] ✅ Connected");
        this.reconnectAttempts = 0;
        this.isConnecting = false;
        this.updateConnectionStatus("connected");
        this.flushMessageBuffer();
      };

      this.ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          this.handleMessage(data);
        } catch (err) {
          console.error("[RiskStream] Message parse error:", err);
        }
      };

      this.ws.onerror = (error) => {
        console.error("[RiskStream] ❌ Error:", error);
        this.updateConnectionStatus("error");
      };

      this.ws.onclose = () => {
        console.log("[RiskStream] Connection closed");
        this.isConnecting = false;
        this.updateConnectionStatus("disconnected");
        this.attemptReconnect();
      };
    } catch (err) {
      console.error("[RiskStream] Connection error:", err);
      this.isConnecting = false;
      this.attemptReconnect();
    }
  }

  /**
   * Handle incoming WebSocket message
   */
  handleMessage(data) {
    switch (data.type) {
      case "history":
        this.handleEventHistory(data.events);
        break;

      case "riskAssessmentStarted":
        this.handleAssessmentStarted(data.event);
        break;

      case "riskAssessmentComplete":
        this.handleAssessmentComplete(data.assessment);
        break;

      case "pong":
        // Heartbeat response
        break;

      default:
        console.warn("[RiskStream] Unknown message type:", data.type);
    }
  }

  /**
   * Handle historical events
   */
  handleEventHistory(events) {
    console.log(`[RiskStream] Received history: ${events.length} events`);
    events.forEach((event) => {
      if (event.type === "riskAssessmentComplete") {
        this.updateRiskDisplay(event.assessment);
      }
    });
  }

  /**
   * Handle assessment started
   */
  handleAssessmentStarted(event) {
    console.log(`[RiskStream] Assessment started for ${event.merchant}`);
    this.showProcessingIndicator(event.webhookId);
  }

  /**
   * Handle assessment completion
   */
  handleAssessmentComplete(assessment) {
    console.log(`[RiskStream] Assessment complete: ${assessment.riskLevel}`);
    this.updateRiskDisplay(assessment);
    this.hideProcessingIndicator(assessment.transactionId);
  }

  /**
   * Update risk display on dashboard
   */
  updateRiskDisplay(assessment) {
    // Find or create risk card
    const cardId = `risk-${assessment.transactionId}`;
    let card = document.getElementById(cardId);

    if (!card) {
      card = document.createElement("div");
      card.id = cardId;
      card.className = "risk-card";

      // Insert at top of dashboard
      const container = this.dashboardElement.querySelector(".risk-updates");
      if (container) {
        container.insertBefore(card, container.firstChild);
      } else {
        this.dashboardElement.appendChild(card);
      }
    }

    // Update card content
    const riskColor = this.getRiskColor(assessment.riskLevel);
    card.innerHTML = `
      <div style="border-left: 4px solid ${riskColor}; padding: 12px; margin: 8px 0; background: rgba(0,0,0,0.05); border-radius: 4px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
          <strong>Transaction ${assessment.transactionId}</strong>
          <span style="background: ${riskColor}; color: white; padding: 2px 8px; border-radius: 3px; font-size: 12px;">
            ${assessment.riskLevel.toUpperCase()} (${assessment.riskScore}/100)
          </span>
        </div>
        <div style="font-size: 13px; color: #666;">
          <div>Recommendation: <strong>${assessment.recommendation}</strong></div>
          <div>${assessment.reasoning}</div>
          <div style="margin-top: 6px; font-size: 11px; color: #999;">
            ${new Date(assessment.timestamp).toLocaleString()}
          </div>
        </div>
      </div>
    `;

    // Auto-remove after 30 seconds (keep showing recent assessments)
    setTimeout(() => {
      card.style.opacity = "0.5";
    }, 15000);
  }

  /**
   * Get risk color
   */
  getRiskColor(riskLevel) {
    switch (riskLevel) {
      case "low":
        return "#10b981"; // green
      case "medium":
        return "#f59e0b"; // amber
      case "high":
        return "#ef4444"; // red
      default:
        return "#6b7280"; // gray
    }
  }

  /**
   * Show processing indicator
   */
  showProcessingIndicator(webhookId) {
    const indicator = document.createElement("div");
    indicator.id = `processing-${webhookId}`;
    indicator.innerHTML = `<div style="padding: 12px; background: #e0e7ff; color: #4f46e5; border-radius: 4px; margin: 8px 0;">
      ⏳ Assessing risk for transaction ${webhookId}...
    </div>`;

    const container = this.dashboardElement.querySelector(".risk-updates");
    if (container) {
      container.insertBefore(indicator, container.firstChild);
    }
  }

  /**
   * Hide processing indicator
   */
  hideProcessingIndicator(transactionId) {
    const indicator = document.getElementById(`processing-${transactionId}`);
    if (indicator) {
      setTimeout(() => indicator.remove(), 500);
    }
  }

  /**
   * Update connection status display
   */
  updateConnectionStatus(status) {
    const statusEl = document.getElementById("risk-stream-status");
    if (!statusEl) return;

    const statusMap = {
      connected: { text: "🟢 Live", color: "#10b981" },
      disconnected: { text: "🔴 Offline", color: "#ef4444" },
      connecting: { text: "🟡 Connecting...", color: "#f59e0b" },
      error: { text: "❌ Error", color: "#ef4444" },
    };

    const info = statusMap[status] || statusMap.disconnected;
    statusEl.textContent = info.text;
    statusEl.style.color = info.color;
  }

  /**
   * Attempt reconnection
   */
  attemptReconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error("[RiskStream] Max reconnect attempts reached");
      this.updateConnectionStatus("error");
      return;
    }

    this.reconnectAttempts++;
    const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);
    console.log(`[RiskStream] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);

    setTimeout(() => {
      this.ws = null;
      this.connect();
    }, delay);
  }

  /**
   * Send heartbeat/ping
   */
  ping() {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({ type: "ping" }));
    }
  }

  /**
   * Buffer messages while reconnecting
   */
  flushMessageBuffer() {
    while (this.messageBuffer.length > 0) {
      const msg = this.messageBuffer.shift();
      this.ws.send(JSON.stringify(msg));
    }
  }

  /**
   * Disconnect gracefully
   */
  disconnect() {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    this.updateConnectionStatus("disconnected");
  }
}

// Auto-initialize when DOM is ready
document.addEventListener("DOMContentLoaded", () => {
  const dashboardEl = document.querySelector(".dashboard");
  if (dashboardEl) {
    window.riskStreamClient = new RiskStreamClient(dashboardEl);
    window.riskStreamClient.connect();

    // Ping every 30 seconds to keep connection alive
    setInterval(() => {
      window.riskStreamClient.ping();
    }, 30000);
  }
});
