#!/bin/bash
# ============================================================================
# 03_hent_varslingslogikk.sh
#
# Formål: KUN LESING - endrer ingenting. Henter ut koden som styrer:
#   1. checkFavoritesAndNotify() - selve varslingsfunksjonen
#   2. Tier-logikken (free/premium/elite) rundt favoritter
#   3. Alt som nevner SkyTeam, elite, bonusreiser, SAS Holidays
#
# Grunnen til at vi gjør dette: for å svare presist på om gratis-brukere
# (uten favoritter) får varsel ved ny Trumf/SAS-kampanje, og om Elite-
# brukere får Telegram-varsel spesifikt for bonusreiser/SkyTeam, må vi se
# den faktiske koden - ikke gjette basert på tidligere notater.
#
# Kjør slik:
#   cd /Users/sunnerehelse/bonusvarsel
#   bash scripts/03_hent_varslingslogikk.sh
#
# Lim inn HELE output i chatten etterpå.
# ============================================================================

set -euo pipefail

TARGET_FILE="api/server.js"

if [ ! -f "$TARGET_FILE" ]; then
  echo "❌ Fant ikke $TARGET_FILE i gjeldende mappe."
  echo "   Kjør fra roten av bonusvarsel-repoet:"
  echo "   cd /Users/sunnerehelse/bonusvarsel && bash scripts/03_hent_varslingslogikk.sh"
  exit 1
fi

echo "================================================================"
echo "1) checkFavoritesAndNotify - funksjonssignatur og start (50 linjer)"
echo "================================================================"
grep -n -A50 "function checkFavoritesAndNotify" "$TARGET_FILE" || echo "(ikke funnet med dette navnet)"

echo ""
echo "================================================================"
echo "2) Alle treff på 'tier' (free/premium/elite-logikk), med kontekst"
echo "================================================================"
grep -n -i -B1 -A3 "tier" "$TARGET_FILE" | head -150

echo ""
echo "================================================================"
echo "3) Alle treff på skyteam/elite/bonusreise/holidays (case-insensitive)"
echo "================================================================"
grep -n -i -B1 -A3 "skyteam\|elite\|bonusreise\|holidays" "$TARGET_FILE" | head -150

echo ""
echo "================================================================"
echo "4) Alle treff på 'favorites' i variabelnavn/betingelser (topp-nivå oversikt)"
echo "================================================================"
grep -n "deviceFavorites\|hasFavorites\|favorites.length\|favorites\.length" "$TARGET_FILE" | head -50

echo ""
echo "================================================================"
echo "FERDIG - kopier ALT ovenfor og lim inn i chatten"
echo "================================================================"
