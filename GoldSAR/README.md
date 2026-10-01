# GoldSAR - minimal stop-and-reverse scalper for XAUUSD M1 (MT5)

Modelled on the "ASP V8" screen recording: one position at a time, and a trailing
opposite-side stop that is both the stop-loss and the next entry.

## Rules (the whole strategy)
1. Always hold exactly one position (long or short).
2. Stop starts `StopDist` from entry. Once `best price - TrailDist` is at/above breakeven it
   trails `TrailDist` behind the best price. It never moves against the trade.
3. When price touches the stop: close, open the opposite direction at market.
4. Lots = `RiskPercent` of balance / loss if the initial stop is hit, so size scales with balance.
5. Guards: skip opening when spread > `MaxSpread`; halt for the day at `DailyLossPct`;
   broker-side safety SL at 3x `StopDist` in case the terminal disconnects.

Two optimized parameters only: `StopDist`, `TrailDist`.

Differences from the video: the stop is virtual (checked every tick) instead of a pending
order, so it also works on netting accounts. Cost: reversal speed depends on your latency.

## Not yet done
- **Not optimized.** The sandbox this was written in cannot reach any XAUUSD data source, so the
  parameters in the code (1.5 / 0.6) are values read off the video, not fitted values.
- **Not compiled.** No MetaEditor here. Open in MetaEditor, press F7, and report any error.

## Run the optimization (about 15 minutes of setup)
1. Copy `GoldSAR.mq5` to `MQL5/Experts/`, compile (F7).
2. Strategy Tester settings:
   - Expert `GoldSAR`, symbol `XAUUSD` (your broker's name), timeframe `M1`
   - Date: custom, `2025.10.01` to `2026.09.30` (change if you meant calendar 2025)
   - Model: `Every tick` for the search; re-check the best few with `Every tick based on real ticks`
   - Execution: `Random delay` or a fixed 100-200 ms (virtual stops are latency sensitive)
   - Deposit: your real balance and currency, leverage as on your account
   - Optimization: `Fast genetic based algorithm`, criterion `Recovery factor`
   - **Forward: `1/4`** - the last quarter is out-of-sample and is the number to trust
3. Inputs tab: right-click > Load > `GoldSAR_opt.set`.
4. Start. Pick a parameter plateau (neighbours also profitable), not the single best row.

## Reading the result
- Expect roughly 30+ reversals per hour in active sessions. Each reversal costs about one
  spread. On driftless synthetic ticks this design earns ~0 before spread and about -1 spread
  per trade after, so any profit must come from trend persistence in real gold.
- If forward-quarter results are far worse than the in-sample pass, treat it as overfit.
- Run it on a demo account first. Past results do not predict live results.
