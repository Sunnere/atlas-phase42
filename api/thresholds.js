export default function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const thresholds = {
    agent_a: { current: 0.65, mode: 'conservative', cycle: 0 },
    agent_b: { current: 0.72, mode: 'balanced', cycle: 0 },
    agent_c: { current: 0.58, mode: 'aggressive', cycle: 0 }
  };

  res.status(200).json({
    thresholds,
    f1Score: '0.8920',
    confusionMatrix: { TP: 89, FP: 11, TN: 150, FN: 50 }
  });
}
