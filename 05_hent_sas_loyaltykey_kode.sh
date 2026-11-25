#!/bin/bash
# ============================================================================
# 05_hent_sas_loyaltykey_kode.sh
#
# Formål: KUN LESING - endrer ingenting. Henter ut koden som henter SAS-
# kampanjer via LoyaltyKey-API-et, fordi overvåkingen meldte:
#   "SAS/LoyaltyKey leverer 0 kampanjer (Trumf 17 / Elite 1 er OK).
#    LoyaltyKey-API-et er trolig nede eller har endret format."
#
# For å finne rotårsaken (API faktisk nede/endret format vs. en bug i vår
# egen håndtering) trenger vi å se:
#   1. fetchCampaigns() - selve SAS/LoyaltyKey-kallet
#   2. Alle steder LOYALTYKEY nevnes (URL, API-nøkkel-bruk, headers)
#   3. Feilhåndtering rundt kallet (try/catch, retries, logging)
#   4. Overvåkingsfunksjonen som sender "SAS/LoyaltyKey leverer 0 kampanjer"
#      -varselet, for å se nøyaktig hvilken sjekk som trigget
#
# Kjør slik:
#   cd /Users/sunnerehelse/bonusvarsel
#   bash scripts/05_hent_sas_loyaltykey_kode.sh
#
# Lim inn HELE output i chatten etterpå.
# ============================================================================

set -euo pipefail

TARGET_FILE="api/server.js"

if [ ! -f "$TARGET_FILE" ]; then
  echo "❌ Fant ikke $TARGET_FILE i gjeldende mappe."
  echo "   Kjør fra roten av bonusvarsel-repoet:"
  echo "   cd /Users/sunnerehelse/bonusvarsel && bash scripts/05_hent_sas_loyaltykey_kode.sh"
  exit 1
fi

echo "================================================================"
echo "1) fetchCampaigns - funksjonssignatur og innhold (80 linjer)"
echo "================================================================"
grep -n -A80 "^async function fetchCampaigns\|^function fetchCampaigns" "$TARGET_FILE" || echo "(ikke funnet med dette navnet - prøver bredere søk under)"

echo ""
echo "================================================================"
echo "2) Alle treff på LOYALTYKEY / loyaltykey (case-insensitive), med kontekst"
echo "================================================================"
(grep -n -i -B2 -A6 "loyaltykey" "$TARGET_FILE" || echo "(ingen treff)") | head -200

echo ""
echo "================================================================"
echo "3) Alle treff på 'catch' i nærheten av fetchCampaigns/SAS (feilhåndtering)"
echo "================================================================"
(grep -n -B5 -A10 "catch.*[Ee]rr" "$TARGET_FILE" | grep -B5 -A10 -i "sas\|loyaltykey") | head -150 || echo "(ingen treff)"

echo ""
echo "================================================================"
echo "4) Overvåkingslogikk - søk etter 'leverer 0 kampanjer' / 'trolig nede'"
echo "================================================================"
grep -n -B10 -A10 "leverer 0 kampanjer\|trolig nede\|endret format" "$TARGET_FILE" || echo "(ikke funnet - kan ligge i en annen fil, f.eks. et eget monitor-script)"

echo ""
echo "================================================================"
echo "5) Miljøvariabler knyttet til LoyaltyKey/SAS (kun NAVN, ikke verdier)"
echo "================================================================"
grep -n -o "process\.env\.[A-Z_]*LOYALTY[A-Z_]*\|process\.env\.[A-Z_]*SAS[A-Z_]*" "$TARGET_FILE" | sort -u || echo "(ingen treff)"

echo ""
echo "================================================================"
echo "FERDIG - kopier ALT ovenfor og lim inn i chatten"
echo "================================================================"
