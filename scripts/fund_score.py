"""Beregner nøkkeltall fra månedlige sluttkurser og gir grønn/oransje/rød/grå score.

Bruk: python3 scripts/fund_score.py data/<fil>.csv
CSV-format: date,close   (date som YYYY-MM, close som tall)
"""
import csv
import math
import sys

# Terskler er forslag og må avtales før bruk.
MIN_MONTHS = 36        # under dette: grå (for kort historikk)
GREEN_MIN_ANN = 6.0    # % annualisert kursavkastning
GREEN_MAX_DD = -30.0   # % største fall, må være bedre enn dette
GREEN_MAX_VOL = 20.0   # % annualisert volatilitet, må være lavere enn dette


def load(path):
    rows = []
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            rows.append((r["date"], float(r["close"])))
    rows.sort()
    return rows


def analyse(rows):
    closes = [c for _, c in rows]
    months = len(closes) - 1
    years = months / 12
    total = (closes[-1] / closes[0] - 1) * 100
    ann = ((closes[-1] / closes[0]) ** (1 / years) - 1) * 100

    rets = [closes[i] / closes[i - 1] - 1 for i in range(1, len(closes))]
    mean = sum(rets) / len(rets)
    if len(rets) > 1:
        var = sum((r - mean) ** 2 for r in rets) / (len(rets) - 1)
        vol = math.sqrt(var) * math.sqrt(12) * 100
    else:
        vol = 0.0

    peak, peak_d = closes[0], rows[0][0]
    mdd, mdd_peak, mdd_trough = 0.0, peak_d, rows[0][0]
    for d, c in rows:
        if c > peak:
            peak, peak_d = c, d
        dd = (c / peak - 1) * 100
        if dd < mdd:
            mdd, mdd_peak, mdd_trough = dd, peak_d, d

    year_end = {}
    for d, c in rows:
        year_end[d[:4]] = c
    years_list = sorted(year_end)
    cal = []
    for y in years_list:
        base = closes[0] if y == years_list[0] else year_end[str(int(y) - 1)]
        cal.append((y, (year_end[y] / base - 1) * 100))

    return {
        "start": rows[0][0], "end": rows[-1][0], "months": months,
        "years": years, "total": total, "ann": ann, "vol": vol,
        "mdd": mdd, "mdd_peak": mdd_peak, "mdd_trough": mdd_trough,
        "cal": cal, "first_year": years_list[0], "last_year": years_list[-1],
    }


def rating(m):
    if m["months"] < MIN_MONTHS:
        return "GRÅ (for kort historikk)"
    if m["ann"] < 0:
        return "RØD"
    if m["ann"] >= GREEN_MIN_ANN and m["mdd"] > GREEN_MAX_DD and m["vol"] < GREEN_MAX_VOL:
        return "GRØNN"
    return "ORANSJE"


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    m = analyse(load(sys.argv[1]))
    print(f"Periode: {m['start']} til {m['end']} ({m['months']} mnd, {m['years']:.2f} år)")
    print(f"Total kursavkastning: {m['total']:.1f} %")
    print(f"Annualisert kursavkastning: {m['ann']:.2f} %")
    print(f"Annualisert volatilitet: {m['vol']:.1f} %")
    print(f"Største fall: {m['mdd']:.1f} % (topp {m['mdd_peak']}, bunn {m['mdd_trough']})")
    print("Kalenderår (første og siste år er delår):")
    for y, r in m["cal"]:
        print(f"  {y}: {r:.1f} %")
    print(f"SCORE: {rating(m)}")
    print("Merk: kun kursavkastning, uten utbytte. Score er et sorteringsverktøy, ikke et kjøpsråd.")


if __name__ == "__main__":
    main()
