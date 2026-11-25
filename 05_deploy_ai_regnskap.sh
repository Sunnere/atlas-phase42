#!/bin/bash
# =====================================================
# BonusVarsel AI Regnskap — Deploy til Firebase
# URL: https://bonusvarsel-ai-regnskap.web.app
# =====================================================
# 1. Opprett prosjektet på console.firebase.google.com
#    Navn: bonusvarsel-ai-regnskap
# 2. Last ned index.html fra Claude til ~/Downloads/
# 3. Kjør: bash ~/Downloads/05_deploy_ai_regnskap.sh
# =====================================================

set -e

PROJECT_ID="bonusvarsel-ai-regnskap"
DEPLOY_DIR="$HOME/bonusvarsel-ai-regnskap-deploy"

echo "════════════════════════════════════════════════"
echo "  BonusVarsel AI Regnskap — Deploy"
echo "  → https://bonusvarsel-ai-regnskap.web.app"
echo "════════════════════════════════════════════════"
echo ""

command -v firebase >/dev/null 2>&1 || { echo "❌ Firebase CLI mangler. Kjør: npm install -g firebase-tools"; exit 1; }

echo "🔍 Sjekker Firebase-innlogging..."
firebase projects:list 2>/dev/null | grep -q "$PROJECT_ID" || {
  echo "⚠️  Prosjektet '$PROJECT_ID' ikke funnet."
  echo "   Gå til console.firebase.google.com og opprett det først."
  echo "   Deretter kjør dette scriptet på nytt."
  exit 1
}

echo "✅ Firebase OK — prosjekt: $PROJECT_ID"
echo ""

rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR/public"

cat > "$DEPLOY_DIR/firebase.json" << 'EOF'
{
  "hosting": {
    "public": "public",
    "ignore": ["firebase.json", "**/.*"],
    "headers": [
      {
        "source": "**",
        "headers": [
          { "key": "Cache-Control", "value": "no-cache" },
          { "key": "Access-Control-Allow-Origin", "value": "*" }
        ]
      }
    ]
  }
}
EOF

cat > "$DEPLOY_DIR/.firebaserc" << EOF
{
  "projects": {
    "default": "$PROJECT_ID"
  }
}
EOF

if [ -f "$HOME/Downloads/index.html" ]; then
  cp "$HOME/Downloads/index.html" "$DEPLOY_DIR/public/index.html"
  echo "✅ index.html kopiert"
else
  echo "❌ Fant ikke ~/Downloads/index.html"
  echo "   Last ned filen fra Claude og legg den i ~/Downloads/"
  exit 1
fi

cd "$DEPLOY_DIR"
firebase use "$PROJECT_ID"
echo "🚀 Deployer..."
firebase deploy --only hosting --project "$PROJECT_ID"

echo ""
echo "════════════════════════════════════════════════"
echo "  ✅ LIVE!"
echo ""
echo "  🔗 https://bonusvarsel-ai-regnskap.web.app"
echo "════════════════════════════════════════════════"
