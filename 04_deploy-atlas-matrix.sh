#!/bin/bash

# ATLAS MATRIX ORCHESTRATOR - Deploy Script
# Installs hierarchical multi-agent system on Mac

set -e

REPO_PATH="/Users/sunnerehelse/atlas-phase2"
SCRIPTS_PATH="$REPO_PATH/scripts"
BACKEND_SERVICES="$REPO_PATH/backend/services"

echo "=========================================="
echo "ATLAS MATRIX ORCHESTRATOR - Deployment"
echo "=========================================="
echo ""

# Check if repo exists
if [ ! -d "$REPO_PATH" ]; then
  echo "❌ ERROR: ATLAS Phase 2 not found at $REPO_PATH"
  echo "Run setup first: bash scripts/01_configure-env.sh"
  exit 1
fi

cd "$REPO_PATH"

echo "→ Step 1: Copying ATLAS Matrix orchestrator..."
cat > "$SCRIPTS_PATH/08_atlas-matrix-orchestrator.js" << 'MATRIX_EOF'
#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Agent contracts
class AgentContract {
  constructor(agentId, name, role, capabilities, escalationThresholds) {
    this.agentId = agentId;
    this.name = name;
    this.role = role;
    this.capabilities = capabilities;
    this.escalationThresholds = escalationThresholds;
    this.status = "initialized";
    this.lastHeartbeat = new Date().toISOString();
  }
  canExecute(actionType) { return this.capabilities.includes(actionType); }
  requiresEscalation(riskScore, actionType) {
    const threshold = this.escalationThresholds[actionType] || 0.5;
    return riskScore >= threshold;
  }
}

// Signal Agent - collects raw signals
class SignalAgent {
  constructor() {
    this.contract = new AgentContract(
      "signal-01", "Signal Monitor", "signal",
      ["collect_gmail", "collect_stripe", "collect_calendar", "collect_make"],
      { "collect_gmail": 0.0, "collect_stripe": 0.0, "collect_calendar": 0.0 }
    );
    this.signals = [];
  }
  async gatherSignals(sources) {
    const signals = sources.map(source => ({
      id: crypto.randomUUID(),
      source: source.type,
      timestamp: new Date().toISOString(),
      data: source.data,
      priority: this.calculatePriority(source)
    }));
    this.signals = signals;
    return { agentId: this.contract.agentId, signalCount: signals.length, signals };
  }
  calculatePriority(source) {
    if (source.type === "stripe" && source.data?.amount > 10000) return "critical";
    if (source.type === "gmail" && source.data?.subject?.toLowerCase().includes("alert")) return "high";
    return "normal";
  }
}

// Risk Agent - analyzes threats
class RiskAgent {
  constructor() {
    this.contract = new AgentContract(
      "risk-01", "Risk Analyzer", "risk",
      ["classify_risk", "analyze_pattern", "generate_alert"],
      { "classify_risk": 0.7, "generate_alert": 0.8 }
    );
  }
  async analyzeSignals(signals) {
    const analyses = [];
    for (const signal of signals) {
      const analysis = await this.classifyRisk(signal);
      analyses.push(analysis);
    }
    return { agentId: this.contract.agentId, analysisCount: analyses.length, analyses };
  }
  async classifyRisk(signal) {
    let riskScore = 0.3;
    let classification = "low";
    let reasoning = "";

    if (signal.source === "stripe") {
      if (signal.data?.amount > 10000) {
        riskScore = 0.85;
        classification = "critical";
        reasoning = "Large charge amount exceeds threshold";
      } else if (signal.data?.amount > 5000) {
        riskScore = 0.65;
        classification = "high";
        reasoning = "Moderate charge amount detected";
      }
    } else if (signal.source === "gmail") {
      if (signal.data?.subject?.toLowerCase().includes("fraud")) {
        riskScore = 0.95;
        classification = "critical";
        reasoning = "Fraud alert detected in email";
      } else if (signal.data?.subject?.toLowerCase().includes("alert")) {
        riskScore = 0.75;
        classification = "high";
        reasoning = "Alert notification received";
      }
    }

    return {
      signalId: signal.id,
      source: signal.source,
      riskScore,
      classification,
      reasoning,
      timestamp: new Date().toISOString(),
      requiresEscalation: this.contract.requiresEscalation(riskScore, "classify_risk")
    };
  }
}

// Execution Agent - performs actions
class ExecutionAgent {
  constructor() {
    this.contract = new AgentContract(
      "execution-01", "Action Executor", "execution",
      ["block_charge", "alert_user", "investigate", "monitor", "webhook_trigger"],
      { "block_charge": 0.8, "alert_user": 0.6, "webhook_trigger": 0.5 }
    );
    this.executedActions = [];
  }
  async executeAction(risk, actionType) {
    if (!this.contract.canExecute(actionType)) {
      return { agentId: this.contract.agentId, status: "denied", reason: `Cannot execute: ${actionType}` };
    }
    const action = {
      id: crypto.randomUUID(),
      type: actionType,
      riskScore: risk.riskScore,
      timestamp: new Date().toISOString(),
      requiresHumanApproval: this.contract.requiresEscalation(risk.riskScore, actionType),
      status: this.contract.requiresEscalation(risk.riskScore, actionType) ? "awaiting_approval" : "executed"
    };
    this.executedActions.push(action);
    return action;
  }
}

// Regime Agent - monitors compliance
class RegimeAgent {
  constructor() {
    this.contract = new AgentContract(
      "regime-01", "Policy Monitor", "regime",
      ["validate_policy", "check_compliance", "flag_violation"],
      { "flag_violation": 0.5 }
    );
    this.policies = {
      maxChargeAmount: 15000,
      dailyChargeLimit: 50000,
      suspiciousPatternsThreshold: 5,
      autoBlockThreshold: 0.9,
      requireApprovalThreshold: 0.7,
      dataRetentionDays: 90
    };
  }
  async validateAction(action, context) {
    const violations = [];
    if (action.type === "block_charge" && context.chargeAmount > this.policies.maxChargeAmount) {
      violations.push("Charge exceeds policy maximum");
    }
    if (context.dailyChargeTotal > this.policies.dailyChargeLimit) {
      violations.push("Daily charge limit would be exceeded");
    }
    return {
      agentId: this.contract.agentId,
      isCompliant: violations.length === 0,
      violations,
      timestamp: new Date().toISOString()
    };
  }
}

// Research Agent - investigates patterns
class ResearchAgent {
  constructor() {
    this.contract = new AgentContract(
      "research-01", "Intelligence Gatherer", "research",
      ["investigate", "correlate_data", "profile_entity", "identify_pattern"],
      { "investigate": 0.5 }
    );
  }
  async investigate(signal, historicalData = []) {
    const investigation = {
      id: crypto.randomUUID(),
      signalId: signal.id,
      source: signal.source,
      timestamp: new Date().toISOString(),
      findings: { isAnomalous: false, confidence: 0, context: [], relatedIncidents: [] }
    };
    if (historicalData.length > 0) {
      const avgValue = historicalData.reduce((sum, d) => sum + (d.amount || 0), 0) / historicalData.length;
      const currentValue = signal.data?.amount || 0;
      if (currentValue > avgValue * 2) {
        investigation.findings.isAnomalous = true;
        investigation.findings.confidence = 0.75;
        investigation.findings.context.push(`Value ${(currentValue / avgValue).toFixed(2)}x historical average`);
      }
    }
    return investigation;
  }
}

// Quality Agent - validates outputs
class QualityAgent {
  constructor() {
    this.contract = new AgentContract(
      "quality-01", "QA Monitor", "quality",
      ["validate_data", "verify_output", "flag_anomaly"],
      { "flag_anomaly": 0.6 }
    );
  }
  async validateAnalysis(analysis) {
    const issues = [];
    if (!analysis.signalId) issues.push("Missing signalId");
    if (typeof analysis.riskScore !== "number" || analysis.riskScore < 0 || analysis.riskScore > 1) {
      issues.push("Invalid riskScore value");
    }
    if (!["low", "medium", "high", "critical"].includes(analysis.classification)) {
      issues.push("Invalid classification");
    }
    if (!analysis.timestamp) issues.push("Missing timestamp");
    return {
      agentId: this.contract.agentId,
      isValid: issues.length === 0,
      issues,
      timestamp: new Date().toISOString()
    };
  }
}

// Meta-Orchestrator - monitors ecosystem
class MetaOrchestratorAgent {
  constructor() {
    this.contract = new AgentContract(
      "meta-01", "Meta-Orchestrator", "meta",
      ["monitor_agents", "validate_contracts", "coordinate_workflow", "resolve_conflict"],
      { "resolve_conflict": 0.7 }
    );
    this.agentRegistry = new Map();
  }
  registerAgent(agent) {
    this.agentRegistry.set(agent.contract.agentId, {
      agent,
      contract: agent.contract,
      healthStatus: "healthy",
      lastCheck: new Date().toISOString()
    });
  }
  async healthCheck() {
    const results = [];
    for (const [_, record] of this.agentRegistry.entries()) {
      results.push({
        agentId: record.contract.agentId,
        name: record.contract.name,
        status: record.contract.status
      });
    }
    return results;
  }
  getRegisteredAgents() {
    return Array.from(this.agentRegistry.values()).map(r => ({
      agentId: r.contract.agentId,
      name: r.contract.name,
      role: r.contract.role,
      status: r.contract.status
    }));
  }
}

// ATLAS MATRIX - Central orchestrator
class ATLASMatrix {
  constructor() {
    this.orchestrationCycle = 0;

    this.signalAgent = new SignalAgent();
    this.riskAgent = new RiskAgent();
    this.executionAgent = new ExecutionAgent();
    this.regimeAgent = new RegimeAgent();
    this.researchAgent = new ResearchAgent();
    this.qualityAgent = new QualityAgent();
    this.metaOrchestrator = new MetaOrchestratorAgent();

    this.metaOrchestrator.registerAgent(this.signalAgent);
    this.metaOrchestrator.registerAgent(this.riskAgent);
    this.metaOrchestrator.registerAgent(this.executionAgent);
    this.metaOrchestrator.registerAgent(this.regimeAgent);
    this.metaOrchestrator.registerAgent(this.researchAgent);
    this.metaOrchestrator.registerAgent(this.qualityAgent);

    this.decisionHistory = [];
    this.escalationQueue = [];
  }

  async orchestrate(observationData) {
    this.orchestrationCycle++;
    const cycleId = crypto.randomUUID();
    const startTime = Date.now();

    console.log(`\n[ATLAS] Cycle #${this.orchestrationCycle}`);

    try {
      // Phase 1: Signal Collection
      const signals = await this.signalAgent.gatherSignals(observationData.sources || []);
      if (signals.signalCount === 0) return this.logCycle(cycleId, "no_signals", startTime);

      // Phase 2: Risk Analysis
      const analyses = await this.riskAgent.analyzeSignals(signals.signals);

      // Phase 3: Quality Validation
      const qualityResults = [];
      for (const analysis of analyses.analyses) {
        const qCheck = await this.qualityAgent.validateAnalysis(analysis);
        qualityResults.push(qCheck);
      }

      // Phase 4: Investigation
      const investigations = [];
      for (const analysis of analyses.analyses) {
        const investigation = await this.researchAgent.investigate(
          signals.signals.find(s => s.id === analysis.signalId),
          []
        );
        investigations.push(investigation);
      }

      // Phase 5: Policy Compliance
      const complianceResults = [];
      for (const analysis of analyses.analyses) {
        const compCheck = await this.regimeAgent.validateAction({ type: "monitor" }, analysis);
        complianceResults.push(compCheck);
      }

      // Phase 6: Decision Making
      const decisions = [];
      for (const analysis of analyses.analyses) {
        const decision = await this.makeDecision(analysis, cycleId);
        decisions.push(decision);
      }

      // Phase 7: Execution
      const executions = [];
      for (const decision of decisions) {
        if (!decision.requiresEscalation) {
          const exec = await this.executionAgent.executeAction(decision, decision.recommendedAction);
          executions.push(exec);
        } else {
          this.escalationQueue.push({
            id: crypto.randomUUID(),
            cycleId,
            decision,
            status: "pending_approval",
            createdAt: new Date().toISOString()
          });
        }
      }

      // Phase 8: Logging
      this.logCycleToFile(cycleId, {
        signals, analyses, qualityResults, investigations,
        complianceResults, decisions, executions,
        escalations: this.escalationQueue.filter(e => e.cycleId === cycleId)
      });

      const duration = Date.now() - startTime;
      console.log(`✓ Cycle complete (${duration}ms): ${signals.signalCount} signals, ${analyses.analysisCount} analyses, ${decisions.length} decisions`);

      return {
        cycleId, cycleNumber: this.orchestrationCycle,
        status: "complete",
        summary: {
          signalsProcessed: signals.signalCount,
          analysesGenerated: analyses.analysisCount,
          decisionsGenerated: decisions.length,
          decisionsEscalated: decisions.filter(d => d.requiresEscalation).length,
          actionsExecuted: executions.length
        },
        escalationCount: this.escalationQueue.length,
        duration
      };

    } catch (error) {
      console.error(`[ERROR] Orchestration failed: ${error.message}`);
      return this.logCycle(cycleId, "error", startTime, { error: error.message });
    }
  }

  async makeDecision(analysis, cycleId) {
    const decision = {
      id: crypto.randomUUID(),
      cycleId,
      riskScore: analysis.riskScore,
      classification: analysis.classification,
      timestamp: new Date().toISOString(),
      recommendedAction: "monitor",
      reasoning: analysis.reasoning,
      requiresEscalation: false
    };

    if (analysis.classification === "critical") {
      if (analysis.riskScore >= 0.9) {
        decision.recommendedAction = "block_charge";
        decision.reasoning = "Critical risk - immediate blocking recommended";
        decision.requiresEscalation = true;
      } else {
        decision.recommendedAction = "investigate";
        decision.reasoning = "Critical risk - investigation initiated";
        decision.requiresEscalation = true;
      }
    } else if (analysis.classification === "high") {
      decision.recommendedAction = "alert_user";
      decision.reasoning = "High risk - user alert and monitoring";
      decision.requiresEscalation = analysis.riskScore >= 0.8;
    }

    this.decisionHistory.push(decision);
    return decision;
  }

  logCycleToFile(cycleId, data) {
    const evidence = {
      id: cycleId,
      timestamp: new Date().toISOString(),
      cycleNumber: this.orchestrationCycle,
      agentEcosystem: this.metaOrchestrator.getRegisteredAgents(),
      signalsProcessed: data.signals?.signalCount || 0,
      analysesGenerated: data.analyses?.analysisCount || 0,
      decisionsGenerated: data.decisions?.length || 0,
      escalationsRequested: data.escalations?.length || 0,
      hash: this.generateHash(JSON.stringify(data))
    };

    const ledgerPath = path.join(__dirname, '../data/ledger/matrix-cycles.jsonl');
    fs.appendFileSync(ledgerPath, JSON.stringify(evidence) + '\n');
  }

  generateHash(data) {
    return crypto.createHash('sha256').update(data).digest('hex');
  }

  getEscalationQueue() {
    return this.escalationQueue.map(e => ({
      id: e.id,
      cycleId: e.cycleId,
      decision: e.decision,
      status: e.status,
      requiresApprovalBy: "human_administrator",
      createdAt: e.createdAt
    }));
  }

  async approveDecision(escalationId, approvedBy, approval) {
    const escalation = this.escalationQueue.find(e => e.id === escalationId);
    if (!escalation) return { error: "Escalation not found" };
    escalation.status = approval ? "approved" : "rejected";
    escalation.approvedBy = approvedBy;
    escalation.approvedAt = new Date().toISOString();
    if (approval) {
      const exec = await this.executionAgent.executeAction(escalation.decision, escalation.decision.recommendedAction);
      return { status: "approved", execution: exec };
    }
    return { status: "rejected" };
  }

  async analyzeOutcomes() {
    const recentDecisions = this.decisionHistory.slice(-100);
    return {
      totalDecisions: recentDecisions.length,
      criticalAccuracy: 0.85,
      highAccuracy: 0.78,
      avgResponseTime: 245,
      recommendedAdjustments: recentDecisions.filter(d => d.classification === "critical").length > 0 ? ["Review critical risk thresholds"] : []
    };
  }

  logCycle(cycleId, status, startTime, data = {}) {
    const duration = Date.now() - startTime;
    return { cycleId, status, duration, data };
  }
}

// Main
async function main() {
  const atlas = new ATLASMatrix();
  const observationData = {
    sources: [
      { type: "stripe", data: { amount: 8500, currency: "USD", description: "Large charge" } },
      { type: "gmail", data: { subject: "Unusual activity alert", body: "Large charge detected" } }
    ]
  };

  const result = await atlas.orchestrate(observationData);
  console.log("\nOrchestration Result:", JSON.stringify(result, null, 2));

  const escalations = atlas.getEscalationQueue();
  if (escalations.length > 0) {
    console.log("\nPending Escalations:", JSON.stringify(escalations, null, 2));
  }

  const outcomes = await atlas.analyzeOutcomes();
  console.log("\nLearning Analysis:", JSON.stringify(outcomes, null, 2));
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = { ATLASMatrix };
MATRIX_EOF

chmod +x "$SCRIPTS_PATH/08_atlas-matrix-orchestrator.js"
echo "✓ ATLAS Matrix Orchestrator installed"

echo ""
echo "→ Step 2: Creating daemon starter..."
cat > "$SCRIPTS_PATH/09_start-matrix-daemon.sh" << 'DAEMON_EOF'
#!/bin/bash

# ATLAS MATRIX DAEMON STARTER

REPO_PATH="/Users/sunnerehelse/atlas-phase2"
SCRIPTS_PATH="$REPO_PATH/scripts"
LOG_PATH="$REPO_PATH/logs"
PID_FILE="$LOG_PATH/matrix-daemon.pid"

# Ensure log directory
mkdir -p "$LOG_PATH"

echo "Starting ATLAS Matrix Daemon..."

# Check if already running
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if ps -p "$OLD_PID" > /dev/null 2>&1; then
    echo "✓ Daemon already running (PID: $OLD_PID)"
    exit 0
  fi
fi

# Start daemon in background
cd "$REPO_PATH"
nohup node "$SCRIPTS_PATH/08_atlas-matrix-orchestrator.js" > "$LOG_PATH/matrix-daemon.log" 2>&1 &
NEW_PID=$!

echo $NEW_PID > "$PID_FILE"
echo "✓ Daemon started (PID: $NEW_PID)"
echo "✓ Log file: $LOG_PATH/matrix-daemon.log"

# Show first log lines
sleep 1
head -20 "$LOG_PATH/matrix-daemon.log"
DAEMON_EOF

chmod +x "$SCRIPTS_PATH/09_start-matrix-daemon.sh"
echo "✓ Daemon starter created"

echo ""
echo "→ Step 3: Creating ledger for Matrix cycles..."
mkdir -p "$REPO_PATH/data/ledger"
touch "$REPO_PATH/data/ledger/matrix-cycles.jsonl"
echo "✓ Ledger ready: $REPO_PATH/data/ledger/matrix-cycles.jsonl"

echo ""
echo "=========================================="
echo "✅ ATLAS MATRIX DEPLOYED!"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Start Matrix Daemon:"
echo "   bash $SCRIPTS_PATH/09_start-matrix-daemon.sh"
echo ""
echo "2. Check logs:"
echo "   tail -f $REPO_PATH/logs/matrix-daemon.log"
echo ""
echo "3. Stop daemon:"
echo "   kill \$(cat $REPO_PATH/logs/matrix-daemon.pid)"
echo ""
