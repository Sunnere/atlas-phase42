class SelfOptimizingThresholds {
  constructor() {
    this.agents = {
      'risk-01': { currentThreshold: 0.5, confusionMatrix: { TP: 0, FP: 0, TN: 0, FN: 0 }, outcomesRecorded: 0 },
      'execution-01': { currentThreshold: 0.5, confusionMatrix: { TP: 0, FP: 0, TN: 0, FN: 0 }, outcomesRecorded: 0 },
      'regime-01': { currentThreshold: 0.5, confusionMatrix: { TP: 0, FP: 0, TN: 0, FN: 0 }, outcomesRecorded: 0 }
    };
    this.optimizationHistory = {};
    this.currentCycle = 0;
  }

  recordOutcome(agentId, predictedScore, threshold, decision, actualOutcome) {
    if (!this.agents[agentId]) return null;
    const agent = this.agents[agentId];
    const cm = agent.confusionMatrix;
    if (decision && actualOutcome) cm.TP++;
    else if (decision && !actualOutcome) cm.FP++;
    else if (!decision && !actualOutcome) cm.TN++;
    else cm.FN++;
    agent.outcomesRecorded++;
    return { agentId, recorded: true, outcomeType: (decision && actualOutcome) ? 'TP' : (decision && !actualOutcome) ? 'FP' : (!decision && !actualOutcome) ? 'TN' : 'FN' };
  }

  calculateMetrics(agentId) {
    if (!this.agents[agentId]) return null;
    const cm = this.agents[agentId].confusionMatrix;
    const total = cm.TP + cm.FP + cm.TN + cm.FN;
    return {
      accuracy: total > 0 ? (cm.TP + cm.TN) / total : 0,
      precision: (cm.TP + cm.FP) > 0 ? cm.TP / (cm.TP + cm.FP) : 0,
      recall: (cm.TP + cm.FN) > 0 ? cm.TP / (cm.TP + cm.FN) : 0,
      falsePositiveRate: (cm.FP + cm.TN) > 0 ? cm.FP / (cm.FP + cm.TN) : 0
    };
  }

  optimizeThreshold(agentId, mode = 'balanced') {
    if (!this.agents[agentId]) return null;
    const agent = this.agents[agentId];
    const metrics = this.calculateMetrics(agentId);
    let adjustment = 0;
    if (mode === 'conservative') adjustment = metrics.precision > 0.7 ? 0.01 : -0.01;
    else if (mode === 'aggressive') adjustment = metrics.recall > 0.8 ? 0.03 : -0.02;
    else adjustment = (metrics.accuracy > 0.6 && metrics.recall > 0.7) ? 0.02 : -0.01;
    agent.currentThreshold = Math.max(0, Math.min(1, agent.currentThreshold + adjustment));
    return { agentId, oldThreshold: agent.currentThreshold - adjustment, newThreshold: agent.currentThreshold, adjustment: (adjustment * 100).toFixed(1) + '%' };
  }

  optimizeAllAgents(mode = 'balanced') {
    const results = [];
    for (const agentId in this.agents) {
      results.push(this.optimizeThreshold(agentId, mode));
    }
    return results;
  }

  getOptimizationReport() {
    const report = {};
    for (const agentId in this.agents) {
      const agent = this.agents[agentId];
      const metrics = this.calculateMetrics(agentId);
      report[agentId] = { currentThreshold: agent.currentThreshold, metrics, outcomesRecorded: agent.outcomesRecorded };
    }
    return report;
  }

  nextCycle() {
    this.currentCycle++;
    return this.currentCycle;
  }
}

module.exports = { SelfOptimizingThresholds };
