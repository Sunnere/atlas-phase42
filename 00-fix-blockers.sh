#!/bin/bash

set -e

echo "🔧 ATLAS Phase 3: Fixing Blockers"
echo "===================================="
echo ""

cd /Users/sunnerehelse/atlas-phase2

# Fix 1: Remove stale git lock file
echo "Step 1: Removing stale git lock file..."
if [ -f ".git/HEAD.lock" ]; then
  rm ".git/HEAD.lock"
  echo "✅ Removed .git/HEAD.lock"
else
  echo "⚠️  No lock file found (already cleaned)"
fi

echo ""

# Fix 2: Install missing cors module
echo "Step 2: Installing missing npm dependencies..."
if ! npm list cors > /dev/null 2>&1; then
  npm install cors
  echo "✅ Installed cors"
else
  echo "✅ cors already installed"
fi

echo ""
echo "✅ All blockers fixed!"
echo ""
echo "Next steps:"
echo "1. npm start"
echo "2. In new terminal: curl http://localhost:3000/health"
echo "3. If OK: ctrl+c and run bash ~/atlas-phase42/03-deploy-phase3.sh"
