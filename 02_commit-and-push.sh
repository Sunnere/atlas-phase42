#!/bin/bash
set -e

echo "📤 Committing and pushing fix to master..."

# Verify we're in a git repo
if [ ! -d ".git" ]; then
    echo "❌ Error: Not a git repository"
    exit 1
fi

# Stage the railway.toml fix
git add railway.toml
echo "✅ Staged railway.toml"

# Commit with descriptive message
git commit -m "Fix: Set correct startCommand to use atlas-backend/server.js with Phase 4.5 & 4.6"
echo "✅ Committed fix"

# Push to master
git push origin master
echo "✅ Pushed to master - Railway will auto-redeploy"

