# Value screen backlog

Research only, not investment advice. Opened 2026-11-07 after reviewing the MGY broker tearsheet.

| Priority | Item | Status | Notes |
|---|---|---|---|
| 1 | Pending deal flag (new "Pending deal" risk check, pro forma debt and dilution for buyers) | Built 2026-11-07; first live analysis run is Mon Nov 9 | Thresholds: under 10% of market value = watch, over 25% = bad. Targets of a pending acquisition are excluded. |
| 2 | Peer-relative valuation | Done 2026-11-07 | New `peer` risk check in screen.py. Peers are the screened $5-$35, $5B+ names, not the whole industry. EV/EBITDA is skipped for foreign filers (currency mismatch) and forward P/E is used instead. |
| 3 | EV/EBITDA and EBITDA margin with multi-year trend | Done 2026-11-07 | EV/EBITDA is used inside the peer check. New `margin` risk check: latest annual EBITDA margin vs the prior 3-year average (drop under 2 pts good, 2-5 watch, over 5 bad). Banks and insurers show unverified. Measures trend, not level; annual data lags. |
| 4 | Earnings steadiness check | Done 2026-11-07 | New `steady` risk check: normalized P/E = trailing P/E x (latest net income / 4-year average). Good 15 or less, watch 15-25, bad over 25 or average earnings not positive. Peer, margin and steadiness checks cost 1 point per bad mark in after-risk but do not change the risk level, which keeps its original definition. |
| 5 | Oil and gas module: net debt to EBITDAX, hedging, breakeven oil price | Planned | Partly manual |
| 6 | Reserve life and reserve replacement | Blocked | No free data source reachable from the GitHub runner |
| 7 | $10 price floor | Decision pending | Would remove TME and SBSW from the Nov. 6 top 10 |
| 8 | Piotroski score | Planned | Not computed in any run so far |

## Pending deal flag: design notes
- Script (`screen/screen.py`): scans Yahoo headlines (up to 270 days back, as many as Yahoo returns) for deal language. Writes `deal_flag` (possible / none_found) and `deal_headlines` to results.json, plus debt, cash, EBITDA, free cash flow and shares outstanding for pro forma math. Risk key `deal` shows ❓ when flagged, ✅ when nothing found.
- Analysis task: confirms terms by news search (buyer or target, value, financing, expected close, approval status), then sets the final rating and pro forma debt and dilution.
- Limit: a deal that is not in headlines can be missed. "None found" is not "none exists."
