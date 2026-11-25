#!/usr/bin/env bash
# scripts/04_legg_til_spenn_kampanjekilde.sh
#
# Legger Spenn (spenngroup.com sitt poengprogram - Norwegian/Strawberry/
# REMA 1000/Uno-X/Widerøe m.fl.) inn i Bonusvarsel som en ny kampanjekilde,
# på linje med Trumf og SAS EuroBonus.
#
# VIKTIG kontekst (se minnenotat bonusvarsel-spenn-monitor):
#   - Spenn har INGEN offentlig API/tilbudsfeed. Kilden her er
#     spennjeger.no, en uoffisiell fan-side (WordPress). Kun de
#     tabell-formaterte "SuperSpenn"-roundup-innleggene parses pålitelig -
#     andre innleggsformater (enkelt-partner-kunngjøringer med
#     Stackable-blokker) hoppes bevisst over fremfor å gjette feil data.
#   - Dette er en SKJØR kilde. Hvis spennjeger.no endrer HTML-format,
#     slutter parseren å finne kampanjer (den feiler aldri hardt - den
#     returnerer bare tom liste, se fetchSpennCampaigns()'s try/catch).
#   - Spenn-kampanjer sendes til ALLE enheter uansett tier/favoritter (som
#     Trippel Trumf-varselet), siden appen ikke har favoritt-UI for Spenn
#     ennå. Dedup skjer per enhet+butikk-slug i sentKeysStore, så samme
#     kampanje varsles kun én gang per enhet.
#
# Testet (29.-30. sept 2026, Claude): fetchSpennCampaigns()-logikken kjørt
# standalone mot spennjeger.no sin faktiske sitemap+innlegg og verifisert å
# gi 5 korrekte kampanjer (Uno-X, Rema 1000, Norwegian, Strawberry,
# Widerøe fra "15-16-september-superspenn") og 0 falske treff fra to andre
# nylige innlegg uten tabellformat. `node --check` kjøres på patchet fil
# nedenfor før scriptet erklærer suksess.
#
# Bruk: kjør fra roten av bonusvarsel-repoet (der api/server.js finnes).
#   ./scripts/04_legg_til_spenn_kampanjekilde.sh
#
# Sjekk ALLTID `git status`/`git diff` FØR du kjører dette (flere
# parallelle Claude-økter jobber ofte i samme repo uten å synkronisere).
# Scriptet lager en backup (api/server.js.bak-<timestamp>) og ruller
# automatisk tilbake hvis node --check feiler etter patching.

set -euo pipefail

TARGET="api/server.js"
if [[ ! -f "$TARGET" ]]; then
  echo "FEIL: fant ikke $TARGET - kjør scriptet fra roten av bonusvarsel-repoet." >&2
  exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP="${TARGET}.bak-${TS}"
cp "$TARGET" "$BACKUP"
echo "Backup laget: $BACKUP"

set +e
python3 - "$TARGET" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    src = f.read()

def replace_once(src, old, new, label):
    count = src.count(old)
    if count != 1:
        print(f"FEIL: fant {count} forekomster av ankeret for '{label}' (forventet nøyaktig 1).", file=sys.stderr)
        print("Sannsynlig årsak: api/server.js har endret seg siden dette scriptet ble laget.", file=sys.stderr)
        print("Ingen endringer gjort for dette steget - resten av scriptet avbrytes.", file=sys.stderr)
        sys.exit(2)
    return src.replace(old, new, 1)

# ── Patch 1: bvOfferLink/bvPortalLabel/bvPortalColor/bvPointsText ───────────
old1 = """function bvOfferLink(c) {
  if (c.source === 'trumf') return TRUMF_HOME;
  return SAS_HOME;
}
function bvPortalLabel(c) {
  return c.source === 'trumf' ? 'Trumf Netthandel' : 'SAS Online Shopping';
}
function bvPortalColor(c) {
  return c.source === 'trumf' ? '#1F7A4D' : '#0F2340';
}
function bvPointsText(c) {
  if (c.source === 'trumf') return 'ekstra Trumf-bonus nå';
  if (c.source === 'sas')   return 'ekstra EuroBonus-poeng nå';
  return 'kampanje nå';
}"""

new1 = """function bvOfferLink(c) {
  if (c.source === 'trumf') return TRUMF_HOME;
  if (c.source === 'spenn') return c.url || 'https://spenngroup.com/nb-NO/home';
  return SAS_HOME;
}
function bvPortalLabel(c) {
  if (c.source === 'spenn') return 'Spenn';
  return c.source === 'trumf' ? 'Trumf Netthandel' : 'SAS Online Shopping';
}
function bvPortalColor(c) {
  if (c.source === 'spenn') return '#7C3AED';
  return c.source === 'trumf' ? '#1F7A4D' : '#0F2340';
}
function bvPointsText(c) {
  if (c.source === 'trumf') return 'ekstra Trumf-bonus nå';
  if (c.source === 'sas')   return 'ekstra EuroBonus-poeng nå';
  if (c.source === 'spenn') return 'Spenn-kampanje nå (uoffisiell kilde)';
  return 'kampanje nå';
}"""

src = replace_once(src, old1, new1, "bvOfferLink/bvPortalLabel/bvPortalColor/bvPointsText")

# ── Patch 2: LOYALTY_PROGRAMS (forward-kompatibel hvis appen får Spenn-favoritter senere) ──
old2 = """const LOYALTY_PROGRAMS = {
  trumf: { prefix: 'tn_', label: 'Trumf' },
  sas: { prefix: 'sas_', label: 'SAS EuroBonus' },
};"""

new2 = """const LOYALTY_PROGRAMS = {
  trumf: { prefix: 'tn_', label: 'Trumf' },
  sas: { prefix: 'sas_', label: 'SAS EuroBonus' },
  spenn: { prefix: 'spenn_', label: 'Spenn' },
};"""

src = replace_once(src, old2, new2, "LOYALTY_PROGRAMS")

# ── Patch 3: fetchAllCampaigns() - legg til Spenn-kilden ────────────────────
old3 = """async function fetchAllCampaigns(plan = 'free') {
  const [sasCampaigns, trumfCampaigns, eliteCampaigns] = await Promise.all([
    fetchCampaigns(),
    fetchTrumfCampaigns(),
    fetchEliteCampaigns(),
  ]);

  const all = [
    ...sasCampaigns.map(c => ({ ...c, source: 'sas', minPlan: 'free' })),
    ...trumfCampaigns.map(c => ({ ...c, source: 'trumf', minPlan: 'free' })),
    ...eliteCampaigns.map(c => ({ ...c, source: 'elite', minPlan: 'elite' })),
  ];"""

new3 = """async function fetchAllCampaigns(plan = 'free') {
  const [sasCampaigns, trumfCampaigns, eliteCampaigns, spennCampaigns] = await Promise.all([
    fetchCampaigns(),
    fetchTrumfCampaigns(),
    fetchEliteCampaigns(),
    fetchSpennCampaigns(),
  ]);

  const all = [
    ...sasCampaigns.map(c => ({ ...c, source: 'sas', minPlan: 'free' })),
    ...trumfCampaigns.map(c => ({ ...c, source: 'trumf', minPlan: 'free' })),
    ...eliteCampaigns.map(c => ({ ...c, source: 'elite', minPlan: 'elite' })),
    ...spennCampaigns.map(c => ({ ...c, source: 'spenn', minPlan: 'free' })),
  ];"""

src = replace_once(src, old3, new3, "fetchAllCampaigns()")

# ── Patch 4: sett inn fetchSpennCampaigns()-funksjonen rett før kombinasjonskommentaren ──
anchor4 = "// ── Kombiner alle kampanjer med abonnement-filtrering ────────────────────────\nasync function fetchAllCampaigns(plan = 'free') {"

spenn_fn = '''// ── Spenn (spenngroup.com poeng-program) kampanjer ──────────────────────────
// Ingen offentlig API/feed finnes for Spenn (bekreftet sept. 2026: /api/ er
// robots.txt-sperret, ingen offentlig kampanjeside). Kilde her er
// spennjeger.no, en uoffisiell fan-side (WordPress). Kun de
// tabell-formaterte "SuperSpenn"-roundup-innleggene (figure.wp-block-table)
// parses pålitelig - andre innleggsformater (enkelt-partner-kunngjøringer
// med Stackable-page-builder-blokker) hoppes bevisst over fremfor å gjette
// feil data. Skjør kilde - forvent jevnlig vedlikehold hvis spennjeger.no
// endrer HTML-format. Feiler aldri hardt - returnerer tom liste ved feil,
// akkurat som fetchTrumfCampaigns()/fetchCampaigns().
async function fetchSpennCampaigns() {
  try {
    const sitemapRes = await fetch("https://spennjeger.no/wp-sitemap-posts-post-1.xml", {
      headers: { "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" },
    });
    if (!sitemapRes.ok) throw new Error(`Spenn sitemap feilet: ${sitemapRes.status}`);
    const sitemapXml = await sitemapRes.text();
    const $sitemap = cheerio.load(sitemapXml, { xmlMode: true });

    const posts = [];
    $sitemap("url").each((_, el) => {
      const loc = $sitemap(el).find("loc").text().trim();
      const lastmod = $sitemap(el).find("lastmod").text().trim();
      if (loc) posts.push({ loc, lastmod: new Date(lastmod) });
    });

    // Kun de 3 nyeste innleggene - roundup-poster kommer sjelden (~1x/uke),
    // og eldre innlegg er uansett utløpte kampanjer.
    posts.sort((a, b) => b.lastmod - a.lastmod);
    const recentPosts = posts.slice(0, 3);

    const mapped = [];
    for (const post of recentPosts) {
      try {
        const postRes = await fetch(post.loc, {
          headers: { "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" },
        });
        if (!postRes.ok) continue;
        const html = await postRes.text();
        const $ = cheerio.load(html);
        const postSlug = post.loc.replace(/\\/$/, "").split("/").pop();

        $("figure.wp-block-table td").each((i, td) => {
          const $td = $(td);
          const rawText = $td.text().replace(/\\s+/g, " ").trim();
          if (!rawText) return;

          const multMatch = rawText.match(/(\\d+(?:[.,]\\d+)?)\\s*x\\s*Spenn/i);
          if (!multMatch) return; // ingen "Nx Spenn"-mønster -> ikke en kampanjerad (f.eks. intro-avsnitt)
          const multiplier = parseFloat(multMatch[1].replace(",", "."));
          if (!Number.isFinite(multiplier) || multiplier <= 1) return;

          const nameMatch = rawText.match(/^([A-ZÆØÅ0-9][A-ZÆØÅ0-9 .&-]{1,30}?)(?=[A-ZÆØÅ][a-zæøå]|\\d+x|Tjen|Planlegg|Kjøp|Book)/);
          const merchantNameRaw = (nameMatch ? nameMatch[1] : rawText.slice(0, 24)).trim().replace(/[-\\s]+$/, "");
          if (!merchantNameRaw) return;

          const merchantName = merchantNameRaw
            .toLowerCase()
            .replace(/(^|[\\s-])([a-zæøå])/g, (m, sep, ch) => sep + ch.toUpperCase());

          const merchantSlug = merchantNameRaw
            .toLowerCase()
            .replace(/æ/g, "ae").replace(/ø/g, "o").replace(/å/g, "a")
            .replace(/[^a-z0-9]+/g, "-")
            .replace(/^-+|-+$/g, "");
          if (!merchantSlug) return;

          mapped.push({
            id: `spenn-${postSlug}-${merchantSlug}-${i}`,
            title: `${merchantName} (Spenn)`,
            multiplier,
            url: post.loc,
            slug: `spenn_${merchantSlug}`,
          });
        });
      } catch (innerErr) {
        console.error(`fetchSpennCampaigns: innlegg ${post.loc} feilet:`, String(innerErr));
      }
    }

    const seen = new Set();
    const deduped = mapped.filter((c) => {
      if (seen.has(c.slug)) return false;
      seen.add(c.slug);
      return true;
    });

    console.log("fetchSpennCampaigns skrapet:", deduped.length, "kampanjer (uoffisiell kilde spennjeger.no)");
    return deduped;
  } catch (e) {
    console.error("fetchSpennCampaigns feilet:", String(e));
    return [];
  }
}


// ── Kombiner alle kampanjer med abonnement-filtrering ────────────────────────
async function fetchAllCampaigns(plan = 'free') {'''

count4 = src.count(anchor4)
if count4 != 1:
    print(f"FEIL: fant {count4} forekomster av ankeret for 'fetchSpennCampaigns()-innsetting' (forventet nøyaktig 1).", file=sys.stderr)
    sys.exit(2)
src = src.replace(anchor4, spenn_fn, 1)

# ── Patch 5: broadcast-varsel for nye Spenn-kampanjer i checkFavoritesAndNotify() ──
old5 = """          await sentKeysStore.add(ttKey);
        }
      }

      const newCampaigns = [];"""

new5 = """          await sentKeysStore.add(ttKey);
        }
      }

      // Spenn: kampanjer sendes til ALLE enheter uansett tier/favoritter
      // (som Trippel Trumf over), siden appen ikke har favoritt-UI for
      // Spenn ennå. Dedup per enhet+butikk-slug i sentKeysStore.
      const spennCampaignsForDevice = campaigns.filter((c) => c.source === 'spenn');
      for (const sc of spennCampaignsForDevice) {
        const spennKey = `${deviceId}-spenn-${sc.slug || sc.id}`;
        if (sentKeysStore.has(spennKey)) continue;
        const tgChatIdSpenn = telegramDeviceStore.get(deviceId) || (favs.telegram ? telegramLinkStore.get(favs.telegram) : null);
        const spennMsg = `🟣 <b>Ny Spenn-kampanje</b>\\n\\n${bvTelegramLine(sc)}\\n\\n<i>Kilde: uoffisiell (spennjeger.no) - sjekk Spenn-appen for detaljer.</i>`;
        if (tgChatIdSpenn) await sendTelegram(spennMsg, tgChatIdSpenn);
        if (favs.email) {
          const spennHtml = `<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:24px;"><h2 style="color:#0F2340;">🟣 Ny Spenn-kampanje</h2>${bvOfferCard(sc)}<p style="color:#94A3B8;font-size:12px;">Kilde: uoffisiell (spennjeger.no) - sjekk Spenn-appen for detaljer.</p></div>`;
          await sendEmail(favs.email, '🟣 Bonusvarsel – ny Spenn-kampanje', spennHtml);
        }
        await sentKeysStore.add(spennKey);
      }

      const newCampaigns = [];"""

src = replace_once(src, old5, new5, "checkFavoritesAndNotify() Spenn-broadcast")

with open(path, "w", encoding="utf-8") as f:
    f.write(src)

print("Alle 5 patcher applisert OK.")
PYEOF
PATCH_STATUS=$?
set -e

if [[ $PATCH_STATUS -ne 0 ]]; then
  echo "Patching feilet (se feilmelding over). $TARGET er IKKE rørt (python-scriptet skriver kun til fil helt til slutt, etter at alle 5 patcher er bekreftet)." >&2
  echo "Ingen tilbakerulling nødvendig - backupen på $BACKUP kan slettes." >&2
  exit 1
fi

echo "Kjører node --check for syntaksvalidering ..."
if node --check "$TARGET"; then
  echo "PATCH_OK: $TARGET er syntaktisk gyldig etter patching."
  echo "Backup ligger fortsatt på $BACKUP i tilfelle du vil sammenligne."
  echo ""
  echo "Neste steg (gjør IKKE dette automatisk):"
  echo "  1. git diff api/server.js   # se nøyaktig hva som endret seg"
  echo "  2. Test lokalt om mulig, eller stol på testingen beskrevet i toppen av dette scriptet"
  echo "  3. git add api/server.js && git commit -m 'Legg til Spenn som kampanjekilde' && git push"
  echo "  4. Railway redeployer automatisk ved push til local-stable-baseline (bekreft i Railway-dashbordet)"
else
  echo "FEIL: node --check feilet etter patching - ruller tilbake fra backup." >&2
  cp "$BACKUP" "$TARGET"
  exit 1
fi
