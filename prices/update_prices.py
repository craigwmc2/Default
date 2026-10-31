"""Fetch daily closing prices for Craig's paper portfolio and merge them into prices.csv.

Sources are tried in order per ticker: Yahoo Finance chart API, then Stooq CSV.
Only completed daily closes are written. Existing rows are never changed.
Exits nonzero if any ticker has no data at all, so a failed run is visible in GitHub.
"""
import csv, datetime as dt, json, os, sys, urllib.request

TICKERS = ["IAG","EQX","BTG","T","KEY","VLY","FNB","HBAN","VTRS","MAT","KHC","SFD","SPY","VTV"]
OUT = os.path.join(os.path.dirname(__file__), "prices.csv")
START = dt.date(2026, 10, 14)
UA = {"User-Agent": "Mozilla/5.0 (paper-portfolio price updater)"}

def get(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8", "replace")

def yahoo(t):
    d = json.loads(get(f"https://query1.finance.yahoo.com/v8/finance/chart/{t}?range=1mo&interval=1d"))
    res = d["chart"]["result"][0]
    ts, closes = res["timestamp"], res["indicators"]["quote"][0]["close"]
    off = res["meta"].get("gmtoffset", -14400)
    out = {}
    for s, c in zip(ts, closes):
        if c is not None:
            out[(dt.datetime.utcfromtimestamp(s + off)).date()] = round(float(c), 4)
    return out

def stooq(t):
    rows = list(csv.DictReader(get(f"https://stooq.com/q/d/l/?s={t.lower()}.us&i=d").splitlines()))
    return {dt.date.fromisoformat(r["Date"]): round(float(r["Close"]), 4) for r in rows if r.get("Close")}

def now_et():
    return dt.datetime.utcnow() - dt.timedelta(hours=4)

def main():
    existing = {}
    if os.path.exists(OUT):
        for r in csv.DictReader(open(OUT)):
            existing[(r["date"], r["ticker"])] = r["close"]
    today = now_et().date()
    market_closed = now_et().hour >= 17
    added, failed = 0, []
    for t in TICKERS:
        data, errs = {}, []
        for fn in (yahoo, stooq):
            try:
                data = fn(t)
                if data: break
            except Exception as e:
                errs.append(f"{fn.__name__}: {e}")
        if not data:
            failed.append(f"{t} ({'; '.join(errs)})"); continue
        for d, c in data.items():
            if d < START or d.weekday() > 4: continue
            if d == today and not market_closed: continue  # skip a day still open
            k = (d.isoformat(), t)
            if k not in existing:
                existing[k] = str(c); added += 1
    with open(OUT, "w", newline="") as f:
        w = csv.writer(f); w.writerow(["date","ticker","close"])
        for (d, t), c in sorted(existing.items()):
            w.writerow([d, t, c])
    latest = {}
    for (d, t) in existing: latest[t] = max(latest.get(t, ""), d)
    print(f"added {added} rows; latest per ticker: {latest}")
    if failed:
        print("FAILED:", *failed, sep="\n  "); sys.exit(1)

if __name__ == "__main__":
    main()
