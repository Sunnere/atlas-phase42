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
