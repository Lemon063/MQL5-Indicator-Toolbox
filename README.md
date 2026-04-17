# MQL5 Indicator Toolbox

A collection of reusable MQL5 indicators for MetaTrader 5, built for algorithmic trading development.

Each indicator is independently testable — attach the `.mq5` to any chart to visually verify its output before integrating into an EA.

---

## What this is

A modular indicator library where every component lives in its own folder with a specification, changelog, and test data. The goal is to verify each indicator in isolation before using it in a full trading system.

This is not a trading strategy and does not contain any EA logic.

---

## How it works

Each indicator comes in two files:

| File | Purpose |
|---|---|
| `IndicatorName.mqh` | Pure logic library. Include this in your EA with `#include <Toolbox/IndicatorName.mqh>` |
| `IndicatorName.mq5` | Visual indicator. Attach to a chart to see values drawn and printed to the Journal |

The `.mq5` and `.mqh` share the same logic — there is no duplication.

---

## Installation

**Step 1 — Copy `.mqh` files**
```
repo/IndicatorName/IndicatorName.mqh
  → MQL5/Include/Toolbox/IndicatorName.mqh
```

**Step 2 — Copy `.mq5` files**
```
repo/IndicatorName/IndicatorName.mq5
  → MQL5/Indicators/Toolbox/IndicatorName.mq5
```

**Step 3 — Use in your EA**
```mql5
#include <Toolbox/ATR.mqh>
#include <Toolbox/SwingHighLow.mqh>
#include <Toolbox/Fibonacci.mqh>
```

**Step 4 — Verify visually**

Attach any `.mq5` to a chart. Values are drawn as lines and printed to the MT5 Journal on every new bar.

---

## Indicators

### Foundation layer

| Indicator | Folder | Description |
|---|---|---|
| ATR | [`ATR/`](./ATR) | ATR value + derived calculations: SL distance, trailing stop distance, Fib proximity threshold, pip size per symbol |
| Swing High / Low | [`SwingHighLow/`](./SwingHighLow) | Highest high and lowest low over N bars. Supports M5 and H1. Used as the anchor for Fibonacci and BOS |
| Fibonacci | [`Fibonacci/`](./Fibonacci) | Retracement levels (0.236–0.786) and extension levels (1.618–3.618) based on Swing High/Low. Includes proximity check and exhaustion signal at 3.618 |

### Signal layer
*Coming after foundation layer is verified*

| Indicator | Folder | Description |
|---|---|---|
| BOS | `BOS/` | Break of Structure — close beyond swing high/low with momentum confirmation |
| Reversal Candle | `ReversalCandle/` | Detects bullish-to-bearish or bearish-to-bullish candle direction flip |
| Body Shrinkage | `BodyShrinkage/` | Detects candle body shrinking vs previous bar, used as momentum exhaustion signal |
| Volume Relative | `VolumeRelative/` | Current bar volume vs N-bar average |

### Advanced layer
*Pending signal layer verification*

| Indicator | Folder | Description |
|---|---|---|
| VPIN | `VPIN/` | Volume-Synchronized Probability of Informed Trading. Uses BVC method to estimate buy/sell volume imbalance |
| Regime | `Regime/` | EMA gap vs ATR for trend/range classification. ADX-based range detection |

---

## Folder structure

Every indicator follows the same layout:

```
IndicatorName/
├── IndicatorName.mqh     ← EA includes this
├── IndicatorName.mq5     ← attach to chart to verify
├── SPEC.md               ← definition, parameters, edge cases
├── CHANGELOG.md          ← version history
├── csv/                  ← output data from testing
└── test/                 ← test scripts
```

---

## Dependencies

```
Fibonacci
└── SwingHighLow

BOS (coming)
└── SwingHighLow

ATR
└── (none — standalone)
```

---

## Platform

| Item | Requirement |
|---|---|
| Platform | MetaTrader 5 (MT5) |
| Language | MQL5 |
| Account type | Hedging |
| Tested symbols | USDJPY, GBPUSD, EURUSD, AUDUSD |
| Chart timeframe | M5 (primary), H1 (veto / regime) |

---

## Status

| Indicator | Status |
|---|---|
| ATR | ✅ v1.1 |
| SwingHighLow | ✅ v1.1 |
| Fibonacci | ✅ v1.1 |
| BOS | ⏳ Pending |
| ReversalCandle | ⏳ Pending |
| BodyShrinkage | ⏳ Pending |
| VolumeRelative | ⏳ Pending |
| VPIN | ⏳ Pending |
| Regime | ⏳ Pending |
