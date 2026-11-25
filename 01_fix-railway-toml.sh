#!/bin/bash
set -e

echo "🔧 Fixing railway.toml for Phase 4.5 & 4.6..."

# Check we're in the right directory
if [ ! -f "railway.toml" ] || [ ! -d "atlas-backend" ]; then
    echo "❌ Error: Must run from repo root (needs railway.toml and atlas-backend/)"
    exit 1
fi

# Create corrected railway.toml
cat > railway.toml << 'EOF'
[build]
builder = "heroku"

[deploy]
startCommand = "cd atlas-backend && node server.js"
EOF

echo "✅ Updated railway.toml:"
cat railway.toml
