#!/bin/bash

# Deploy three new agents to Mac
# Run on Mac at: bash scripts/01_deploy-agents-to-mac.sh

TARGET_DIR="/Users/sunnerehelse/atlas-phase2/backend/services"

echo "📦 Deploying three new agents to Mac..."
echo "Target: $TARGET_DIR"
echo ""

# Create directory if needed
mkdir -p "$TARGET_DIR"

# Copy agent files
echo "🏡 Copying Thailand Property Agent..."
cp ./thailand-property-agent.js "$TARGET_DIR/"

echo "🎯 Copying BonusShop Marketing Agent..."
cp ./bonusshop-marketing-agent.js "$TARGET_DIR/"

echo "📈 Copying Trading & Investment Agent..."
cp ./trading-investment-agent.js "$TARGET_DIR/"

# Copy test suite
echo "🧪 Copying test suite..."
cp ./11_test-three-agents.js ../scripts/

# Copy integration guide
echo "📖 Copying integration guide..."
cp ./12_integrate-agents.js ../scripts/

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Verify files:"
echo "   ls -la $TARGET_DIR"
echo ""
echo "2. Run test suite:"
echo "   cd /Users/sunnerehelse/atlas-phase2"
echo "   node scripts/11_test-three-agents.js"
echo ""
echo "3. Read integration guide:"
echo "   node scripts/12_integrate-agents.js"
echo ""
echo "4. Integrate into ATLAS Matrix (08_atlas-matrix-orchestrator.js)"
