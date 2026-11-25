#!/bin/bash
# =====================================================
# BonusVarsel AI Booking — Deploy til Firebase
# Prosjekt: bonusvarsel-ai-booking
# URL: https://bonusvarsel-ai-booking.web.app
# =====================================================
# Kjør fra terminalen:
#   bash ~/Downloads/04_deploy_ai_booking.sh
# =====================================================

set -e

PROJECT_ID="bonusvarsel-ai-booking"
DEPLOY_DIR="$HOME/bonusvarsel-ai-booking-deploy"

echo "════════════════════════════════════════════════"
echo "  BonusVarsel AI Booking — Deploy"
echo "  → https://bonusvarsel-ai-booking.web.app"
echo "════════════════════════════════════════════════"
echo ""

# Sjekk Firebase CLI
command -v firebase >/dev/null 2>&1 || {
  echo "❌ Firebase CLI mangler."
  echo "   Kjør: npm install -g firebase-tools"
  exit 1
}

# Sjekk innlogget
echo "🔍 Sjekker Firebase-innlogging..."
firebase projects:list 2>/dev/null | grep -q "$PROJECT_ID" || {
  echo "⚠️  Logger inn på Firebase..."
  firebase login
}

echo "✅ Firebase OK — prosjekt: $PROJECT_ID"
echo ""

# Lag deploy-mappe
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR/public"

# firebase.json
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

# .firebaserc med riktig prosjekt
cat > "$DEPLOY_DIR/.firebaserc" << EOF
{
  "projects": {
    "default": "$PROJECT_ID"
  }
}
EOF

# Kopier demo-filen
if [ -f "$HOME/Downloads/index.html" ]; then
  cp "$HOME/Downloads/index.html" "$DEPLOY_DIR/public/index.html"
  echo "✅ index.html kopiert"
else
  echo "❌ Fant ikke ~/Downloads/index.html"
  echo "   Last ned index.html fra Claude og legg den i ~/Downloads/"
  exit 1
fi

echo ""

# Aktiver Hosting i Firebase
echo "🔧 Setter opp Firebase Hosting..."
cd "$DEPLOY_DIR"
firebase use "$PROJECT_ID"

# Deploy
echo "🚀 Deployer..."
firebase deploy --only hosting --project "$PROJECT_ID"

echo ""
echo "════════════════════════════════════════════════"
echo "  ✅ LIVE!"
echo ""
echo "  🔗 https://bonusvarsel-ai-booking.web.app"
echo ""
echo "  Send denne til salongene!"
echo "════════════════════════════════════════════════"
