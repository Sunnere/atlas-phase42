#!/usr/bin/env bash
# Oppretter fond-scoring (scripts/fund_score.py + testdata) og legger cat-script-regelen i docs/AI_RULES.md.
# Kjør fra roten av repoet: bash scripts/10_fund_score_setup.sh
set -euo pipefail
mkdir -p scripts data

cat > scripts/fund_score.py << 'PYEOF'
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
PYEOF

cat > data/URTH_monthly.csv << 'CSVEOF'
date,close
2021-11,131.10
2021-12,135.32
2022-01,128.32
2022-02,124.58
2022-03,128.16
2022-04,117.42
2022-05,117.94
2022-06,106.88
2022-07,115.57
2022-08,110.28
2022-09,99.95
2022-10,107.42
2022-11,115.44
2022-12,109.25
2023-01,117.01
2023-02,113.98
2023-03,117.67
2023-04,119.79
2023-05,118.60
2023-06,124.52
2023-07,128.54
2023-08,125.70
2023-09,120.17
2023-10,117.11
2023-11,127.78
2023-12,133.02
2024-01,134.20
2024-02,140.28
2024-03,144.91
2024-04,139.17
2024-05,145.71
2024-06,147.49
2024-07,149.97
2024-08,154.18
2024-09,156.91
2024-10,153.73
2024-11,161.14
2024-12,155.50
2025-01,160.66
2025-02,160.00
2025-03,153.18
2025-04,154.28
2025-05,163.31
2025-06,169.38
2025-07,171.10
2025-08,175.88
2025-09,181.56
2025-10,185.03
2025-11,185.66
2025-12,185.77
2026-01,189.63
2026-02,190.84
2026-03,180.02
2026-04,196.55
2026-05,204.93
2026-06,202.64
2026-07,203.37
2026-08,208.82
2026-09,206.23
2026-10,209.01
CSVEOF

echo "Skrev scripts/fund_score.py og data/URTH_monthly.csv"
python3 scripts/fund_score.py data/URTH_monthly.csv

mkdir -p docs
touch docs/AI_RULES.md
if grep -q "## Kodeendringer som cat-scripts" docs/AI_RULES.md; then
  echo "Seksjonen finnes allerede i docs/AI_RULES.md, ingen endring."
  exit 0
fi
cat >> docs/AI_RULES.md << 'MDEOF'

## Kodeendringer som cat-scripts

- Kodeendringer leveres som bash-scripts (`cat`-scripts) som oppretter eller oppdaterer filer under `scripts/`.
- Ikke lim inn kode direkte i chatten.
- Scripts nummereres fortløpende, for eksempel `scripts/01_fix_...sh`.
- Scripts testes i arbeidsmiljøet før de leveres.
- Kjøres med `bash scripts/<navn>.sh`, ikke ved å lime inn heredocs i zsh.
MDEOF
echo "La til seksjonen 'Kodeendringer som cat-scripts' i docs/AI_RULES.md"
