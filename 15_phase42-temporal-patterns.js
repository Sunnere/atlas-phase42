class TemporalPatternRecognition {
  constructor() {
    this.events = [];
    this.patterns = [];
    this.currentCycle = 0;
  }

  recordEvent(cycleNumber, agentId, eventType, severity = 0.5) {
    this.events.push({ cycle: cycleNumber, agentId, eventType, severity, timestamp: Date.now() });
    return { recorded: true, eventType, cycle: cycleNumber };
  }

  discoverPattern(sourceEvent, targetEvent, minOccurrences = 2, confidenceThreshold = 0.6) {
    const matches = [];
    for (let i = 0; i < this.events.length - 1; i++) {
      if (this.events[i].eventType === sourceEvent) {
        for (let lag = 1; lag <= 5; lag++) {
          if (i + lag < this.events.length && this.events[i + lag].eventType === targetEvent) {
            matches.push({ sourceIdx: i, targetIdx: i + lag, lag });
          }
        }
      }
    }
    if (matches.length >= minOccurrences) {
      const avgLag = Math.round(matches.reduce((sum, m) => sum + m.lag, 0) / matches.length);
      const confidence = (matches.length / this.events.length) * 100;
      if (confidence >= confidenceThreshold * 100) {
        const avgSeverity = matches.reduce((sum, m) => sum + this.events[m.sourceIdx].severity, 0) / matches.length;
        return { sourceEvent, targetEvent, lag: avgLag, occurrences: matches.length, confidence: Math.round(confidence), avgSeverity: avgSeverity.toFixed(2) };
      }
    }
    return null;
  }

  analyzeAllPatterns() {
    const patterns = [];
    const eventTypes = [...new Set(this.events.map(e => e.eventType))];
    for (const source of eventTypes) {
      for (const target of eventTypes) {
        if (source !== target) {
          const pattern = this.discoverPattern(source, target, 2, 0.6);
          if (pattern) patterns.push(pattern);
        }
      }
    }
    return patterns;
  }

  predictNextCycleEvents() {
    const patterns = this.analyzeAllPatterns();
    const predictions = [];
    for (const pattern of patterns) {
      const lastSource = this.events.filter(e => e.eventType === pattern.sourceEvent).pop();
      if (lastSource && this.currentCycle - lastSource.cycle <= pattern.lag + 1) {
        predictions.push({ expectedEvent: pattern.targetEvent, confidence: pattern.confidence, predictedCycle: this.currentCycle + pattern.lag });
      }
    }
    return predictions;
  }

  generateReport() {
    const patterns = this.analyzeAllPatterns();
    return { totalEvents: this.events.length, totalCycles: this.currentCycle, patternCount: patterns.length, topPatterns: patterns, predictions: this.predictNextCycleEvents() };
  }

  nextCycle() {
    this.currentCycle++;
    return this.currentCycle;
  }
}

module.exports = { TemporalPatternRecognition };
