#!/bin/bash
# Fix theme toggle - ensure dark mode CSS applies correctly

set -e
cd "$HOME/mnt/atlas-phase42"

FILE="public/dashboard/index.html"
BACKUP="public/dashboard/index.html.backup.theme-fix-$(date +%Y%m%d_%H%M%S)"

echo "📦 Creating backup: $BACKUP"
cp "$FILE" "$BACKUP"

echo "🔧 Fixing theme toggle..."

# Replace the window.load event listener with DOMContentLoaded
sed -i '' 's/window\.addEventListener.*.load.*/document.addEventListener("DOMContentLoaded", () => {/' "$FILE"

echo "✅ Applied fix 1: DOMContentLoaded"

# Create a Python script to do the more complex edit (adding inline script)
python3 << 'EOFPYTHON'
import re

file_path = "public/dashboard/index.html"

with open(file_path, 'r') as f:
    content = f.read()

# Add inline theme script right before </head>
inline_script = '''    <script>
try {
  const theme = localStorage.getItem('theme') || 'light';
  document.documentElement.setAttribute('data-theme', theme);
} catch (e) {}
</script>
  </head>'''

# Replace the closing head tag
content = content.replace('  </head>', inline_script)

with open(file_path, 'w') as f:
    f.write(content)

print("✅ Applied fix 2: Inline theme script")
EOFPYTHON

echo "✅ Theme toggle fixed!"
echo "   • DOMContentLoaded instead of load event"
echo "   • Inline script prevents theme flashing"
echo "   • Backup: $BACKUP"

# Show what changed
echo ""
echo "Preview of changes:"
grep -n "inline\|DOMContentLoaded" "$FILE" | head -5

