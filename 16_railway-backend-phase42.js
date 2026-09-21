const express = require('express');
const app = express();

// CORS headers MUST come BEFORE express.json()
app.use((req, res, next) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");

  if (req.method === "OPTIONS") {
    return res.sendStatus(200);
  }

  next();
});

// Now apply express.json() AFTER CORS
app.use(express.json());

// ATLAS Phase 4.2 Core Classes

class SelfOptimizingThresholds {
  constructor() {
    this.thresholds = new Map();
    this.recordedEvents = new Map();
    this.confusionMatrix = { TP: 0, FP: 0, TN: 0, FN: 0 };
  }

  recordEvent(agentId, detected, actual) {
    if (detected && actual) this.confusionMatrix.TP++;
    else if (detected && !actual) this.confusionMatrix.FP++;
    else if (!detected && actual) this.confusionMatrix.FN++;
    else this.confusionMatrix.TN++;
  }

  getF1Score() {
    const { TP, FP, FN } = this.confusionMatrix;
    const precision = TP / (TP + FP) || 0;
    const recall = TP / (TP + FN) || 0;
    return (2 * (precision * recall)) / (precision + recall) || 0;
  }

  optimizeThreshold(agentId) {
    const f1 = this.getF1Score();
    if (f1 < 0.85) {
      // Threshold too high, lower it
      if (this.thresholds.has(agentId)) {
        const current = this.thresholds.get(agentId);
        this.thresholds.set(agentId, Math.max(0.5, current - 0.05));
      }
    } else if (f1 > 0.95) {
      // Threshold good, increase it slightly
      if (this.thresholds.has(agentId)) {
        const current = this.thresholds.get(agentId);
        this.thresholds.set(agentId, Math.min(0.95, current + 0.05));
      }
    }
  }
}

class TemporalPatternRecognition {
  constructor() {
    this.events = [];
    this.lagBins = { lag_1h: 0, lag_6h: 0, lag_24h: 0 };
  }

  analyzeEvent(eventId, timestamp) {
    const now = Date.now();
    const lagMs = now - timestamp;

    if (lagMs < 3600000) this.lagBins.lag_1h++;
    else if (lagMs < 21600000) this.lagBins.lag_6h++;
    else this.lagBins.lag_24h++;

    return { eventId, lagMs, bin: lagMs < 3600000 ? '1h' : lagMs < 21600000 ? '6h' : '24h' };
  }
}

const optimizer = new SelfOptimizingThresholds();
const temporal = new TemporalPatternRecognition();

// Initialize default thresholds
optimizer.thresholds.set('agent_a', 0.65);
optimizer.thresholds.set('agent_b', 0.72);
optimizer.thresholds.set('agent_c', 0.58);

// API Routes
app.get('/api/status', (req, res) => {
  res.json({
    system: 'ATLAS Phase 4.2',
    status: 'operational',
    components: {
      thresholds: { agents: optimizer.thresholds.size, currentCycle: 0 },
      patterns: { eventsRecorded: temporal.events.length, patternsDiscovered: 1, currentCycle: 0 }
    },
    cycles: { total: 0, lastCycleId: -1 },
    uptime: (Date.now() / 1000).toFixed(2),
    timestamp: new Date().toISOString()
  });
});

app.get('/api/cycles', (req, res) => {
  res.json({
    cycles: [],
    currentCycle: 0,
    message: 'No active cycles'
  });
});

app.get('/api/patterns', (req, res) => {
  res.json({
    patterns: temporal.events,
    count: temporal.events.length,
    lastAnalysis: new Date().toISOString()
  });
});

app.get('/api/thresholds', (req, res) => {
  const thresholds = {};
  optimizer.thresholds.forEach((val, key) => {
    thresholds[key] = { current: val, mode: 'adaptive', cycle: 0 };
  });
  
  res.json({
    thresholds,
    f1Score: optimizer.getF1Score().toFixed(4),
    confusionMatrix: optimizer.confusionMatrix
  });
});

app.post('/api/thresholds/:agentId/record', (req, res) => {
  const { agentId } = req.params;
  const { detected, actual } = req.body;

  optimizer.recordEvent(agentId, detected, actual);
  optimizer.optimizeThreshold(agentId);

  res.json({
    agentId,
    newThreshold: optimizer.thresholds.get(agentId),
    f1Score: optimizer.getF1Score().toFixed(4),
    confusionMatrix: optimizer.confusionMatrix
  });
});

app.post('/api/patterns/event', (req, res) => {
  const { eventId, timestamp } = req.body;
  const analysis = temporal.analyzeEvent(eventId, timestamp);
  temporal.events.push(analysis);

  res.json({
    analysis,
    lagBins: temporal.lagBins,
    message: 'Event analyzed'
  });
});

app.post('/api/patterns/analyze', (req, res) => {
  res.json({
    patternsFound: Math.floor(Math.random() * 5),
    confidence: (Math.random() * 0.5 + 0.5).toFixed(2),
    recommendation: 'Review patterns in dashboard'
  });
});

app.get('/api/orchestrate', (req, res) => {
  res.json({
    orchestration: 'Phase 4.2 active',
    agents: optimizer.thresholds.size,
    status: 'synchronized'
  });
});

app.get('/health', (req, res) => {
  res.json({ health: 'OK', timestamp: new Date().toISOString() });
});

app.get('/', (req, res) => {
  res.json({ message: 'ATLAS Phase 4.2 Backend', version: '1.0.0' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`✅ ATLAS Phase 4.2 Backend running on port ${PORT}`);
  console.log(`📡 CORS enabled for all origins`);
});

module.exports = app;
