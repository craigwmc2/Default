# rerun requested 2026-11-07
"""Craig's value screen. Pulls fresh data from Yahoo Finance at run time (no cached/stale pages),
scores every candidate on the 12-point rubric, rates the numeric risk checks, builds the
combined top 10 / top 5 per exchange, and compares with the previous run.
Output: screen/results.json (latest) and screen/history/<date>.json."""
import datetime as dt, json, math, os, re, sys, time
import yfinance as yf
from yfinance import EquityQuery

HERE = os.path.dirname(__file__)
PRICE_CAP, PENNY_PRICE, PENNY_CAP = 35.0, 5.0, 1e9
CAP_FLOOR, CAP_FLOOR_HIGHPRICE = 5e9, 15e9      # NYSE names priced $30-$35 need about $15B
EXCH = {"NMS": "Nasdaq", "NGM": "Nasdaq", "NCM": "Nasdaq", "NYQ": "NYSE", "ASE": "NYSE American"}
MASTER = 2   # risk setting: 1 cautious, 2 mildly cautious (default), 3 balanced, 4 mildly aggressive, 5 aggressive
LEVELS = {   # indicator: (direction, [(good,bad) for level 1..5])
    "debt":     ("lower",  [(1.5,3),(2,3.5),(3,4.5),(3.5,5.5),(4,7)]),
    "altman":   ("higher", [(3.5,2.5),(3,1.8),(2.5,1.5),(2,1.2),(1.8,0.8)]),
    "dilution": ("lower",  [(0,2),(0,5),(2,8),(5,12),(8,20)]),
    "short":    ("lower",  [(2,5),(3,8),(5,10),(7,14),(10,20)]),
    "divpay":   ("lower",  [(50,80),(60,90),(70,100),(80,110),(90,130)]),
    "eps":      ("higher", [(8,2),(5,0),(3,-3),(0,-6),(-3,-10)]),
    "fcfy":     ("higher", [(7,3),(5,2),(4,1),(3,0),(2,-2)]),
}
OVERRIDES = {}  # e.g. {"debt": 3}
EXCLUDED = json.load(open(os.path.join(HERE, "exclusions.json"))) if os.path.exists(os.path.join(HERE, "exclusions.json")) else {}

DEAL_RE = re.compile(r"\b(acquire[sd]?|acquisition|acquiring|agrees? to (?:buy|sell|be acquired|merge)|merger|merges?|takeover|take-private|buyout|definitive agreement|to be acquired|tender offer|all-stock|all-cash deal)\b", re.I)

def deal_scan(t, days=270):
    """Scan Yahoo headlines from the last `days` days (pending deals can take 3-9 months to close) for deal language. Returns (flag, headlines).
    This is a wide net: Claude confirms terms in the analysis step. Absence = 'none found', not 'none exists'."""
    try:
        try: items = retry(lambda: t.get_news(count=50)) or []
        except TypeError: items = retry(lambda: t.news) or []
    except Exception: return None, []
    cutoff = dt.datetime.utcnow() - dt.timedelta(days=days)
    hits = []
    for it in items:
        c = it.get("content") or it
        title = c.get("title") or ""
        when = c.get("pubDate") or c.get("displayTime") or ""
        try: d = dt.datetime.strptime(when[:10], "%Y-%m-%d")
        except Exception: d = None
        if d and d < cutoff: continue
        if DEAL_RE.search(title): hits.append({"date": when[:10], "title": title[:160]})
    return ("possible" if hits else "none_found"), hits[:5]

def num(x):
    try:
        if x is None: return None
        x = float(x)
        return None if math.isnan(x) or math.isinf(x) else x
    except Exception: return None

def rate(ind, v):
    if v is None: return "❓"
    d, tbl = LEVELS[ind]; good, bad = tbl[OVERRIDES.get(ind, MASTER) - 1]
    if d == "lower": return "✅" if v <= good else ("❌" if v > bad else "⚠️")
    return "✅" if v >= good else ("❌" if v < bad else "⚠️")

def retry(fn, n=3):
    for i in range(n):
        try: return fn()
        except Exception as e:
            err = e; time.sleep(1.5 * (i + 1))
    return None

def row_val(df, names, col=0):
    if df is None or getattr(df, "empty", True): return None
    for n in names:
        if n in df.index:
            try:
                return num(df.loc[n].iloc[col])
            except Exception: pass
    return None

def universe():
    codes = list(EXCH.keys())
    q = EquityQuery("and", [EquityQuery("is-in", ["exchange"] + codes),
                            EquityQuery("lt", ["intradayprice", PRICE_CAP + 0.01]),
                            EquityQuery("gt", ["intradayprice", PENNY_PRICE]),
                            EquityQuery("gt", ["intradaymarketcap", CAP_FLOOR])])
    out, offset = [], 0
    while True:
        r = retry(lambda: yf.screen(q, size=250, offset=offset, sortField="intradaymarketcap", sortAsc=False))
        qs = (r or {}).get("quotes", [])
        out += qs
        if len(qs) < 250: break
        offset += 250
    seen, res = set(), []
    for x in out:
        s = x.get("symbol", "")
        if "-" in s or "^" in s or s in seen or x.get("quoteType") not in (None, "EQUITY"): continue
        seen.add(s); res.append(x)
    return res

def analyze(sym, quote):
    t = yf.Ticker(sym)
    info = retry(lambda: t.info) or {}
    price = num(info.get("currentPrice")) or num(info.get("regularMarketPrice")) or num(quote.get("regularMarketPrice"))
    mcap = num(info.get("marketCap")) or num(quote.get("marketCap"))
    exch = EXCH.get(info.get("exchange") or quote.get("exchange"), None)
    r = {"ticker": sym, "name": info.get("shortName") or quote.get("shortName") or sym, "exchange": exch,
         "price": price, "market_cap": mcap, "sector": info.get("sector"), "industry": info.get("industry"),
         "fetched_at": dt.datetime.utcnow().strftime("%Y-%m-%dT%H:%MZ")}
    if price is None or exch is None: r["skip"] = "no price/exchange"; return r
    if price > PRICE_CAP: r["skip"] = f"price above ${PRICE_CAP:.0f}"; return r
    if price < PENNY_PRICE or (mcap or 0) < PENNY_CAP: r["skip"] = "penny stock"; return r
    floor = CAP_FLOOR_HIGHPRICE if (exch == "NYSE" and price >= 30) else CAP_FLOOR
    if (mcap or 0) < floor: r["skip"] = "market value below floor"; return r
    fin = (info.get("sector") == "Financial Services") and any(k in (info.get("industry") or "") for k in ("Bank", "Insurance", "Credit", "Capital Markets", "Asset Management"))
    fwd, trl, pb = num(info.get("forwardPE")), num(info.get("trailingPE")), num(info.get("priceToBook"))
    fcf, debt, ebitda, cash = num(info.get("freeCashflow")), num(info.get("totalDebt")), num(info.get("ebitda")), num(info.get("totalCash"))
    roe = num(info.get("returnOnEquity")); roe = roe * 100 if roe is not None else None
    fcfy = (fcf / mcap * 100) if (fcf is not None and mcap) else None
    # cheap prefilter so we only deep-pull plausible value names
    cheap = (fwd is not None and 0 < fwd <= 16) or (pb is not None and 0 < pb <= 2) or (fcfy is not None and fcfy >= 5)
    if not cheap: r["skip"] = "not cheap (prefilter)"; return r
    fgrowth = ((trl / fwd - 1) * 100) if (trl and fwd and trl > 0 and fwd > 0) else None
    bs = retry(lambda: t.balance_sheet); fs = retry(lambda: t.financials); cf = retry(lambda: t.cashflow)
    # ROIC proxy
    ebit, tax = row_val(fs, ["EBIT"]), row_val(fs, ["Tax Rate For Calcs"])
    ic = row_val(bs, ["Invested Capital"])
    roic = (ebit * (1 - (tax if tax is not None and 0 <= tax < 1 else 0.21)) / ic * 100) if (ebit is not None and ic) else None
    # dilution: latest annual share count vs prior annual
    s0, s1 = row_val(bs, ["Ordinary Shares Number", "Share Issued"], 0), row_val(bs, ["Ordinary Shares Number", "Share Issued"], 1)
    dil = ((s0 / s1 - 1) * 100) if (s0 and s1) else None
    # Altman Z (non-financials)
    z = None
    if not fin:
        ta, tl = row_val(bs, ["Total Assets"]), row_val(bs, ["Total Liabilities Net Minority Interest"])
        ca, cl = row_val(bs, ["Current Assets"]), row_val(bs, ["Current Liabilities"])
        re, sales = row_val(bs, ["Retained Earnings"]), row_val(fs, ["Total Revenue"])
        if ta and tl and ca is not None and cl is not None and re is not None and ebit is not None and sales is not None and mcap:
            z = 1.2*(ca-cl)/ta + 1.4*re/ta + 3.3*ebit/ta + 0.6*mcap/tl + 1.0*sales/ta
    dte = (debt / ebitda) if (debt is not None and ebitda and ebitda > 0) else None
    netcash = (cash is not None and debt is not None and cash >= debt)
    divs = row_val(cf, ["Cash Dividends Paid", "Common Stock Dividend Paid"])
    divpay = (abs(divs) / fcf * 100) if (divs and fcf and fcf > 0) else (0.0 if (divs is None and not info.get("dividendYield")) else None)
    short = num(info.get("shortPercentOfFloat")); short = short * 100 if short is not None else None
    tgt = num(info.get("targetMeanPrice")); up = ((tgt / price - 1) * 100) if tgt else None
    rec = info.get("recommendationKey")
    # ---- 12-point score
    v = (2 if fwd and 0 < fwd <= 10 else 1 if fwd and 0 < fwd <= 14 else 0) + (2 if ((pb and 0 < pb <= 1.5) or (fcfy is not None and fcfy >= 8)) else 0)
    best_ret = max([x for x in (roe, roic) if x is not None], default=None)
    ret = 2 if (best_ret is not None and best_ret >= 12) else 1 if (best_ret is not None and best_ret >= 6) else 0
    if fin: bal, fc = 1, 1
    else:
        bal = 2 if (netcash or (dte is not None and dte <= 2)) else 1 if (dte is not None and dte <= 3.5) else 0
        fc = 2 if (fcfy is not None and fcfy >= 5) else 1 if (fcfy is not None and fcfy > 0) else 0
    gr = 2 if (fgrowth is not None and fgrowth >= 10) else 1 if (fgrowth is not None and fgrowth >= 3) else 0
    score = v + ret + bal + fc + gr
    risks = {"debt": rate("debt", None if fin else (0.0 if netcash and dte is None else dte)), "fcfy": rate("fcfy", fcfy),
             "divpay": rate("divpay", divpay), "eps": rate("eps", fgrowth), "dilution": rate("dilution", dil),
             "short": rate("short", short), "altman": rate("altman", z)}
    analyst = "❓" if (rec is None and tgt is None) else ("❌" if (up is not None and up < 0) else "✅" if (rec in ("buy", "strong_buy") and up is not None and up >= 15) else "⚠️")
    risks["analyst"] = analyst
    nred = sum(1 for k, x in risks.items() if x == "❌"); nwatch = sum(1 for x in risks.values() if x == "⚠️")
    lvl = "High" if nred >= 2 else "Medium" if (nred == 1 or nwatch >= 5) else "Low"
    dflag, dhits = deal_scan(t)
    risks["deal"] = "❓" if dflag == "possible" else ("✅" if dflag == "none_found" else "❓")
    ts = num(info.get("earningsTimestamp") or info.get("earningsTimestampStart"))
    r.update({"financial": fin, "fwd_pe": fwd, "pb": pb, "roe": roe, "roic": roic, "fcf_yield": fcfy, "debt_ebitda": dte,
              "net_cash": netcash, "altman": z, "dilution_pct": dil, "short_pct_float": short, "fcf_payout_pct": divpay,
              "fwd_eps_growth_pct": fgrowth, "analyst_rec": rec, "analyst_upside_pct": up,
              "score": score, "score_parts": {"valuation": v, "returns": ret, "balance": bal, "fcf": fc, "growth": gr},
              "risks": risks, "after_risk": score - nred, "risk_level": lvl,
              "deal_flag": dflag, "deal_headlines": dhits,
              "total_debt": debt, "total_cash": cash, "ebitda": ebitda, "free_cash_flow": fcf,
              "shares_out": num(info.get("sharesOutstanding")),
              "next_earnings": dt.datetime.utcfromtimestamp(ts).strftime("%Y-%m-%d") if ts else None})
    return r

def main():
    today = dt.date.today().isoformat()
    uni = universe()
    print("universe", len(uni), flush=True)
    rows = []
    for i, q in enumerate(uni):
        sym = q["symbol"]
        if sym in EXCLUDED: continue
        try: rows.append(analyze(sym, q))
        except Exception as e: rows.append({"ticker": sym, "skip": f"error {e!r}"})
        if i % 40 == 0: print(i, sym, flush=True)
        time.sleep(0.15)
    scored = [r for r in rows if "score" in r]
    scored.sort(key=lambda r: (-r["after_risk"], -r["score"], -(r["market_cap"] or 0)))
    for n, r in enumerate(scored, 1): r["rank"] = n
    top10 = scored[:10]
    by_ex = {e: [r for r in scored if r["exchange"] == e][:5] for e in ("NYSE", "Nasdaq", "NYSE American")}
    watched = []
    for r in top10 + [x for e in by_ex.values() for x in e]:
        if r["ticker"] not in watched: watched.append(r["ticker"])
    prev_path = os.path.join(HERE, "results.json")
    prev = json.load(open(prev_path)) if os.path.exists(prev_path) else None
    changes = {"entered": [], "exited": [], "compared_with": None}
    if prev:
        changes["compared_with"] = prev.get("run_date")
        pw = set(prev.get("watched", [])); nw = set(watched)
        idx = {r["ticker"]: r for r in rows}
        for t in watched:
            if t not in pw: changes["entered"].append(t)
        for t in prev.get("watched", []):
            if t in nw: continue
            r = idx.get(t)
            if t in EXCLUDED: why = f"excluded: {EXCLUDED[t]}"
            elif r is None:
                info = retry(lambda: yf.Ticker(t).info) or {}
                p, m = num(info.get("currentPrice")), num(info.get("marketCap"))
                why = (f"price ${p:.2f} above the ${PRICE_CAP:.0f} cap" if p and p > PRICE_CAP else
                       f"price ${p:.2f} below the $5 penny-stock line" if p and p < PENNY_PRICE else
                       "market value below the floor" if m and m < CAP_FLOOR else "no longer returned by the screen")
            elif "skip" in r: why = r["skip"] + (f" (price ${r['price']:.2f})" if r.get("price") else "")
            else: why = f"ranked {r['rank']} (score {r['score']}, after risk {r['after_risk']}), crowded out of the top lists"
            changes["exited"].append({"ticker": t, "reason": why})
    out = {"run_date": today, "generated_at": dt.datetime.utcnow().strftime("%Y-%m-%dT%H:%MZ"),
           "source": "Yahoo Finance via yfinance, fetched live during this run",
           "risk_setting": {"master": MASTER, "overrides": OVERRIDES},
           "counts": {"universe": len(uni), "scored": len(scored), "skipped": len(rows) - len(scored),
                      "skip_reasons": {k: sum(1 for r in rows if r.get("skip", "").startswith(k)) for k in
                                       {r.get("skip", "").split(" (")[0] for r in rows if "skip" in r}}},
           "excluded": EXCLUDED, "top10": top10, "by_exchange": by_ex, "watched": watched, "changes": changes,
           "all_scored": scored}
    os.makedirs(os.path.join(HERE, "history"), exist_ok=True)
    for p in (prev_path, os.path.join(HERE, "history", f"{today}.json")):
        json.dump(out, open(p, "w"), indent=1, default=str)
    print("done", out["counts"], "top10", [r["ticker"] for r in top10])

if __name__ == "__main__":
    main()
