#!/usr/bin/env bash
# scripts/03_ukentlig_statusmelding.sh
#
# Bygger den ukentlige Bonusvarsel-statusmeldingen (norsk, emoji-seksjoner)
# fra live, read-only data på Railway-backenden, og sender den til Telegram
# via det eksisterende /v1/push/send-test-endepunktet (som selv bruker
# TG_BOT_TOKEN/TG_CHAT_ID fra Railway sine miljøvariabler — token rører
# aldri dette scriptet).
#
# Bruk:
#   ./03_ukentlig_statusmelding.sh            -> viser meldingen (dry-run, sender IKKE)
#   ./03_ukentlig_statusmelding.sh --send      -> sender meldingen til Telegram
#
# Dette er nøyaktig samme logikk den ukentlige planlagte oppgaven (Claude
# scheduled task) skal kjøre hver mandag kl 09:00.

set -euo pipefail

BASE="https://bonusvarsel-production.up.railway.app"
SEND=false
if [[ "${1:-}" == "--send" ]]; then
  SEND=true
fi

health=$(curl -sS -m 15 "$BASE/health")
campaigns=$(curl -sS -m 15 "$BASE/api/campaigns")
devices=$(curl -sS -m 15 "$BASE/v1/devices/favorites")

# --- Trekk ut tall med jq ---
total=$(echo "$campaigns" | jq -r '.count')
trumf=$(echo "$campaigns" | jq -r '.trumfCount')
sas=$(echo "$campaigns" | jq -r '.sasCount')
elite=$(echo "$campaigns" | jq -r '.eliteCount')

cached_keys=$(echo "$health" | jq -r '.sentKeys.cachedKeys')
checks_run=$(echo "$health" | jq -r '.monitor.checksRun')
alerts_sent=$(echo "$health" | jq -r '.monitor.alertsSent')
active_issues=$(echo "$health" | jq -r '.monitor.activeIssues | length')
sas_live=$(echo "$health" | jq -r '.monitor.lastResult.sas')

n_elite=$(echo "$devices" | jq '[.devices[] | select(.tier=="elite")] | length')
n_premium=$(echo "$devices" | jq '[.devices[] | select(.tier=="premium")] | length')
n_free=$(echo "$devices" | jq '[.devices[] | select(.tier=="free")] | length')
n_devices=$(echo "$devices" | jq '.devices | length')

if [[ "$active_issues" -gt 0 ]]; then
  status_line="🔴 ${active_issues} aktivt problem i overvåkingen"
elif [[ "$sas_live" -eq 0 ]]; then
  status_line="🟡 SAS/LoyaltyKey leverer 0 kampanjer akkurat nå"
else
  status_line="🟢 Alt ser normalt ut"
fi

title="📊 Bonusvarsel – ukestatus ($(date +%d.%m.%Y))"
msg=$(cat <<EOF
${status_line}
🎯 ${total} aktive kampanjer (${trumf} Trumf / ${sas} SAS / ${elite} Elite)
👥 ${n_devices} enheter: ${n_elite} Elite, ${n_premium} Premium, ${n_free} Free
🔁 ${cached_keys} kampanjenøkler i dedup-minnet (kumulativt)
🛰️ Overvåking: ${checks_run} sjekker kjørt, ${alerts_sent} varsler totalt, ${active_issues} aktive nå
EOF
)

echo "----- FORMATERT MELDING (slik den vil se ut i Telegram, inkl. /v1/push/send-test sin egen 🔔-innpakning) -----"
echo "🔔 ${title}"
echo "$msg"
echo "--------------------------------------------------------------------------------------------------------"

if $SEND; then
  echo "Sender til Telegram via /v1/push/send-test ..."
  resp=$(curl -sS -m 15 -X POST "$BASE/v1/push/send-test" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg t "$title" --arg m "$msg" '{title: $t, message: $m}')")
  echo "Svar fra server: $resp"
else
  echo "(Dry-run — ikke sendt. Kjør med --send for å faktisk sende til Telegram.)"
fi
