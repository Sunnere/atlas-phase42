#!/bin/bash

set -e

cd /Users/sunnerehelse/atlas-phase2

echo "🚀 Pushing Phase 3 to repository..."

# Detect branch
DEFAULT_BRANCH=$(git rev-parse --abbrev-ref origin/HEAD | cut -d'/' -f2)
echo "Default branch: $DEFAULT_BRANCH"

git push origin HEAD:$DEFAULT_BRANCH

echo "✅ Push successful!"
echo ""
echo "Check deployment at:"
echo "  https://fulfilling-charm-production-b137.up.railway.app/dashboard"
