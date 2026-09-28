#!/bin/bash

# ============================================================================
# ATLAS Phase 3: Deploy to Railway
# Usage: bash 03-deploy-phase3.sh
#
# This script:
# 1. Verifies git status (no uncommitted changes)
# 2. Creates proper git commit with attribution
# 3. Pushes to master branch
# 4. Monitors Railway deployment
# ============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 ATLAS Phase 3: Deploy to Railway${NC}"
echo "======================================"
echo ""

# Step 1: Check git status
echo -e "${BLUE}Step 1: Checking git status${NC}"
if [ ! -d ".git" ]; then
  echo -e "${RED}❌ Not a git repository${NC}"
  exit 1
fi

# Check for uncommitted changes (excluding our new Phase 3 files)
UNCOMMITTED=$(git status --porcelain | grep -v "^??" | wc -l)
if [ $UNCOMMITTED -gt 0 ]; then
  echo -e "${YELLOW}⚠️  Uncommitted changes detected:${NC}"
  git status --short
  echo ""
  read -p "Continue anyway? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

echo -e "${GREEN}✅ Git status OK${NC}"
echo ""

# Step 2: Stage Phase 3 files
echo -e "${BLUE}Step 2: Staging Phase 3 changes${NC}"
git add -A
echo "Changed files:"
git status --short
echo ""

# Step 3: Create commit with proper attribution
echo -e "${BLUE}Step 3: Creating commit${NC}"
git commit -m "feat(phase3): Add custom time ranges and CSV export

- Updated /api/metrics/requests with date range parameters
- Added /api/metrics/summary for aggregated statistics
- Added /api/metrics/export for CSV downloads
- Enhanced dashboard with date range picker (60min, 24h, 1week, 1month, custom)
- Fixed theme toggle (light/dark mode now functional)
- Added export metrics button with CSV download
- Improved responsive design for mobile/tablet

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01UgfQ8q59pVPAgAgKXiSAas"

COMMIT_HASH=$(git rev-parse --short HEAD)
echo -e "${GREEN}✅ Commit created: $COMMIT_HASH${NC}"
echo ""

# Step 4: Push to master
echo -e "${BLUE}Step 4: Pushing to master branch${NC}"
echo "Pushing to origin/master..."
git push origin master

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Push successful!${NC}"
else
  echo -e "${RED}❌ Push failed${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}✅ Deployment to Railway initiated!${NC}"
echo ""
echo -e "${YELLOW}📊 Deployment Status:${NC}"
echo "Watch Railway at: https://fulfilling-charm-production-b137.up.railway.app/"
echo ""
echo "Dashboard available at:"
echo "  🌐 https://fulfilling-charm-production-b137.up.railway.app/dashboard"
echo ""
echo -e "${YELLOW}📋 Verify Deployment:${NC}"
echo "1. Wait 30-60 seconds for Railway to rebuild"
echo "2. Open dashboard in browser"
echo "3. Test date range picker (60min, 24h, 1week, 1month)"
echo "4. Test theme toggle (🌙/☀️)"
echo "5. Test CSV export button"
echo ""
echo "Commit hash: $COMMIT_HASH"
