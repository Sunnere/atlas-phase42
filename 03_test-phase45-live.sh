#!/bin/bash

DOMAIN="https://atlas.bonusvarsel.no"
TIMEOUT=30

echo "🧪 Testing Phase 4.5 & 4.6 Endpoints"
echo "======================================"
echo ""

# Test 1: /api/health
echo "1️⃣  Testing /api/health..."
RESPONSE=$(curl -s -w "\n%{http_code}" "$DOMAIN/api/health" --max-time $TIMEOUT)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Status 200 (OK)"
else
    echo "❌ Status $HTTP_CODE - $(echo "$BODY" | head -c 60)"
fi
echo ""

# Test 2: /api/risk/stats (Phase 4.5)
echo "2️⃣  Testing /api/risk/stats (Phase 4.5)..."
RESPONSE=$(curl -s -w "\n%{http_code}" "$DOMAIN/api/risk/stats" --max-time $TIMEOUT)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Status 200 - Phase 4.5 is LIVE"
else
    echo "❌ Status $HTTP_CODE - $(echo "$BODY" | head -c 60)"
fi
echo ""

# Test 3: POST /api/risk/assess (Phase 4.5)
echo "3️⃣  Testing POST /api/risk/assess (Phase 4.5)..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$DOMAIN/api/risk/assess" \
  -H "Content-Type: application/json" \
  -d '{"amount": 1000, "merchant_id": "test123", "user_velocity": 5}' \
  --max-time $TIMEOUT)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Status 200 - Assessment working"
else
    echo "❌ Status $HTTP_CODE - $(echo "$BODY" | head -c 60)"
fi
echo ""

echo "======================================"
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Phase 4.5 & 4.6 is LIVE in production"
else
    echo "❌ Still running Phase 4.2 — wait 1-2 min for deploy to complete"
fi
