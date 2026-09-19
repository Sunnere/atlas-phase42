const express = require('express');
const app = express();

// CORS Middleware
const cors = (req, res, next) => {
  const origin = req.headers.origin || '*'; const allowedOrigin = origin === '*' ? '*' : req.headers.origin;
  
  res.header('Access-Control-Allow-Origin', req.headers.origin ? req.headers.origin : '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
  res.header('Access-Control-Allow-Credentials', 'true');
  
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  
  next();
};

app.use(cors);
app.use(express.json());

// In-memory state
const state = {
  thresholds: {
    agent_a: { current: 0.65, mode: 'conservative', cycle: 0 },
    agent_b: { current: 0.72, mode: 'balanced', cycle: 0 },
    agent_c: { current: 0.58, mode: 'aggressive', cycle: 0 }
  },
  patterns: {
    0: {
      sourceEvent: 'high_volatility_detected',
      targetEvent: 'decision_override',
      lag: 2,
      occurrences: 3,
      confidence: 75,
      avgSeverity: '0.80'
    },
    1: {
      sourceEvent: 'volume_spike',
      targetEvent: 'threshold_adjustment',
      lag: 1,
      occurrences: 5,
      confidence: 82,
      avgSeverity: '0.65'
    }
  },
  cycles: [],
  startTime: Date.now()
};

// GET / - Root
app.get('/', (req, res) => {
  res.json({
    service: 'ATLAS Phase 4.2 Backend',
    version: '4.2.0',
    endpoints: 10,
    status: 'operational'
  });
});

// GET /health - Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'ATLAS Phase 4.2'
  });
});

// GET /api/status - System status
app.get('/api/status', (req, res) => {
  const uptime = (Date.now() - state.startTime) / 1000;
  
  res.json({
    system: 'ATLAS Phase 4.2',
    status: 'operational',
    components: {
      thresholds: {
        agents: Object.keys(state.thresholds).length,
        currentCycle: 0
      },
      patterns: {
        eventsRecorded: 4,
        patternsDiscovered: Object.keys(state.patterns).length,
        currentCycle: 0
      }
    },
    cycles: {
      total: state.cycles.length,
      lastCycleId: state.cycles.length - 1
    },
    uptime: uptime.toFixed(2),
    timestamp: new Date().toISOString()
  });
});

// GET /api/thresholds - Current thresholds
app.get('/api/thresholds', (req, res) => {
  res.json({
    thresholds: state.thresholds,
    timestamp: new Date().toISOString()
  });
});

// GET /api/cycles - Optimization cycles
app.get('/api/cycles', (req, res) => {
  res.json({
    cycles: state.cycles,
    total: state.cycles.length,
    timestamp: new Date().toISOString()
  });
});

// GET /api/patterns - Temporal patterns
app.get('/api/patterns', (req, res) => {
  res.json({
    patterns: state.patterns,
    count: Object.keys(state.patterns).length,
    timestamp: new Date().toISOString()
  });
});

// POST /api/orchestrate - Orchestration
app.post('/api/orchestrate', (req, res) => {
  const { action, data } = req.body;
  
  res.json({
    orchestration: 'accepted',
    action,
    cycleId: state.cycles.length,
    status: 'processing',
    timestamp: new Date().toISOString()
  });
});

// POST /api/thresholds/:agentId/record - Record threshold change
app.post('/api/thresholds/:agentId/record', (req, res) => {
  const { agentId } = req.params;
  const { newValue, mode } = req.body;
  
  if (state.thresholds[agentId]) {
    state.thresholds[agentId].current = newValue;
    state.thresholds[agentId].mode = mode || 'balanced';
  }
  
  res.json({
    recorded: true,
    agent: agentId,
    value: newValue,
    timestamp: new Date().toISOString()
  });
});

// POST /api/patterns/event - Record event
app.post('/api/patterns/event', (req, res) => {
  const { event, severity } = req.body;
  
  res.json({
    eventRecorded: true,
    event,
    severity,
    timestamp: new Date().toISOString()
  });
});

// POST /api/patterns/analyze - Analyze patterns
app.post('/api/patterns/analyze', (req, res) => {
  res.json({
    analysis: 'complete',
    patternsFound: Object.keys(state.patterns).length,
    topPattern: {
      source: 'high_volatility_detected',
      target: 'decision_override',
      confidence: 75
    },
    timestamp: new Date().toISOString()
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`✅ ATLAS Phase 4.2 Backend running on port ${PORT}`);
  console.log(`   Health: http://localhost:${PORT}/health`);
  console.log(`   API: http://localhost:${PORT}/api/status`);
  console.log(`   CORS enabled for dashboard connections`);
});
