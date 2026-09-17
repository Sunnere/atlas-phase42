const express = require('express');
const { SelfOptimizingThresholds } = require('./14_phase42-self-optimizing-thresholds');
const { TemporalPatternRecognition } = require('./15_phase42-temporal-patterns');

const app = express();
app.use(express.json());

const thresholds = new SelfOptimizingThresholds();
const patterns = new TemporalPatternRecognition();
let cycles = [];

// Initialize with test data
thresholds.recordOutcome('risk-01', 0.92, 0.5, true, true);
thresholds.recordOutcome('risk-01', 0.45, 0.5, false, false);
thresholds.recordOutcome('execution-01', 0.78, 0.5, true, true);
thresholds.recordOutcome('regime-01', 0.88, 0.5, true, true);
for (let i = 0; i < 6; i++) {
  thresholds.recordOutcome('risk-01', Math.random() * 1, 0.5, Math.random() > 0.5, Math.random() > 0.4);
  thresholds.recordOutcome('execution-01', Math.random() * 1, 0.5, Math.random() > 0.5, Math.random() > 0.3);
  thresholds.recordOutcome('regime-01', Math.random() * 1, 0.5, Math.random() > 0.5, Math.random() > 0.3);
}
patterns.recordEvent(0, 'risk-01', 'high_volatility_detected', 0.8);
patterns.recordEvent(1, 'risk-01', 'decision_override', 0.75);
patterns.recordEvent(2, 'risk-01', 'high_volatility_detected', 0.8);
patterns.recordEvent(3, 'risk-01', 'decision_override', 0.75);

const startTime = Date.now();

app.get('/', (req, res) => {
  const report = thresholds.getOptimizationReport();
  const patternReport = patterns.generateReport();
  res.send(`<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>ATLAS Phase 4.2 Dashboard</title><style>body{font-family:sans-serif;background:#0a0e27;color:#0ff;margin:0;padding:20px}h1{color:#0f0;text-align:center}h2{color:#0ff;margin-top:30px;border-bottom:2px solid #0ff;padding-bottom:10px}.metric{display:inline-block;margin:20px;padding:15px;background:#1a1f3a;border:1px solid #0ff;border-radius:8px;min-width:200px}.metric-value{font-size:24px;color:#0f0;font-weight:bold}.metric-label{color:#0ff;font-size:12px;margin-top:5px}.pattern{background:#1a2a3a;border-left:4px solid #0f0;padding:10px;margin:10px 0}.pattern-title{color:#0f0;font-weight:bold}.pattern-detail{color:#0ff;font-size:12px;margin-top:5px}.status{text-align:center;padding:10px;background:#0a3a0a;color:#0f0;border-radius:4px;margin:20px 0}.refresh-btn{padding:10px 20px;background:#0f0;color:#000;border:none;border-radius:4px;cursor:pointer;font-weight:bold}</style></head><body><h1>🚀 ATLAS Phase 4.2 Dashboard</h1><div class="status">✅ System Healthy - Real-time Monitoring Active</div><div class="metric"><div class="metric-value">${cycles.length}</div><div class="metric-label">Total Cycles</div></div><div class="metric"><div class="metric-value">3</div><div class="metric-label">Active Agents</div></div><div class="metric"><div class="metric-value">${patternReport.patternCount}</div><div class="metric-label">Discovered Patterns</div></div><div class="metric"><div class="metric-value">${patternReport.totalEvents}</div><div class="metric-label">Events Recorded</div></div><h2>📊 Agent Thresholds</h2>${Object.entries(report).map(([id, data]) => `<div class="metric"><div class="metric-label">${id}</div><div class="metric-value">${data.currentThreshold.toFixed(3)}</div><div class="metric-detail">Accuracy: ${(data.metrics.accuracy * 100).toFixed(1)}% | Recall: ${(data.metrics.recall * 100).toFixed(1)}%</div></div>`).join('')}<h2>🔗 Temporal Patterns</h2>${patternReport.topPatterns.map(p => `<div class="pattern"><div class="pattern-title">${p.sourceEvent} → ${p.targetEvent}</div><div class="pattern-detail">Lag: ${p.lag} cycles | Confidence: ${p.confidence}% | Occurrences: ${p.occurrences}</div></div>`).join('') || '<div class="pattern">No patterns discovered yet</div>'}<div style="text-align:center;margin-top:30px"><button class="refresh-btn" onclick="location.reload()">🔄 Refresh</button></div><script>setInterval(() => location.reload(), 10000);</script></body></html>`);
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'ATLAS Phase 4.2' });
});

app.get('/api/status', (req, res) => {
  res.json({
    system: 'ATLAS Phase 4.2',
    status: 'operational',
    components: {
      thresholds: { agents: Object.keys(thresholds.agents).length, currentCycle: thresholds.currentCycle },
      patterns: { eventsRecorded: patterns.events.length, patternsDiscovered: patterns.analyzeAllPatterns().length, currentCycle: patterns.currentCycle }
    },
    cycles: { total: cycles.length, lastCycleId: cycles.length - 1 },
    uptime: ((Date.now() - startTime) / 1000).toFixed(2),
    timestamp: new Date().toISOString()
  });
});

app.post('/api/orchestrate', (req, res) => {
  const cycleId = cycles.length;
  const { agents: agentList = ['risk-01', 'execution-01'], events: eventList = [] } = req.body;
  cycles.push({ id: cycleId, timestamp: new Date().toISOString(), agents: agentList, eventCount: eventList.length });
  thresholds.nextCycle();
  patterns.nextCycle();
  res.json({ success: true, cycle: cycleId, message: 'Orchestration cycle started', timestamp: new Date().toISOString() });
});

app.get('/api/cycles', (req, res) => {
  res.json({ totalCycles: cycles.length, cycles });
});

app.get('/api/thresholds', (req, res) => {
  const report = thresholds.getOptimizationReport();
  res.json({ totalAgents: Object.keys(report).length, agents: report });
});

app.post('/api/thresholds/:agentId/record', (req, res) => {
  const { agentId } = req.params;
  const { predictedScore, threshold, decision, actualOutcome } = req.body;
  const result = thresholds.recordOutcome(agentId, predictedScore, threshold, decision, actualOutcome);
  res.json({ success: !!result, message: 'Outcome recorded', agentId, decision, actualOutcome });
});

app.get('/api/patterns', (req, res) => {
  const patternList = patterns.analyzeAllPatterns();
  res.json({ totalPatterns: patternList.length, patterns: patternList });
});

app.post('/api/patterns/event', (req, res) => {
  const { cycleNumber, agentId, eventType, severity = 0.5 } = req.body;
  const result = patterns.recordEvent(cycleNumber, agentId, eventType, severity);
  res.json({ success: !!result, message: 'Event recorded', eventType, agentId, cycleNumber });
});

app.post('/api/patterns/analyze', (req, res) => {
  const discovered = patterns.analyzeAllPatterns();
  res.json({ success: true, message: 'Pattern analysis complete', patternsDiscovered: discovered.length, topPatterns: discovered });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`\n✅ ATLAS Phase 4.2 Backend running on http://localhost:${PORT}\n`);
  console.log('Endpoints:');
  console.log(`  Dashboard: GET http://localhost:${PORT}/`);
  console.log(`  Status: GET http://localhost:${PORT}/api/status`);
  console.log(`  Thresholds: GET http://localhost:${PORT}/api/thresholds`);
  console.log(`  Patterns: GET http://localhost:${PORT}/api/patterns`);
  console.log(`  Orchestrate: POST http://localhost:${PORT}/api/orchestrate\n`);
  console.log('Press Ctrl+C to stop.\n');
});
