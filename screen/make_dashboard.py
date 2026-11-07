"""Builds the JSON datasets the Value Stock Scorecard reads, from screen/results.json.
Usage: python3 screen/make_dashboard.py OUTDIR   (writes metrics, levels, top10, exchange, risks .json)
Judgment ratings (rates, geo, politics) are blank (❓) here; the analysis task may pass a judgments.json to fill them."""
import json, sys, os, re
sys.path.insert(0, os.path.dirname(__file__))
src = os.path.join(os.path.dirname(__file__), "results.json")
d = json.load(open(src))
out = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(out, exist_ok=True)
LEV = {"debt": ("lower", [(1.5,3),(2,3.5),(3,4.5),(3.5,5.5),(4,7)]),
       "altman": ("higher", [(3.5,2.5),(3,1.8),(2.5,1.5),(2,1.2),(1.8,0.8)]),
       "dilution": ("lower", [(0,2),(0,5),(2,8),(5,12),(8,20)]),
       "short": ("lower", [(2,5),(3,8),(5,10),(7,14),(10,20)]),
       "divpay": ("lower", [(50,80),(60,90),(70,100),(80,110),(90,130)]),
       "eps": ("higher", [(8,2),(5,0),(3,-3),(0,-6),(-3,-10)]),
       "fcfy": ("higher", [(7,3),(5,2),(4,1),(3,0),(2,-2)])}
levels = [{"indicator": k, "level": i+1, "direction": dr, "good": g, "bad": b}
          for k, (dr, t) in LEV.items() for i, (g, b) in enumerate(t)]
RAW = {"debt": "debt_ebitda", "altman": "altman", "dilution": "dilution_pct", "short": "short_pct_float",
       "divpay": "fcf_payout_pct", "eps": "fwd_eps_growth_pct", "fcfy": "fcf_yield"}
judg = {}
jp = os.path.join(os.path.dirname(__file__), "judgments.json")
if os.path.exists(jp): judg = json.load(open(jp))
rows = sorted(d["all_scored"], key=lambda r: r["rank"])
keep = {r["ticker"] for r in rows[:25]} | {r["ticker"] for r in d["top10"]} | {"KEY", "VLY"}
for ex in d["by_exchange"].values(): keep |= {r["ticker"] for r in ex}
sel = [r for r in rows if r["ticker"] in keep]
def rnd(x): return None if x is None else round(x, 2)
metrics = []
for r in sel:
    m = {"ticker": r["ticker"], "name": r["name"], "score": r["score"], "rank": r["rank"]}
    for k, f in RAW.items():
        m[k] = rnd(r.get(f)); m["fb_" + k] = r["risks"].get(k, "❓")
    j = judg.get(r["ticker"], {})
    m["analyst"] = r["risks"].get("analyst", "❓")
    for k in ("rates", "geo", "politics"): m[k] = j.get(k, "❓")
    for k in ("deal", "peer", "margin", "steady"): m[k] = r["risks"].get(k, "❓")
    metrics.append(m)
def tr(r):
    return {"rank": r["rank"], "ticker": r["ticker"], "name": r["name"], "exchange": r["exchange"], "price": r["price"],
            "fwd_pe": rnd(r.get("fwd_pe")), "score": r["score"], "after_risk": r["after_risk"], "risk": r["risk_level"],
            "earnings": r.get("next_earnings") or ""}
top10 = [tr(r) for r in d["top10"]]
exch = []
for ex, lst in d["by_exchange"].items():
    for i, r in enumerate(lst[:5]): exch.append({**tr(r), "exch_rank": i+1})
ORDER = ["debt","fcfy","divpay","eps","dilution","short","altman","analyst","rates","geo","politics","deal","peer","margin","steady"]
HEAD = {"debt":"Debt load","fcfy":"Cash generation","divpay":"Dividend safety","eps":"Earnings outlook","dilution":"Share dilution","short":"Short-seller pressure","altman":"Distress signals","analyst":"Analyst view","rates":"Interest rates","geo":"Tariffs, war, geopolitics","politics":"Politics, legal, industry","deal":"Pending deal","peer":"Versus peers","margin":"Profit margin trend","steady":"Earnings steadiness"}
risks = []
for r in d["top10"]:
    mm = next((m for m in metrics if m["ticker"] == r["ticker"]), None)
    for k in ORDER:
        v = mm[k] if k in ("rates","geo","politics") and mm else r["risks"].get(k, "❓")
        risks.append({"ticker": r["ticker"], "check": HEAD[k], "rating": v})
meta = {"run_date": d["run_date"], "generated_at": d["generated_at"], "universe": d.get("counts")}
for n, v in (("metrics", metrics), ("levels", levels), ("top10", top10), ("exchange", exch), ("risks", risks), ("meta", [meta])):
    json.dump(v, open(os.path.join(out, n + ".json"), "w"), ensure_ascii=False)
print("wrote", out, "run", d["run_date"], "stocks in explorer:", len(metrics))
