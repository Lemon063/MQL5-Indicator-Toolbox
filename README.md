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
| ATR | [`Momentum/ATR/`](./Momentum/ATR) | ATR value + derived calculations: SL distance, trailing stop distance, Fib proximity threshold, pip size per symbol |
| Swing High / Low | [`Market Structure/SwingHighLow/`](./Market%20Structure/SwingHighLow) | Highest high and lowest low over N bars. Supports M5 and H1. Used as the anchor for Fibonacci and BOS |
| Fibonacci | [`Fibonacci/`](./Fibonacci) | Retracement levels (0.236–0.786) and extension levels (1.618–3.618) based on Swing High/Low. Includes proximity check and exhaustion signal at 3.618 |

### Signal layer
*Coming after foundation layer is verified*

| Indicator | Folder | Description |
|---|---|---|
| Stochastic | [`Momentum/Stochastic/`](./Momentum/Stochastic) | K/D cross detection, OB/OS zones, bar latch, CSV log |
| Engulf / Pin Bar | [`Candle Pattern/EngulfPinBar/`](./Candle%20Pattern/EngulfPinBar) | Bullish/Bearish Engulfing and Pin Bar detection, bar latch, CSV log |
| BOS | `Market Structure/BOS/` | Break of Structure — close beyond swing high/low with momentum confirmation |
| Reversal Candle | `Candle Pattern/ReversalCandle/` | Detects bullish-to-bearish or bearish-to-bullish candle direction flip |
| Body Shrinkage | `Candle Pattern/BodyShrinkage/` | Detects candle body shrinking vs previous bar, used as momentum exhaustion signal |
| Volume Relative | `Momentum/VolumeRelative/` | Current bar volume vs N-bar average |

### Advanced layer
*Pending signal layer verification*

| Indicator | Folder | Description |
|---|---|---|
| VPIN | `Momentum/VPIN/` | Volume-Synchronized Probability of Informed Trading. Uses BVC method to estimate buy/sell volume imbalance |
| Regime | `Momentum/Regime/` | EMA gap vs ATR for trend/range classification. ADX-based range detection |

---

## Folder structure

Every indicator follows the same layout:

```
IndicatorName/
├── IndicatorName.mqh     ← EA includes this
├── IndicatorName.mq5     ← attach to chart to verify
├── SPEC_IndicatorName.md        ← definition, parameters, edge cases
├── CHANGELOG_IndicatorName.md   ← version history
├── csv/                  ← output data from testing
└── test/                 ← test scripts
```

---

## Dependencies

```
Fibonacci
└── SwingHighLow

EngulfPinBar
└── ATR  (GetPipSize)

BOS (coming)
└── SwingHighLow

ATR
└── (none — standalone)

Stochastic
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
| Runtime | macOS + Wine |

---

## Notes for EA integration

All `.mqh` files use `#ifndef` include guards (MQL5 standard). `#pragma once` is not supported in MQL5.

Indicators that use MT5 built-in calculation engines (`iATR`, `iStochastic`) require a handle to be created in `OnInit()` and released in `OnDeinit()`. Do not create and release handles inside individual function calls.

When specifying timeframes in an EA, always use explicit constants (e.g. `PERIOD_M5`) rather than `PERIOD_CURRENT`, and log the TF in `OnInit()` to confirm correct configuration.

---

## Status

| Indicator | Status |
|---|---|
| ATR | 🔧 v1.3 — visual check in progress |
| SwingHighLow | ⏳ Pending visual check |
| Fibonacci | ⏳ Pending visual check |
| Stochastic | ⏳ Pending visual check |
| EngulfPinBar | ⏳ Pending visual check |
| BOS | ⏳ Pending |
| ReversalCandle | ⏳ Pending |
| BodyShrinkage | ⏳ Pending |
| VolumeRelative | ⏳ Pending |
| VPIN | ⏳ Pending |
| Regime | ⏳ Pending |
