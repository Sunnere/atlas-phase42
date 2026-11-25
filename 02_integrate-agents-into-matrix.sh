#!/bin/bash

# Integrate three new agents into ATLAS Matrix Orchestrator
# Edit 08_atlas-matrix-orchestrator.js with the integration code

TARGET_FILE="/Users/sunnerehelse/atlas-phase2/scripts/08_atlas-matrix-orchestrator.js"

echo "🔗 Integration Steps for ATLAS Matrix"
echo "====================================="
echo ""
echo "Target file: $TARGET_FILE"
echo ""

echo "✅ STEP 1: Add imports at top of file"
echo "---"
cat << 'STEP1_EOF'
// Add after existing agent imports:
const { ThailandPropertyAgent } = require('../backend/services/thailand-property-agent.js');
const { BonusShopMarketingAgent } = require('../backend/services/bonusshop-marketing-agent.js');
const { TradingInvestmentAgent } = require('../backend/services/trading-investment-agent.js');
STEP1_EOF

echo ""
echo "✅ STEP 2: Instantiate in ATLASMatrix constructor"
echo "---"
cat << 'STEP2_EOF'
// In constructor, add after existing agents:
this.agents = {
  // ... existing 7 agents ...
  'thailand-property-01': new ThailandPropertyAgent(),
  'marketing-01': new BonusShopMarketingAgent(),
  'trading-01': new TradingInvestmentAgent()
};
STEP2_EOF

echo ""
echo "✅ STEP 3: Add Phase 7 to orchestration cycle"
echo "---"
cat << 'STEP3_EOF'
// In orchestrate() method, add after Phase 6:
// PHASE 7: SPECIALIZED AGENTS ANALYSIS
cycle.phases.specializedAgents = await this.runSpecializedAgentPhase();

// PHASE 8: CROSS-AGENT CORRELATION
cycle.phases.crossAgentCorrelation = await this.correlateSpecializedAgents(cycle);
STEP3_EOF

echo ""
echo "✅ STEP 4: Implement Phase 7 method"
echo "---"
echo "See 12_integrate-agents.js for full code"
echo ""

echo "✅ STEP 5: Implement Phase 8 method"
echo "---"
echo "See 12_integrate-agents.js for full code"
echo ""

echo "✅ STEP 6: Update escalation handling"
echo "---"
echo "Review escalation logic for new agent types"
echo ""

echo "✅ STEP 7: Update ledger entries"
echo "---"
echo "Include new agents in evidence logging"
echo ""

echo "📖 Full integration guide:"
echo "   node /Users/sunnerehelse/atlas-phase2/scripts/12_integrate-agents.js"
echo ""

