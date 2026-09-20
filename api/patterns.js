export default function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const patterns = {
    0: { eventId: "bonus_triggered", timestamp: 1726774200000, features: { frequency: 2, recency: 1 }, confidence: 0.89 },
    1: { eventId: "threshold_breach", timestamp: 1726774350000, features: { magnitude: 1.2, consecutive: 2 }, confidence: 0.94 }
  };

  res.status(200).json({
    patterns: Object.entries(patterns).map(([id, p]) => ({ id: parseInt(id), ...p })),
    count: Object.keys(patterns).length,
    lastAnalysis: new Date().toISOString()
  });
}
