# Value screen backlog

Research only, not investment advice. Opened 2026-11-07 after reviewing the MGY broker tearsheet.

| Priority | Item | Status | Notes |
|---|---|---|---|
| 1 | Pending deal flag (new "Pending deal" risk check, pro forma debt and dilution for buyers) | In progress | Thresholds: under 10% of market value = watch, over 25% = bad. Targets of a pending acquisition are excluded. |
| 2 | Peer-relative valuation | Planned | Compare each stock to its industry median, not the whole market |
| 3 | EV/EBITDA and EBITDA margin with multi-year trend | Planned | Available from Yahoo |
| 4 | Earnings steadiness check | Planned | Guards against a low P/E built on peak commodity earnings |
| 5 | Oil and gas module: net debt to EBITDAX, hedging, breakeven oil price | Planned | Partly manual |
| 6 | Reserve life and reserve replacement | Blocked | No free data source reachable from the GitHub runner |
| 7 | $10 price floor | Decision pending | Would remove TME and SBSW from the Nov. 6 top 10 |
| 8 | Piotroski score | Planned | Not computed in any run so far |

## Pending deal flag: design notes
- Script (`screen/screen.py`): scans Yahoo headlines (up to 270 days back, as many as Yahoo returns) for deal language. Writes `deal_flag` (possible / none_found) and `deal_headlines` to results.json, plus debt, cash, EBITDA, free cash flow and shares outstanding for pro forma math. Risk key `deal` shows ❓ when flagged, ✅ when nothing found.
- Analysis task: confirms terms by news search (buyer or target, value, financing, expected close, approval status), then sets the final rating and pro forma debt and dilution.
- Limit: a deal that is not in headlines can be missed. "None found" is not "none exists."
