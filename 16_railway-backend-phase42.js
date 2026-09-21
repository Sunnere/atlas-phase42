const express = require('express');
const cors = require('cors');
const app = express();
const port = process.env.PORT || 8080;

// CORS FIRST - using npm cors package (more reliable than manual headers)
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Origin', 'X-Requested-With', 'Content-Type', 'Accept']
}));

app.use(express.json());

// ============================================================
// REST OF CODE (same as before)
// ============================================================
class SelfOptimizingThresholds {
  constructor() {
    this.thresholds = { agent_a: 0.5, agent_b: 0.5, agent_c: 0.5 };
    this.performanceHistory = [];
  }

  optimize(agentName, f1Score) {
    const history = this.performanceHistory.find(h => h.agent === agentName);
    if (history) {
      history.f1Scores.push(f1Score);
    } else {
      this.performanceHistory.push({ agent: agentName, f1Scores: [f1Score] });
    }

    const avgF1 = history.f1Scores.reduce((a, b) => a + b, 0) / history.f1Scores.length;
    this.thresholds[agentName] = Math.max(0.3, Math.min(0.9, avgF1));
  }

  getThreshold(agentName) {
    return this.thresholds[agentName] || 0.5;
  }
}

class TemporalPatternRecognition {
  constructor() {
    this.patterns = {};
    this.eventLags = [];
  }

  recordEvent(timestamp, eventType) {
    const key = eventType;
    if (!this.patterns[key]) {
      this.patterns[key] = [];
    }
    this.patterns[key].push(timestamp);
  }

  analyzeLag(eventType) {
    const events = this.patterns[eventType] || [];
    if (events.length < 2) return null;

    const lags = [];
    for (let i = 1; i < events.length; i++) {
      lags.push(events[i] - events[i - 1]);
    }
    const avgLag = lags.reduce((a, b) => a + b, 0) / lags.length;
    return { count: events.length, avgLag, lastEvent: events[events.length - 1] };
  }

  getPatterns() {
    const result = {};
    Object.keys(this.patterns).forEach(key => {
      result[key] = this.analyzeLag(key);
    });
    return result;
  }
}

const thresholds = new SelfOptimizingThresholds();
const patterns = new TemporalPatternRecognition();

let systemState = {
  cycles: 0,
  lastCycleId: -1,
  startTime: Date.now(),
  agents: {
    agent_a: { cycles: 0, events: 0, f1Score: 0.75 },
    agent_b: { cycles: 0, events: 0, f1Score: 0.82 },
    agent_c: { cycles: 0, events: 0, f1Score: 0.68 }
  }
};

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/api/status', (req, res) => {
  res.json({
    system: 'ATLAS Phase 4.2',
    status: 'operational',
    components: {
      thresholds: {
        agents: Object.keys(systemState.agents).length,
        currentCycle: systemState.cycles
      },
      patterns: {
        eventsRecorded: Object.values(patterns.patterns).flat().length,
        patternsDiscovered: Object.keys(patterns.patterns).length,
        currentCycle: systemState.cycles
      }
    },
    cycles: {
      total: systemState.cycles,
      lastCycleId: systemState.lastCycleId
    },
    uptime: ((Date.now() - systemState.startTime) / 1000).toFixed(2),
    timestamp: new Date().toISOString()
  });
});

app.get('/api/cycles', (req, res) => {
  res.json({
    total: systemState.cycles,
    lastCycleId: systemState.lastCycleId,
    agents: systemState.agents,
    timestamp: new Date().toISOString()
  });
});

app.get('/api/patterns', (req, res) => {
  res.json({
    patterns: patterns.getPatterns(),
    totalEvents: Object.values(patterns.patterns).flat().length,
    timestamp: new Date().toISOString()
  });
});

app.get('/api/thresholds', (req, res) => {
  res.json({
    thresholds: thresholds.thresholds,
    performanceHistory: thresholds.performanceHistory,
    timestamp: new Date().toISOString()
  });
});

app.post('/api/optimize', (req, res) => {
  const { agent, f1Score } = req.body;
  if (!agent || f1Score === undefined) {
    return res.status(400).json({ error: 'agent and f1Score required' });
  }
  thresholds.optimize(agent, f1Score);
  res.json({ message: 'Threshold optimized', threshold: thresholds.getThreshold(agent) });
});

app.post('/api/patterns/record', (req, res) => {
  const { eventType } = req.body;
  if (!eventType) {
    return res.status(400).json({ error: 'eventType required' });
  }
  patterns.recordEvent(Date.now(), eventType);
  res.json({ message: 'Event recorded', eventType });
});

app.post('/api/orchestrate', (req, res) => {
  systemState.cycles++;
  systemState.lastCycleId = systemState.cycles - 1;
  Object.keys(systemState.agents).forEach(agent => {
    systemState.agents[agent].cycles++;
  });
  res.json({
    message: 'Orchestration cycle completed',
    cycleId: systemState.lastCycleId,
    timestamp: new Date().toISOString()
  });
});

app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head><title>ATLAS Phase 4.2</title></head>
    <body style="font-family:monospace; background:#1a1a1a; color:#0f0;">
      <h1>✅ ATLAS Phase 4.2 Backend</h1>
      <p>Status: <strong>Operational</strong></p>
      <p>System: Self-Optimizing Thresholds + Temporal Pattern Recognition</p>
      <h2>API Endpoints:</h2>
      <ul>
        <li>GET /api/status - System status</li>
        <li>GET /api/cycles - Cycle information</li>
        <li>GET /api/patterns - Pattern analysis</li>
        <li>GET /api/thresholds - Threshold values</li>
        <li>POST /api/optimize - Optimize thresholds</li>
        <li>POST /api/patterns/record - Record event</li>
        <li>POST /api/orchestrate - Run cycle</li>
      </ul>
    </body>
    </html>
  `);
});

app.listen(port, () => {
  console.log(`✅ ATLAS Phase 4.2 Backend running on http://localhost:${port}`);
  console.log('');
  console.log('Endpoints:');
  console.log(`  Dashboard: GET http://localhost:${port}/`);
  console.log(`  Status: GET http://localhost:${port}/api/status`);
  console.log(`  Thresholds: GET http://localhost:${port}/api/thresholds`);
  console.log(`  Patterns: GET http://localhost:${port}/api/patterns`);
  console.log(`  Orchestrate: POST http://localhost:${port}/api/orchestrate`);
  console.log('');
  console.log('Press Ctrl+C to stop.');
  console.log('');
});
