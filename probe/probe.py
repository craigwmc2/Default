import json, sys, traceback, urllib.request, datetime as dt
out = []
def log(*a): out.append(" ".join(str(x) for x in a)); print(*a)
def fetch(name, url, n=300):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        b = urllib.request.urlopen(req, timeout=30).read().decode("utf-8", "replace")
        log("OK ", name, len(b), b[:n].replace("\n", " | "))
    except Exception as e:
        log("ERR", name, e)
fetch("nasdaqtraded", "https://www.nasdaqtrader.com/dynamic/SymDir/nasdaqtraded.txt", 200)
fetch("nasdaq-ftp-http", "https://www.nasdaqtrader.com/dynamic/SymDir/otherlisted.txt", 200)
fetch("stooq", "https://stooq.com/q/d/l/?s=t.us&i=d", 200)
fetch("stockanalysis-stats", "https://stockanalysis.com/stocks/t/statistics/", 200)
fetch("stockanalysis-list", "https://stockanalysis.com/list/nyse-stocks/", 200)
fetch("sec-tickers", "https://www.sec.gov/files/company_tickers.json", 200)
fetch("nasdaq-api", "https://api.nasdaq.com/api/quote/T/info?assetclass=stocks", 200)
try:
    import yfinance as yf
    log("yfinance", yf.__version__)
    t = yf.Ticker("T")
    h = t.history(period="5d")
    log("history", h[["Close"]].tail(3).to_dict())
    info = t.info
    keys = ["trailingPE","forwardPE","priceToBook","returnOnEquity","returnOnAssets","freeCashflow","marketCap","totalDebt","ebitda","totalCash","shortPercentOfFloat","sharesShort","sharesOutstanding","earningsGrowth","revenueGrowth","recommendationKey","targetMeanPrice","currentPrice","dividendYield","payoutRatio","exchange","earningsTimestamp"]
    log("info", {k: info.get(k) for k in keys})
    bs = t.balance_sheet
    log("balance_sheet rows", list(bs.index)[:40] if bs is not None else None)
    log("financials rows", list(t.financials.index)[:30])
    log("cashflow rows", list(t.cashflow.index)[:30])
    try:
        from yfinance import EquityQuery
        q = EquityQuery("and", [EquityQuery("is-in", ["exchange", "NMS", "NYQ", "ASE"]), EquityQuery("lt", ["intradayprice", 35]), EquityQuery("gt", ["intradaymarketcap", 5e9])])
        r = yf.screen(q, size=250, sortField="intradaymarketcap", sortAsc=False)
        log("screen total", r.get("total"), "returned", len(r.get("quotes", [])), [x["symbol"] for x in r.get("quotes", [])][:15])
    except Exception as e:
        log("screen ERR", repr(e))
except Exception as e:
    log("yfinance ERR", repr(e), traceback.format_exc()[-400:])
open("probe/out.txt", "w").write("\n".join(out) + "\n")
