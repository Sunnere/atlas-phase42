export default function handler(req, res) {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Origin');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  res.status(200).json({
    system: 'ATLAS Phase 4.2',
    status: 'operational',
    components: {
      thresholds: { agents: 3, currentCycle: 0 },
      patterns: { eventsRecorded: 4, patternsDiscovered: 1, currentCycle: 0 }
    },
    cycles: { total: 0, lastCycleId: -1 },
    uptime: (Date.now() / 1000).toFixed(2),
    timestamp: new Date().toISOString()
  });
}
