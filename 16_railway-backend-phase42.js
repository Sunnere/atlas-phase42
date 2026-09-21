const express = require('express');
const app = express();

app.use(express.json());

// CORS headers set directly on all responses
app.use((req, res, next) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
  
  // Handle preflight requests
  if (req.method === "OPTIONS") {
    return res.sendStatus(200);
  }
  
  next();
});

// In-memory state storage
const state = {
  thresholds: {
    agent_a: { current: 0.65, mode: 'conservative', cycle: 0 },
    agent_b: { current: 0.72, mode: 'balanced', cycle: 0 },
    agent_c: { current: 0.58, mode: 'aggressive', cycle: 0 }
  },
  patterns: {
    0: { eventId: "bonus_triggered", timestamp: 1726774200000, features: { frequency: 2, recency: 1 }, confidence: 0.89 },
    1: { eventId: "threshold_breach", timestamp: 1726774350000, features: { magnitude: 1.2, consecutive: 2 }, confidence: 0.94 }
  }
};

class SelfOptimizingThresholds {
  constructor() {
    this.agents = { agent_a: {}, agent_b: {}, agent_c: {} };
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
    const agent = state.thresholds[agentId];
    if (f1 < 0.85) {
      agent.current = Math.max(0.5, agent.current - 0.05);
    } else if (f1 > 0.95) {
      agent.current = Math.min(0.95, agent.current + 0.05);
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

// API Routes
app.get('/api/status', (req, res) => {
  res.json({
    system: 'ATLAS Phase 4.2',
    status: 'operational',
    components: {
      thresholds: { agents: Object.keys(state.thresholds).length, currentCycle: state.cycles?.currentCycle || 0 },
      patterns: { eventsRecorded: state.patterns ? Object.keys(state.patterns).length : 0, patternsDiscovered: 1, currentCycle: 0 }
    },
    cycles: { total: 0, lastCycleId: -1 },
    uptime: (Date.now() / 1000).toFixed(2),
    timestamp: new Date().toISOString()
  });
});

app.get('/api/cycles', (req, res) => {
  res.json({
    cycles: [],
    currentCycle: state.cycles?.currentCycle || 0,
    message: 'No active cycles'
  });
});

app.get('/api/patterns', (req, res) => {
  res.json({
    patterns: Object.entries(state.patterns).map(([id, p]) => ({ id: parseInt(id), ...p })),
    count: Object.keys(state.patterns).length,
    lastAnalysis: new Date().toISOString()
  });
});

app.get('/api/thresholds', (req, res) => {
  res.json({
    thresholds: state.thresholds,
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
    newThreshold: state.thresholds[agentId].current,
    f1Score: optimizer.getF1Score().toFixed(4),
    confusionMatrix: optimizer.confusionMatrix
  });
});

app.post('/api/patterns/event', (req, res) => {
  const { eventId, timestamp } = req.body;
  const analysis = temporal.analyzeEvent(eventId, timestamp);

  res.json({
    analysis,
    lagBins: temporal.lagBins,
    message: 'Event analyzed'
  });
});

app.post('/api/patterns/analyze', (req, res) => {
  const { events } = req.body;
  
  res.json({
    patternsFound: Math.floor(Math.random() * 5),
    confidence: (Math.random() * 0.5 + 0.5).toFixed(2),
    recommendation: 'Review patterns in dashboard'
  });
});

app.get('/api/orchestrate', (req, res) => {
  res.json({
    orchestration: 'Phase 4.2 active',
    agents: 3,
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
  console.log(`ATLAS Phase 4.2 backend running on port ${PORT}`);
});

module.exports = app;
