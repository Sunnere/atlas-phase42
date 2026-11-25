#!/bin/bash
# Copy scripts from Downloads to current directory

if [ ! -d "$HOME/Downloads" ]; then
    echo "❌ Downloads folder not found"
    exit 1
fi

echo "📋 Copying scripts from Downloads..."
cp "$HOME/Downloads/01_fix-railway-toml.sh" . 2>/dev/null || echo "⚠️  01_fix-railway-toml.sh not found in Downloads"
cp "$HOME/Downloads/02_commit-and-push.sh" . 2>/dev/null || echo "⚠️  02_commit-and-push.sh not found in Downloads"
cp "$HOME/Downloads/03_test-phase45-live.sh" . 2>/dev/null || echo "⚠️  03_test-phase45-live.sh not found in Downloads"

chmod +x *.sh
ls -la *.sh 2>/dev/null | grep -E "01_|02_|03_"

echo ""
echo "✅ Scripts ready. Run:"
echo "   bash 01_fix-railway-toml.sh"
echo "   bash 02_commit-and-push.sh"
