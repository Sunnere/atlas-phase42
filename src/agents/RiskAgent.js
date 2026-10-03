/**
 * Phase 4.5: Risk Agent — AI-driven risk scoring & pattern detection
 * Analyzes transaction patterns, detects anomalies, assigns risk scores
 */

const Anthropic = require("@anthropic-ai/sdk");

class RiskAgent {
  constructor(apiKey) {
    this.client = new Anthropic({ apiKey });
    this.transactionHistory = [];
    this.merchantPatterns = {};
    this.thresholds = {
      velocityHigh: 10,
      amountStdDev: 2.5,
      riskScoreHigh: 70,
    };
  }

  async assessTransaction(transaction) {
    const { id, amount, merchant, category, timestamp = Date.now(), userId } = transaction;
    const context = this.gatherContext(userId, merchant, category);
    const signals = this.calculateSignals(transaction, context.recentTransactions);
    const aiAnalysis = await this.analyzeWithClaude(transaction, context, signals);
    const riskAssessment = this.synthesizeRiskScore(signals, aiAnalysis, transaction);
    this.recordTransaction(transaction, riskAssessment);
    return riskAssessment;
  }

  gatherContext(userId, merchant, category) {
    const now = Date.now();
    const sevenDaysAgo = now - 7 * 24 * 60 * 60 * 1000;
    const recentTransactions = this.transactionHistory.filter((tx) => tx.userId === userId && tx.timestamp >= sevenDaysAgo && tx.timestamp <= now);
    const merchantTxs = recentTransactions.filter((tx) => tx.merchant === merchant);
    const categoryTxs = recentTransactions.filter((tx) => tx.category === category);

    return {
      userId, merchant, category, recentTransactions, merchantTxs, categoryTxs,
      merchantPattern: this.merchantPatterns[merchant] || null,
      transactionCount7d: recentTransactions.length,
      merchantCount7d: merchantTxs.length,
      categoryCount7d: categoryTxs.length,
    };
  }

  calculateSignals(transaction, recentTxs) {
    const { amount, merchant, category, timestamp } = transaction;
    const past24h = timestamp - 24 * 60 * 60 * 1000;
    const recentTxCount = recentTxs.filter((tx) => tx.timestamp >= past24h).length;
    const velocityScore = Math.min(100, (recentTxCount / this.thresholds.velocityHigh) * 100);

    const merchantAmounts = recentTxs.filter((tx) => tx.merchant === merchant).map((tx) => tx.amount);
    const avgAmount = merchantAmounts.length > 0 ? merchantAmounts.reduce((a, b) => a + b, 0) / merchantAmounts.length : amount;
    const stdDev = merchantAmounts.length > 1 ? Math.sqrt(merchantAmounts.reduce((sum, val) => sum + Math.pow(val - avgAmount, 2), 0) / (merchantAmounts.length - 1)) : 0;
    const zScore = stdDev > 0 ? Math.abs((amount - avgAmount) / stdDev) : 0;
    const amountAnomalyScore = Math.min(100, (zScore / this.thresholds.amountStdDev) * 100);

    const merchantFrequency = recentTxs.filter((tx) => tx.merchant === merchant).length;
    const isNewMerchant = merchantFrequency === 0;
    const newMerchantScore = isNewMerchant ? 40 : 0;

    const txHour = new Date(timestamp).getHours();
    const businessHours = txHour >= 9 && txHour <= 17;
    const timeAnomalyScore = !businessHours ? 20 : 0;

    return { velocityScore, amountAnomalyScore, newMerchantScore, timeAnomalyScore, zScore, merchantFrequency, avgMerchantAmount: avgAmount, isNewMerchant, businessHours };
  }

  async analyzeWithClaude(transaction, context, signals) {
    const prompt = `You are a fraud risk analyst. Analyze this transaction and context to assess anomaly likelihood.

TRANSACTION:
- Amount: ${transaction.amount} NOK
- Merchant: ${transaction.merchant}
- Category: ${transaction.category}
- Timestamp: ${new Date(transaction.timestamp).toISOString()}

CONTEXT (7-day window):
- Total transactions for user: ${context.transactionCount7d}
- Merchant transactions: ${context.merchantCount7d}

STATISTICAL SIGNALS:
- Velocity score: ${signals.velocityScore.toFixed(0)}/100
- Amount anomaly (Z-score): ${signals.zScore.toFixed(2)}
- New merchant: ${signals.isNewMerchant ? "YES" : "NO"}
- Time anomaly: ${!signals.businessHours ? "YES (off-hours)" : "NO"}

Respond ONLY as valid JSON:
{
  "anomalyRiskLevel": "low|medium|high",
  "confidence": 0.0,
  "factors": ["factor1"],
  "reasoning": "brief explanation"
}`;

    try {
      const message = await this.client.messages.create({
        model: "claude-3-5-sonnet-20241022",
        max_tokens: 256,
        messages: [{ role: "user", content: prompt }],
      });
      const responseText = message.content[0].type === "text" ? message.content[0].text : "{}";
      return JSON.parse(responseText);
    } catch (error) {
      return { anomalyRiskLevel: "medium", confidence: 0.5, factors: ["api-error"], reasoning: "Claude API unavailable" };
    }
  }

  synthesizeRiskScore(signals, aiAnalysis, transaction) {
    const weights = { velocity: 0.25, amountAnomaly: 0.25, newMerchant: 0.15, timeAnomaly: 0.1 };
    let baseScore = weights.velocity * signals.velocityScore + weights.amountAnomaly * signals.amountAnomalyScore + weights.newMerchant * signals.newMerchantScore + weights.timeAnomaly * signals.timeAnomalyScore;
    const aiBoost = aiAnalysis.anomalyRiskLevel === "high" ? 20 : aiAnalysis.anomalyRiskLevel === "medium" ? 10 : 0;
    const riskScore = Math.min(100, baseScore + aiBoost * aiAnalysis.confidence);

    let riskLevel = "low";
    if (riskScore >= 70) riskLevel = "high";
    else if (riskScore >= 40) riskLevel = "medium";

    let recommendation = "APPROVE";
    if (riskLevel === "high") recommendation = "REVIEW";
    else if (riskLevel === "medium") recommendation = "MONITOR";

    return {
      transactionId: transaction.id,
      riskScore: Math.round(riskScore),
      riskLevel,
      recommendation,
      factors: { velocity: signals.velocityScore.toFixed(0), amountAnomaly: signals.amountAnomalyScore.toFixed(0), newMerchant: signals.newMerchantScore, timeAnomaly: signals.timeAnomalyScore, aiAnalysis: aiAnalysis.factors },
      reasoning: aiAnalysis.reasoning,
      timestamp: new Date().toISOString(),
    };
  }

  recordTransaction(transaction, assessment) {
    this.transactionHistory.push({ ...transaction, riskAssessment: assessment, recordedAt: Date.now() });
    const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
    this.transactionHistory = this.transactionHistory.filter((tx) => tx.timestamp >= sevenDaysAgo);

    if (!this.merchantPatterns[transaction.merchant]) {
      this.merchantPatterns[transaction.merchant] = { transactionCount: 0, totalAmount: 0, avgAmount: 0, firstSeen: transaction.timestamp, lastSeen: transaction.timestamp };
    }
    const pattern = this.merchantPatterns[transaction.merchant];
    pattern.transactionCount += 1;
    pattern.totalAmount += transaction.amount;
    pattern.avgAmount = pattern.totalAmount / pattern.transactionCount;
    pattern.lastSeen = transaction.timestamp;
  }

  getHistoricalRisks(userId, days = 7) {
    const cutoff = Date.now() - days * 24 * 60 * 60 * 1000;
    const userTxs = this.transactionHistory.filter((tx) => tx.userId === userId && tx.timestamp >= cutoff);
    const byDay = {};
    userTxs.forEach((tx) => {
      const day = new Date(tx.timestamp).toISOString().split("T")[0];
      if (!byDay[day]) byDay[day] = [];
      byDay[day].push(tx.riskAssessment?.riskScore || 0);
    });

    const aggregated = {};
    Object.entries(byDay).forEach(([day, scores]) => {
      aggregated[day] = {
        avgRiskScore: (scores.reduce((a, b) => a + b, 0) / scores.length).toFixed(1),
        maxRiskScore: Math.max(...scores),
        txCount: scores.length,
        highRiskCount: scores.filter((s) => s >= 70).length,
      };
    });
    return aggregated;
  }

  getMerchantPattern(merchant) {
    return this.merchantPatterns[merchant] || null;
  }
}

module.exports = RiskAgent;
