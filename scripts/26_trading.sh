#!/usr/bin/env bash
# ATLAS Matrix: «Trading»-agent – aksjeroboten (IBKR papirkonto) inn på skjermen.
#  - agent «trading»: avkastning mot S&P 500 (SPY), posisjoner, solgte handler, driftsstatus og varsler
#  - tools/trading/atlas_feed.py: kjører på Macen og sender tallene (kopieres til ~/aksjesignaler)
#  - daily_run.sh i aksjesignaler: får én linje som kjører feederen etter roboten (kl. 16:00)
#  - jarvis.html: node «Trading» (klikk = tabell), briefing: ny seksjon
# Kjør fra roten av atlas-phase42:  bash scripts/26_trading.sh
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f src/agents/coordinator.js ] && [ -f src/agents/briefing.js ] && [ -f public/dashboard/jarvis.html ] || { echo "Feil: kjør fra roten av atlas-phase42"; exit 1; }

cat > src/agents/handlers/tradingAgent.js <<'JS_EOF'
// Trading-agent: leser tall fra aksjeroboten (papirkonto) og måler den mot S&P 500 (SPY).
// Ingen eksterne kall her. Dataene leveres av tools/trading/atlas_feed.py på Macen:
//   asOf: ISO-tid
//   usdNok: kurs (valgfri)
//   totals: { costUsd, valueUsd, spyUsd }
//   positions: [{ sym, qty, costUsd, valueUsd, priced }]
//   sold: [{ sym, qty, costUsd, proceedsUsd, spyUsd }]
//   health: { lastRunStatus, lastRunMessage, hoursSinceRun, signalsAgeHours, signalRows, hoursSinceOrder }
// Kun måling og varsler. Ingen handelsråd.
const RUN_PROBLEMS = {
  ikke_innlogget: "IB Gateway er ikke innlogget. Roboten handler ikke før den er logget inn (husk ⌘Q på IBKR Desktop).",
  ibkr_stille: "IBKR svarte ikke ved siste kjøring.",
  signaler: "Signalene kunne ikke hentes ved siste kjøring.",
  feil: "Roboten feilet ved siste kjøring. Se loggen i aksjesignaler/logs.",
};
const MAX_SIGNAL_AGE_H = 36;
const MIN_SIGNAL_ROWS = 10;
const STALE_RUN_H = 80; // helg + litt slingringsmonn
const BIG_LOSS_PCT = -15;

function num(v, name) {
  const n = Number(v);
  if (!Number.isFinite(n)) throw new Error(`${name} må være et tall`);
  return n;
}
const r1 = (x) => Math.round(x * 10) / 10;
const r0 = (x) => Math.round(x);

function assessTrading(p) {
  if (!p || typeof p !== "object") throw new Error("payload mangler");
  if (!p.totals || typeof p.totals !== "object") throw new Error("totals mangler");
  const cost = num(p.totals.costUsd, "totals.costUsd");
  const value = num(p.totals.valueUsd, "totals.valueUsd");
  const spy = num(p.totals.spyUsd, "totals.spyUsd");
  if (cost <= 0) throw new Error("totals.costUsd må være over 0");
  const usdNok = p.usdNok === undefined ? 10 : num(p.usdNok, "usdNok");

  const positions = (Array.isArray(p.positions) ? p.positions : []).map((x) => {
    if (!x || typeof x.sym !== "string" || !x.sym) throw new Error("hver posisjon trenger sym");
    const c = num(x.costUsd, `${x.sym}.costUsd`);
    const v = num(x.valueUsd, `${x.sym}.valueUsd`);
    return { sym: x.sym, qty: Number(x.qty || 0), costUsd: r0(c), valueUsd: r0(v), pnlPct: c > 0 ? r1((v / c - 1) * 100) : 0, priced: x.priced !== false };
  });
  const sold = (Array.isArray(p.sold) ? p.sold : []).map((x) => {
    if (!x || typeof x.sym !== "string" || !x.sym) throw new Error("hver solgt post trenger sym");
    const c = num(x.costUsd, `${x.sym}.costUsd`);
    const f = num(x.proceedsUsd, `${x.sym}.proceedsUsd`);
    return { sym: x.sym, qty: Number(x.qty || 0), costUsd: r0(c), proceedsUsd: r0(f), pnlPct: c > 0 ? r1((f / c - 1) * 100) : 0 };
  });

  const h = p.health && typeof p.health === "object" ? p.health : {};
  const health = {
    lastRunStatus: typeof h.lastRunStatus === "string" ? h.lastRunStatus : "ukjent",
    lastRunMessage: h.lastRunMessage ? String(h.lastRunMessage).slice(0, 200) : "",
    hoursSinceRun: Number.isFinite(Number(h.hoursSinceRun)) && h.hoursSinceRun !== null ? r1(Number(h.hoursSinceRun)) : null,
    signalsAgeHours: Number.isFinite(Number(h.signalsAgeHours)) && h.signalsAgeHours !== null ? r1(Number(h.signalsAgeHours)) : null,
    signalRows: Number.isFinite(Number(h.signalRows)) && h.signalRows !== null ? Number(h.signalRows) : null,
    hoursSinceOrder: Number.isFinite(Number(h.hoursSinceOrder)) && h.hoursSinceOrder !== null ? r1(Number(h.hoursSinceOrder)) : null,
  };

  const roboPct = r1((value / cost - 1) * 100);
  const spyPct = r1((spy / cost - 1) * 100);
  const diffUsd = r0(value - spy);
  const diffPct = spy > 0 ? r1((value / spy - 1) * 100) : 0;

  const flags = [];
  if (RUN_PROBLEMS[health.lastRunStatus]) flags.push({ typ: "drift", tekst: RUN_PROBLEMS[health.lastRunStatus] });
  if (health.hoursSinceRun !== null && health.hoursSinceRun > STALE_RUN_H) flags.push({ typ: "drift", tekst: `Roboten har ikke kjørt på ${Math.round(health.hoursSinceRun)} timer.` });
  if (health.signalsAgeHours !== null && health.signalsAgeHours > MAX_SIGNAL_AGE_H) flags.push({ typ: "drift", tekst: `Signalfilen er ${Math.round(health.signalsAgeHours)} timer gammel (grense ${MAX_SIGNAL_AGE_H}).` });
  if (health.signalRows !== null && health.signalRows < MIN_SIGNAL_ROWS) flags.push({ typ: "drift", tekst: `Signallisten har bare ${health.signalRows} rader (roboten nekter under ${MIN_SIGNAL_ROWS}).` });
  for (const x of positions.filter((y) => y.pnlPct <= BIG_LOSS_PCT)) flags.push({ typ: "tap", tekst: `${x.sym} er ${x.pnlPct} % fra kjøpskurs.` });
  for (const x of positions.filter((y) => !y.priced)) flags.push({ typ: "kurs", tekst: `Mangler kurs for ${x.sym}, verdsatt til kjøpspris.` });
  if (diffPct <= -2) flags.push({ typ: "marked", tekst: `Roboten ligger ${Math.abs(diffPct)} % under S&P 500 (${diffUsd} USD).` });

  const worst = positions.length ? positions.reduce((a, b) => (b.pnlPct < a.pnlPct ? b : a)) : null;
  return {
    asOf: typeof p.asOf === "string" ? p.asOf : null,
    usdNok,
    totals: { costUsd: r0(cost), valueUsd: r0(value), spyUsd: r0(spy) },
    roboPct, spyPct, diffUsd, diffPct, diffNok: r0(diffUsd * usdNok),
    positions, sold, worst, health, flags,
    source: "IBKR papirkonto + Nordnet-kurser",
  };
}

function checkTrading(result) {
  const problems = [];
  if (!result || !result.totals || !Number.isFinite(result.totals.costUsd) || result.totals.costUsd <= 0) problems.push("totals mangler");
  if (!result || !Number.isFinite(result.roboPct)) problems.push("avkastning mangler");
  return problems;
}

module.exports = { assessTrading, checkTrading };
JS_EOF
echo "tradingAgent.js skrevet"

mkdir -p tools/trading
cat > tools/trading/atlas_feed.py <<'PY_EOF'
#!/usr/bin/env python3
"""
Sender aksjeroboten sine tall til ATLAS Matrix (agent «trading»).

Ligger i ~/aksjesignaler og kjøres av daily_run.sh etter at roboten har kjørt.
Bruker bare standardbiblioteket. Henter kurser fra Nordnet via fasit.py.

  python atlas_feed.py            regn ut og send
  python atlas_feed.py --dry      regn ut og skriv ut, uten å sende
Valgfritt: ATLAS_URL, ATLAS_POST_KEY (om serveren krever nøkkel for POST).
"""
import json, os, re, sys, urllib.request
from datetime import datetime

HER = os.environ.get("ATLAS_TRADING_DIR") or os.path.dirname(os.path.abspath(__file__))
URL = os.environ.get("ATLAS_URL", "https://atlas.bonusvarsel.no/api/coordinator/tasks")
PRISFIL = os.environ.get("ATLAS_FEED_PRICES")   # kun til test: {"SYM": kurs, "SPY": kurs}


def les(navn, standard=None):
    try:
        with open(os.path.join(HER, navn), encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return standard


def spy_historikk():
    h = {}
    h.update(les("spy_dagskurs.json", {}) or {})
    return h


def spy_den_dagen(hist, dato):
    if dato in hist:
        return hist[dato]
    tidligere = sorted(d for d in hist if d <= dato)
    return hist[tidligere[-1]] if tidligere else None


def kurs_fra_nordnet(sym):
    sys.path.insert(0, HER)
    import fasit
    return fasit.nordnet_kurs(sym)


def hent_kurs(sym, priser):
    if sym in priser:
        return priser[sym]
    k = kurs_fra_nordnet(sym)
    priser[sym] = k
    return k


def regn(logg, hist, priser):
    ordrer = [o for o in logg.get("orders", [])
              if o.get("action") in ("BUY", "SELL") and o.get("mode") == "paper"
              and o.get("status") not in ("Cancelled", "Inactive", "ApiCancelled", "Error")]
    spy_naa = hent_kurs("SPY", priser)
    if not spy_naa:
        tid = sorted(hist)
        spy_naa = hist[tid[-1]] if tid else None
    if not spy_naa:
        raise SystemExit("Fikk ikke SPY-kurs")

    lots, solgt = {}, []
    for o in sorted(ordrer, key=lambda x: x["time"]):
        sym, q, p = o["symbol"], float(o["qty"]), float(o["limit"])
        dato = o["time"][:10]
        spy = spy_den_dagen(hist, dato)
        if spy is None:
            continue
        if o["action"] == "BUY":
            lots.setdefault(sym, []).append({"ant": q, "pris": p, "spy": spy})
        else:
            igjen = q
            for lot in lots.get(sym, []):
                if igjen <= 0 or lot["ant"] <= 0:
                    continue
                n = min(igjen, lot["ant"])
                lot["ant"] -= n
                igjen -= n
                solgt.append({"sym": sym, "qty": n, "kost": n * lot["pris"], "fikk": n * p,
                              "spy": n * lot["pris"] / lot["spy"] * spy})

    positions, sum_kost, sum_verdi, sum_spy = [], 0.0, 0.0, 0.0
    for sym, ls in lots.items():
        qty = sum(l["ant"] for l in ls)
        if qty <= 0:
            continue
        kost = sum(l["ant"] * l["pris"] for l in ls)
        spy_andeler = sum(l["ant"] * l["pris"] / l["spy"] for l in ls)
        kurs = hent_kurs(sym, priser)
        priced = bool(kurs)
        verdi = qty * kurs if priced else kost
        positions.append({"sym": sym, "qty": qty, "costUsd": round(kost, 2), "valueUsd": round(verdi, 2), "priced": priced})
        sum_kost += kost
        sum_verdi += verdi
        sum_spy += spy_andeler * spy_naa
    sold = []
    for s in solgt:
        sold.append({"sym": s["sym"], "qty": s["qty"], "costUsd": round(s["kost"], 2), "proceedsUsd": round(s["fikk"], 2)})
        sum_kost += s["kost"]
        sum_verdi += s["fikk"]
        sum_spy += s["spy"]
    return positions, sold, {"costUsd": round(sum_kost, 2), "valueUsd": round(sum_verdi, 2), "spyUsd": round(sum_spy, 2)}, ordrer


def drift(logg, ordrer, naa):
    h = {"lastRunStatus": "ukjent", "lastRunMessage": "", "hoursSinceRun": None,
         "signalsAgeHours": None, "signalRows": None, "hoursSinceOrder": None}
    try:
        with open(os.path.join(HER, "logs", ".siste_kjoring.log"), encoding="utf-8") as f:
            tekst = f.read()
        m = re.findall(r"^VARSEL: (.*)$", tekst, re.M)
        msg = m[-1] if m else ""
        h["lastRunMessage"] = msg
        if "IB Gateway er ikke innlogget" in msg: h["lastRunStatus"] = "ikke_innlogget"
        elif "IBKR svarte ikke" in msg: h["lastRunStatus"] = "ibkr_stille"
        elif "Signalene kunne ikke hentes" in msg: h["lastRunStatus"] = "signaler"
        elif "Roboten feilet" in msg: h["lastRunStatus"] = "feil"
        elif "Kjøpt:" in msg or "Solgt:" in msg: h["lastRunStatus"] = "handlet"
        elif "Ingen handler" in msg: h["lastRunStatus"] = "ingen_handler"
        t = re.findall(r"^===== (\d{4}-\d\d-\d\d \d\d:\d\d) =====", tekst, re.M)
        if t:
            h["hoursSinceRun"] = (naa - datetime.strptime(t[-1], "%Y-%m-%d %H:%M")).total_seconds() / 3600
    except Exception:
        pass
    sig = les("signals.json", {}) or {}
    try:
        h["signalsAgeHours"] = (naa - datetime.strptime(sig["generated"], "%Y-%m-%d %H:%M")).total_seconds() / 3600
    except Exception:
        pass
    if isinstance(sig.get("rows"), list):
        h["signalRows"] = len(sig["rows"])
    if ordrer:
        try:
            siste = max(datetime.strptime(o["time"][:19], "%Y-%m-%dT%H:%M:%S") for o in ordrer)
            h["hoursSinceOrder"] = (naa - siste).total_seconds() / 3600
        except Exception:
            pass
    return h


def usd_nok(logg):
    for o in reversed(logg.get("orders", [])):
        if o.get("action") == "FX" and o.get("rate"):
            return float(o["rate"])
    return None


def bygg(naa=None):
    naa = naa or datetime.now()
    logg = les("ibkr_log.json", {}) or {}
    priser = {}
    if PRISFIL:
        with open(PRISFIL, encoding="utf-8") as f:
            priser.update(json.load(f))
    positions, sold, totals, ordrer = regn(logg, spy_historikk(), priser)
    if totals["costUsd"] <= 0:
        raise SystemExit("Ingen handler å regne på")
    payload = {"asOf": naa.strftime("%Y-%m-%dT%H:%M:%S"), "totals": totals,
               "positions": positions, "sold": sold, "health": drift(logg, ordrer, naa)}
    k = usd_nok(logg)
    if k:
        payload["usdNok"] = k
    return payload


def send(payload):
    body = json.dumps({"type": "trading", "payload": payload}).encode("utf-8")
    hdr = {"content-type": "application/json"}
    if os.environ.get("ATLAS_POST_KEY"):
        hdr["x-atlas-key"] = os.environ["ATLAS_POST_KEY"]
    req = urllib.request.Request(URL, data=body, headers=hdr, method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.status


def main():
    payload = bygg()
    if "--dry" in sys.argv:
        print(json.dumps(payload, ensure_ascii=False, indent=1))
        return 0
    uten_kurs = [x for x in payload["positions"] if not x["priced"]]
    if payload["positions"] and len(uten_kurs) * 2 > len(payload["positions"]):
        print(f"! Mangler kurs for {len(uten_kurs)} av {len(payload['positions'])} posisjoner – sender ikke (ville gitt misvisende tall)")
        return 3
    status = send(payload)
    print(f"ATLAS trading sendt (HTTP {status}): kost ${payload['totals']['costUsd']:,.0f}, verdi ${payload['totals']['valueUsd']:,.0f}")
    return 0 if status == 202 else 1


if __name__ == "__main__":
    sys.exit(main())
PY_EOF
echo "tools/trading/atlas_feed.py skrevet"

python3 - <<'PY'
import pathlib
def patch(path, pairs, marker):
    p = pathlib.Path(path); s = p.read_text()
    if marker in s:
        print(path + ': allerede oppdatert'); return
    for old, new in pairs:
        assert s.count(old) == 1, path + ' fant ikke: ' + old[:60]
        s = s.replace(old, new)
    p.write_text(s); print(path + ': oppdatert')

patch('src/agents/coordinator.js', [
  ('const { assessOkonomi, checkOkonomi } = require("./handlers/okonomiAgent");', 'const { assessOkonomi, checkOkonomi } = require("./handlers/okonomiAgent");\nconst { assessTrading, checkTrading } = require("./handlers/tradingAgent");'),
  ('  okonomi: (payload) => assessOkonomi(payload),\n', '  okonomi: (payload) => assessOkonomi(payload),\n  trading: (payload) => assessTrading(payload),\n'),
  ('  } else if (type === "okonomi") {', '  } else if (type === "trading") {\n    problems.push(...checkTrading(result));\n  } else if (type === "okonomi") {'),
], 'assessTrading')

patch('src/agents/briefing.js', [
  ('  const okonomi = latest.okonomi && latest.okonomi.result ? latest.okonomi.result : null;\n', '  const okonomi = latest.okonomi && latest.okonomi.result ? latest.okonomi.result : null;\n  const trading = latest.trading && latest.trading.result ? latest.trading.result : null;\n'),
  ('    makeAnnonser: null,', '    trading: trading ? { roboPct: trading.roboPct, spyPct: trading.spyPct, diffUsd: trading.diffUsd, diffNok: trading.diffNok, totals: trading.totals, positions: trading.positions.length, flags: trading.flags, sistOppdatert: latest.trading.finishedAt } : null,\n    makeAnnonser: null,'),
  ('"sosial", "okonomi"].filter', '"sosial", "okonomi", "trading"].filter'),
  ('  if (okonomi) {\n    for (const f of okonomi.flags.filter((x) => x.typ === "moms"))', '  if (trading) {\n    for (const f of trading.flags.filter((x) => x.typ === "drift")) todo.push({ typ: "trading", tekst: f.tekst });\n  }\n  if (okonomi) {\n    for (const f of okonomi.flags.filter((x) => x.typ === "moms"))'),
  ('  lines.push("💰 Økonomi (hittil i år)");', '''  lines.push("📈 Trading (papirkonto)");
  if (!s.trading) lines.push("  Ingen data ennå.");
  else {
    const t = s.trading;
    lines.push(`  Roboten ${t.roboPct} % mot S&P 500 ${t.spyPct} % (${t.diffUsd >= 0 ? "+" : ""}${t.diffUsd} USD, ca. ${t.diffNok} kr), ${t.positions} posisjoner`);
    for (const f of t.flags) lines.push(`  ⚠️ ${f.tekst}`);
  }
  lines.push("");

  lines.push("💰 Økonomi (hittil i år)");'''),
], 'trading')

patch('public/dashboard/jarvis.html', [
  ('okonomi: "Økonomi"};', 'okonomi: "Økonomi", trading: "Trading"};'),
  ('  if(t.type === "okonomi" && t.result && t.result.sources && t.status !== "failed"){', '''  if(t.type === "trading" && t.result && t.result.totals && t.status !== "failed"){
    return "Robot " + t.result.roboPct + " % · SPY " + t.result.spyPct + " %";
  }
  if(t.type === "okonomi" && t.result && t.result.sources && t.status !== "failed"){'''),
  ('    if(a.type === "okonomi"){', '    if(a.type === "trading"){ el.style.cursor = "pointer"; el.title = "Vis trading"; el.addEventListener("click", openTrading); }\n    if(a.type === "okonomi"){'),
  ('// Økonomi: inntekt hittil i år per kilde og momsgrensen.', '''// Trading: aksjeroboten (papirkonto) mot S&P 500, posisjoner og driftsstatus.
function openTrading(){
  const box = document.getElementById("rp"), body = document.getElementById("rpbody");
  document.querySelector("#rp h2").textContent = "Trading (papirkonto)";
  box.hidden = false;
  const t = LAST_TASKS.find(x => x.type === "trading" && x.result && x.result.totals);
  if(!t){ body.textContent = "Ingen data ennå. Feederen kjører etter roboten kl. 16:00 på hverdager."; return; }
  const r = t.result, usd = n => "$" + Number(n).toLocaleString("no-NO"), pct = n => (n > 0 ? "+" : "") + n + " %";
  const cls = n => n < 0 ? "st-error" : "st-ok";
  const pos = r.positions.map(x => `<tr><td>${esc(x.sym)}</td><td>${x.qty}</td><td>${usd(x.costUsd)}</td><td>${usd(x.valueUsd)}${x.priced ? "" : " *"}</td><td class="${cls(x.pnlPct)}">${pct(x.pnlPct)}</td></tr>`).join("");
  const sold = r.sold.map(x => `<tr><td>${esc(x.sym)}</td><td>${x.qty}</td><td>${usd(x.costUsd)}</td><td>${usd(x.proceedsUsd)}</td><td class="${cls(x.pnlPct)}">${pct(x.pnlPct)}</td></tr>`).join("");
  const flags = r.flags.map(f => `<p class="st-warn">⚠ ${esc(f.tekst)}</p>`).join("");
  const h = r.health;
  body.innerHTML = `<p>Robot <b class="${cls(r.roboPct)}">${pct(r.roboPct)}</b> · S&amp;P 500 ${pct(r.spyPct)} · forskjell <b class="${cls(r.diffUsd)}">${r.diffUsd >= 0 ? "+" : ""}${usd(r.diffUsd)}</b> (ca. ${r.diffNok.toLocaleString("no-NO")} kr)</p>
  <p>Satt inn ${usd(r.totals.costUsd)} · verdt nå ${usd(r.totals.valueUsd)} · samme beløp i SPY ${usd(r.totals.spyUsd)}</p>
  <h3>Eier nå</h3><table><tr><th>Aksje</th><th>Ant</th><th>Kostet</th><th>Verdt</th><th>Endring</th></tr>${pos || "<tr><td colspan=5>Ingen</td></tr>"}</table>
  <h3>Solgt</h3><table><tr><th>Aksje</th><th>Ant</th><th>Kostet</th><th>Fikk</th><th>Endring</th></tr>${sold || "<tr><td colspan=5>Ingen</td></tr>"}</table>
  <p>Siste kjøring: ${esc(h.lastRunMessage || h.lastRunStatus)} · signaler ${h.signalRows === null ? "?" : h.signalRows} rader, ${h.signalsAgeHours === null ? "?" : Math.round(h.signalsAgeHours)} t gamle</p>${flags}
  <p style="opacity:.7">Papirkonto. Tallene er målt mot S&amp;P 500 og er verken råd eller bevis for strategien. * = kurs mangler, verdsatt til kjøpspris.</p>`;
}

// Økonomi: inntekt hittil i år per kilde og momsgrensen.'''),
], 'openTrading')
PY

# Feederen kopieres til aksjeroboten og kobles på daily_run.sh (en gang)
if [ -d "$HOME/aksjesignaler" ]; then
  cp tools/trading/atlas_feed.py "$HOME/aksjesignaler/atlas_feed.py"
  if [ -f "$HOME/aksjesignaler/daily_run.sh" ] && ! grep -q "atlas_feed.py" "$HOME/aksjesignaler/daily_run.sh"; then
    printf '\n# Sender tallene til ATLAS Matrix (agent «trading»)\n./.venv/bin/python "$HOME/aksjesignaler/atlas_feed.py" >> "logs/$(date +%%F).log" 2>&1\n' >> "$HOME/aksjesignaler/daily_run.sh"
    echo "daily_run.sh: feeder lagt til"
  else
    echo "daily_run.sh: feeder var allerede koblet på"
  fi
  echo "atlas_feed.py kopiert til ~/aksjesignaler"
else
  echo "OBS: ~/aksjesignaler finnes ikke her – kopier tools/trading/atlas_feed.py dit selv"
fi

cat > scripts/test_trading.js <<'JS_EOF'
const assert = require("assert");
const { assessTrading, checkTrading } = require("../src/agents/handlers/tradingAgent");
const { buildBriefing } = require("../src/agents/briefing");
const coordinator = require("../src/agents/coordinator");
const base = () => ({
  asOf: "2026-11-26T16:00:00", usdNok: 10,
  totals: { costUsd: 3117, valueUsd: 2969, spyUsd: 2988 },
  positions: [
    { sym: "TM", qty: 2, costUsd: 433, valueUsd: 432, priced: true },
    { sym: "TSM", qty: 1, costUsd: 417, valueUsd: 342, priced: true },
  ],
  sold: [{ sym: "BABA", qty: 1, costUsd: 103, proceedsUsd: 81 }],
  health: { lastRunStatus: "ingen_handler", lastRunMessage: "Ingen handler i dag.", hoursSinceRun: 2, signalsAgeHours: 3, signalRows: 50, hoursSinceOrder: 30 },
});
(async () => {
  const r = assessTrading(base());
  assert.strictEqual(r.roboPct, -4.7);
  assert.strictEqual(r.spyPct, -4.1);
  assert.strictEqual(r.diffUsd, -19);
  assert.strictEqual(r.diffNok, -190);
  assert.strictEqual(r.worst.sym, "TSM");
  assert.strictEqual(r.worst.pnlPct, -18);
  assert.ok(r.flags.some((f) => f.typ === "tap" && f.tekst.includes("TSM")));
  assert.ok(!r.flags.some((f) => f.typ === "drift"));
  assert.deepStrictEqual(checkTrading(r), []);

  const d = base();
  d.health = { lastRunStatus: "ikke_innlogget", signalsAgeHours: 50, signalRows: 4, hoursSinceRun: 100 };
  const rd = assessTrading(d);
  assert.strictEqual(rd.flags.filter((f) => f.typ === "drift").length, 4);

  const u = base(); u.positions[0].priced = false;
  assert.ok(assessTrading(u).flags.some((f) => f.typ === "kurs"));
  assert.throws(() => assessTrading({}));
  assert.throws(() => assessTrading({ totals: { costUsd: 0, valueUsd: 0, spyUsd: 0 } }));
  assert.throws(() => assessTrading({ totals: { costUsd: "x", valueUsd: 1, spyUsd: 1 } }));
  assert.ok(assessTrading({ totals: { costUsd: 100, valueUsd: 110, spyUsd: 105 } }).roboPct === 10);

  assert.ok(coordinator.agentTypes().includes("trading"));
  const t = coordinator.submit("trading", base());
  await new Promise((res) => setTimeout(res, 300));
  assert.strictEqual(coordinator.get(t.id).status, "done");
  const b = buildBriefing({ trading: { result: rd, finishedAt: new Date().toISOString() } });
  assert.ok(b.tekst.includes("Trading (papirkonto)") && b.dagensGjoremal.some((x) => x.typ === "trading"));
  console.log("trading OK"); process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
JS_EOF

# Test av feederen på falske data (ingen nett, ingen sending)
if command -v python3 >/dev/null 2>&1; then
  TMP="$(mktemp -d)"
  cat > "$TMP/ibkr_log.json" <<'LOG_EOF'
{"orders":[
{"action":"FX","symbol":"USD.NOK","rate":9.5,"mode":"paper","time":"2026-11-10T19:00:29","status":"Submitted"},
{"action":"BUY","symbol":"AAA","qty":2,"limit":100,"mode":"paper","time":"2026-11-10T19:00:31","status":"Filled"},
{"action":"BUY","symbol":"BBB","qty":1,"limit":200,"mode":"paper","time":"2026-11-11T13:00:00","status":"Filled"},
{"action":"SELL","symbol":"BBB","qty":1,"limit":150,"mode":"paper","time":"2026-11-16T16:00:00","status":"Filled"}]}
LOG_EOF
  echo '{"2026-11-10": 100, "2026-11-11": 100, "2026-11-16": 90}' > "$TMP/spy_dagskurs.json"
  echo '{"SPY": 95, "AAA": 90}' > "$TMP/priser.json"
  echo '{"generated":"2026-11-26 16:50","rows":[1,2,3]}' > "$TMP/signals.json"
  mkdir -p "$TMP/logs"
  printf '===== 2026-11-26 16:00 =====\nVARSEL: ⚠️ IB Gateway er ikke innlogget – ingen handler i dag.\n' > "$TMP/logs/.siste_kjoring.log"
  ATLAS_TRADING_DIR="$TMP" ATLAS_FEED_PRICES="$TMP/priser.json" python3 tools/trading/atlas_feed.py --dry > "$TMP/ut.json"
  python3 - "$TMP/ut.json" <<'PYT'
import json, sys
p = json.load(open(sys.argv[1]))
t = p["totals"]
# AAA: kostet 200, verdt 180, SPY 200/100*95 = 190. BBB: kostet 200, solgt 150, SPY 200/100*90 = 180.
assert t["costUsd"] == 400 and t["valueUsd"] == 330 and t["spyUsd"] == 370, t
assert p["usdNok"] == 9.5
assert p["health"]["lastRunStatus"] == "ikke_innlogget", p["health"]
assert p["health"]["signalRows"] == 3
assert [x["sym"] for x in p["positions"]] == ["AAA"] and [x["sym"] for x in p["sold"]] == ["BBB"]
print("feeder OK")
PYT
  # Uten kurser på posisjonene skal feederen nekte å sende (kode 3), ikke sende misvisende tall
  echo '{"SPY": 95, "AAA": null}' > "$TMP/priser2.json"
  set +e
  ATLAS_TRADING_DIR="$TMP" ATLAS_FEED_PRICES="$TMP/priser2.json" ATLAS_URL="http://127.0.0.1:9/ingen" python3 tools/trading/atlas_feed.py > "$TMP/ut2.txt" 2>&1
  KODE=$?
  set -e
  [ "$KODE" = "3" ] || { echo "Feil: feederen skulle stoppe med kode 3, fikk $KODE"; cat "$TMP/ut2.txt"; exit 1; }
  echo "feeder-vern OK"
  rm -rf "$TMP"
else
  echo "python3 mangler – hopper over feeder-test"
fi

for t in trading okonomi sosial fronter rapport laas; do node scripts/test_$t.js; done
node -e 'const h=require("fs").readFileSync("public/dashboard/jarvis.html","utf8");new Function(h.match(/<script>([\s\S]*)<\/script>/)[1]);console.log("jarvis.html kompilerer")'
echo "✅ Script 26 ferdig"
