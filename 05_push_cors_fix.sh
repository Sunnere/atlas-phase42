#!/bin/bash
# Push CORS fix to GitHub and trigger Vercel redeploy
# Run this from ~/atlas-phase42 directory on your Mac

echo "🔧 CORS Fix Push Script"
echo "======================="
echo ""
echo "This script pushes the CORS middleware fix to GitHub,"
echo "which will trigger a Vercel redeploy of atlas.bonusvarsel.no"
echo ""

# Check if we're in the right directory
if [ ! -f "16_railway-backend-phase42.js" ]; then
  echo "❌ Error: 16_railway-backend-phase42.js not found"
  echo "Make sure you're in the ~/atlas-phase42 directory"
  exit 1
fi

# Show what we're about to push
echo "📊 Local commits ahead of GitHub:"
git log --oneline origin/master..HEAD | head -10
echo ""

# Show the specific CORS fix
echo "✅ CORS Middleware Fix Details:"
echo "================================"
git show --stat 9a87170
echo ""

# Ask for confirmation
read -p "Ready to push these commits to GitHub? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "❌ Push cancelled"
  exit 1
fi

echo ""
echo "🚀 Pushing to GitHub master branch..."
git push origin master

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ SUCCESS! Commits pushed to GitHub"
  echo ""
  echo "📡 Vercel will automatically redeploy within 1-2 minutes"
  echo ""
  echo "Testing the fix:"
  echo "1. Wait 1-2 minutes for Vercel to redeploy"
  echo "2. Test with: curl -i https://atlas.bonusvarsel.no/api/status"
  echo "3. Look for: Access-Control-Allow-Origin: * header"
  echo "4. Dashboard should now work without CORS errors"
else
  echo ""
  echo "❌ Push failed. Possible causes:"
  echo "  - Network/firewall blocking git HTTPS"
  echo "  - SSH key not configured"
  echo "  - GitHub credentials not saved"
  echo ""
  echo "Try these fixes:"
  echo "  1. git credential-osxkeychain erase host=github.com (clear old credentials)"
  echo "  2. git push origin master (and enter PAT when prompted)"
  echo "  3. Or create a GitHub Personal Access Token and use that"
fi
