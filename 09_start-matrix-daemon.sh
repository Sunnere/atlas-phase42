#!/bin/bash

# Start ATLAS Matrix Orchestrator as daemon
# Runs continuous orchestration cycles every 5 minutes
# Usage: bash scripts/09_start-matrix-daemon.sh

PROJECT_DIR="/Users/sunnerehelse/atlas-phase2"
SCRIPT="${PROJECT_DIR}/scripts/08_atlas-matrix-orchestrator.js"
LOG_FILE="${PROJECT_DIR}/logs/matrix-daemon.log"
PID_FILE="${PROJECT_DIR}/logs/matrix-daemon.pid"

# Ensure directories exist
mkdir -p "${PROJECT_DIR}/logs"
mkdir -p "${PROJECT_DIR}/data/ledger"

echo "🚀 Starting ATLAS Matrix Orchestrator Daemon"
echo "   Project: $PROJECT_DIR"
echo "   Log: $LOG_FILE"
echo ""

# Start daemon
nohup node << 'DAEMON_JS' > "$LOG_FILE" 2>&1 &

// ATLAS Matrix Daemon
const { ATLASMatrix } = require('/Users/sunnerehelse/atlas-phase2/scripts/08_atlas-matrix-orchestrator.js');
const matrix = new ATLASMatrix();

console.log(`[${new Date().toISOString()}] 🤖 ATLAS Matrix Daemon Started`);
console.log(`[${new Date().toISOString()}] 📊 Agent Ecosystem:`);
matrix.agentEcosystem.forEach((agent, i) => {
  console.log(`[${new Date().toISOString()}]    ${i + 1}. ${agent.name}`);
});

// Run orchestration every 5 minutes
const interval = 5 * 60 * 1000; // 5 minutes
let cycleCount = 0;

async function runCycle() {
  try {
    cycleCount++;
    console.log(`\n[${new Date().toISOString()}] 🔄 Starting cycle #${cycleCount}`);
    const cycle = await matrix.orchestrate();
    console.log(`[${new Date().toISOString()}] ✅ Cycle #${cycleCount} complete`);
    console.log(`[${new Date().toISOString()}]    Insights: ${cycle.phases.crossAgentCorrelation.insights.length}`);
  } catch (error) {
    console.error(`[${new Date().toISOString()}] ❌ Cycle error:`, error.message);
  }
}

// Run immediately, then on interval
runCycle();
setInterval(runCycle, interval);

// Graceful shutdown
process.on('SIGINT', () => {
  console.log(`\n[${new Date().toISOString()}] 🛑 Shutting down daemon...`);
  console.log(`[${new Date().toISOString()}] 📊 Total cycles: ${cycleCount}`);
  process.exit(0);
});

DAEMON_JS
DAEMON_PID=$!

echo "✅ Daemon started (PID: $DAEMON_PID)"
echo "   Process: node 08_atlas-matrix-orchestrator.js"
echo "   Interval: 5 minutes"
echo ""
echo "📊 Watch logs:"
echo "   tail -f $LOG_FILE"
echo ""
echo "📁 View ledger:"
echo "   tail -f ${PROJECT_DIR}/data/ledger/matrix-cycles.jsonl | jq"
echo ""
echo "🛑 Stop daemon:"
echo "   kill $DAEMON_PID"
echo ""

