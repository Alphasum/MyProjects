# GoldRetest - break-and-retest of higher-timeframe levels, XAUUSD M5 (MT5)

## How traders pick key levels on higher timeframes (research summary)
Most common, roughly in order of how often they come up:
1. **Swing highs/lows** on H1/H4/D1, usually defined as Williams fractals (a bar whose high/low
   beats N bars on each side; N=2 is the default). They are only confirmed N bars later.
2. **Previous day / week high and low** and the daily open: the "obvious" levels many traders watch.
3. **Session ranges**: Asian high/low, London range, often treated as liquidity that gets swept.
4. **Round numbers** (e.g. $50/$100 handles on gold): widely cited, little hard evidence found.
5. **Confluence tools**: Fibonacci retracements, moving averages, trendlines, often used to turn
   a line into a zone.

Break-and-retest practice: confirm the break with a **close** beyond the level (wicks are
often stop-hunts), **enter on the retest, not the break**, place the stop beyond the retested
level, and target the next structure level or at least 1:1-1:2 reward:risk.
Most sources are retail commentary or vendor material, not tested methodology.

This EA uses (1) on H1 plus the previous day high/low from (2).

## Rules
- **Levels**: H1 swing highs/lows over the last ~week (`LevelLookback`), plus yesterday's high/low.
- **Break**: an M5 bar closes above a swing high (long setup) or below a swing low (short setup).
- **Retest**: within the next `RetestBars` (12 = 1 hour) an M5 bar comes back to the level
  (within `RetestTol`) and closes back on the break side with a candle in the trade direction.
  A close more than `RetestTol` back through the level cancels the setup.
- **Entry**: next bar open.
- **Target**: the next swing high above (long) / swing low below (short) that is at least
  `MinRR` x risk away. No such level means no trade.
- **Stop** (`UseStopLoss`, default on): retest bar's low/high (or the level) +/- `StopBuffer`.
  Your spec only says "close at target". Set `UseStopLoss=false` for that, but then the only
  exit on a loser is the broker's margin stop-out.
- **Size**: one 0.1-lot order per $100 of balance (`LotsPerOrder` / `BalancePerOrder`),
  capped by free margin and `MaxOrders`. All orders share the same TP/SL. If any close,
  the EA closes the rest.
- **Quality caps**: at most `MaxTradesPerDay` = 3 signals per server day, one basket at a time,
  spread filter.

## What the money management means (arithmetic, no backtest needed)
0.1 lot of gold = 10 oz, so **each $1 move in gold = $10 = 10% of the $100 that funds it**.
At gold ~ $4,700 that is $47,000 of exposure per $100, i.e. ~470:1.

| Broker leverage | Margin per 0.1 lot | Full size possible? | Adverse move to 50% stop-out |
|---|---|---|---|
| 1:100 | $470 | no (EA opens fewer orders) | - |
| 1:200 | $235 | no (EA opens fewer orders) | - |
| 1:500 | $94 | barely | ~$5.3 |
| 1:1000 | $47 | yes | ~$7.7 |
| 1:2000 | $23.5 | yes | ~$8.8 |

A typical retest stop on M5 gold is $2-5 away, so **one losing trade costs roughly 20-50% of
the account**, and two in a row can end it. Winners are the mirror image. Treat the backtest
as a test of survival, not just profit. Lower `LotsPerOrder` (e.g. 0.01) to see the same
signals at 1/10th the exposure.

## Test on the past month (MT5 Strategy Tester)
1. Copy `GoldRetest.mq5` to `MQL5/Experts/`, open in MetaEditor, compile (F7).
2. Tester: Expert `GoldRetest`, symbol `XAUUSD` (your broker's name), timeframe **M5**,
   dates **2026.09.15 - 2026.10.15**, model **Every tick based on real ticks**,
   deposit/leverage = your real account.
3. Run once with **Visual mode** to check that the levels, retests and targets look sensible;
   the Journal prints every entry with level, stop, target and R multiple.
4. Then run normally and read: number of signals (max 3/day), win rate, average R,
   max drawdown, and whether a margin call happened.

One month is ~20 trading days and at most ~60 signals, likely far fewer. That is enough to
see whether the logic behaves, **not** enough to show an edge.

## Not yet done
- **Not compiled** (no MetaEditor in the build environment) - report any compile error.
- **Not backtested**: the build environment could not reach any gold price data.
