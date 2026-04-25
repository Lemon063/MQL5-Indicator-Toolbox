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
#include <Toolbox/PivotSR.mqh>
#include <Toolbox/Fibonacci.mqh>
```

**Step 4 — Verify visually**

Attach any `.mq5` to a chart. Values are drawn as lines and printed to the MT5 Journal on every new bar.

---

## Indicators

### Foundation layer

| Indicator | Folder | Files | Description |
|---|---|---|---|
| ATR | [`Momentum/ATR/`](./Momentum/ATR) | `ATR.mqh` | ATR value + derived calculations: SL distance, trailing stop, Fib proximity threshold, pip size. Visual check: use MT5 built-in ATR indicator |
| SupportResistance | [`Market Structure/SupportResistance/`](./Market%20Structure/SupportResistance) | `SupportResistance.mqh` | High/Low price density zones over N bars. Outputs S/R zones with strength scores. Used by PivotSR |
| PivotSR | [`Market Structure/PivotSR/`](./Market%20Structure/PivotSR) | `PivotSR.mqh` `PivotSR_M5.mq5` `PivotSR_H1.mq5` | V-structure pivot detection + S/R validation. Replaces SwingHighLow. Outputs best High/Low anchor for Fibonacci |
| FibTypes | [`Fibonacci/`](./Fibonacci) | `FibTypes.mqh` | `FibLevels` struct definition only. Extracted to avoid circular dependency between PivotSR and Fibonacci |
| Fibonacci | [`Fibonacci/`](./Fibonacci) | `Fibonacci.mqh` `Fibonacci.mq5` | Retracement (0.236–0.786) and extension (1.618–3.618) levels via PivotSR anchors. M5: distance priority + lock/unlock. H1: S/R strength priority |

### Signal layer
*Coming after foundation layer is verified*

| Indicator | Folder | Description |
|---|---|---|
| Stochastic | [`Momentum/Stochastic/`](./Momentum/Stochastic) | K/D cross detection, OB/OS zones, bar latch, CSV log. No external dependencies. Visual check: use MT5 built-in Stochastic |
| Engulf / Pin Bar | [`Candle_Pattern/EngulfPinBar/`](./Candle_Pattern/EngulfPinBar) | Bullish/Bearish Engulfing and Pin Bar detection, bar latch, CSV log. Depends on ATR.mqh (GetPipSize) |
| BOS | `Market Structure/BOS/` | Break of Structure — close beyond swing high/low with momentum confirmation |
| Reversal Candle | `Candle Pattern/ReversalCandle/` | Detects bullish-to-bearish or bearish-to-bullish candle direction flip |
| Body Shrinkage | `Candle Pattern/BodyShrinkage/` | Detects candle body shrinking vs previous bar, momentum exhaustion signal |
| Volume Relative | `Momentum/VolumeRelative/` | Current bar volume vs N-bar average |

### Advanced layer
*Pending signal layer verification*

| Indicator | Folder | Description |
|---|---|---|
| VPIN | `Momentum/VPIN/` | Volume-Synchronized Probability of Informed Trading. BVC method to estimate buy/sell volume imbalance |
| Regime | `Momentum/Regime/` | EMA gap vs ATR for trend/range classification. ADX-based range detection |

---

## Visual check — which chart to use

| Indicator | Attach to | Notes |
|---|---|---|
| ATR | Any chart | Use MT5 built-in ATR indicator instead |
| PivotSR_M5 | M5 chart | Purple-red + blue arrows on pivot highs/lows |
| PivotSR_H1 | H1 chart | White + sky-blue arrows on pivot highs/lows |
| Fibonacci | M5 or H1 chart | 9 horizontal lines + labels, follows chart TF |
| Stochastic | Any chart | Use MT5 built-in Stochastic instead |
| EngulfPinBar | M5 chart | Green/red arrows on chart |

---

## Folder structure

Every indicator follows the same layout:

```
IndicatorName/
├── IndicatorName.mqh          ← EA includes this
├── IndicatorName.mq5          ← attach to chart to verify
├── SPEC_IndicatorName.md      ← definition, parameters, edge cases
├── CHANGELOG_IndicatorName.md ← version history
├── csv/                       ← output data from testing
└── test/                      ← test scripts
```

---

## Dependencies

```
Fibonacci.mqh
└── PivotSR.mqh
    ├── SupportResistance.mqh
    │   └── ATR.mqh  (GetPipSize)
    └── FibTypes.mqh  (FibLevels struct)

EngulfPinBar.mqh
└── ATR.mqh  (GetPipSize)

Stochastic.mqh
└── (none — standalone)

ATR.mqh
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

All `.mqh` files use `#ifndef` include guards — `#pragma once` is not supported in MQL5.

Indicators using MT5 built-in engines (`iATR`, `iStochastic`) require a handle created in `OnInit()` and released in `OnDeinit()`. Never create and release handles inside individual function calls.

All `.mq5` visual indicators use `PERIOD_CURRENT` to follow the chart timeframe. In EA code, always specify the timeframe explicitly (e.g. `PERIOD_M5`) and log it in `OnInit()` to confirm correct configuration.

`GetAnchorPoints()` requires an `is_buy` direction parameter. The function enforces directionality — BUY requires Low bar to be more recent than High bar, SELL requires the opposite. If validation fails, `valid = false` is returned and nothing is drawn.

---

## Status

| Indicator | Status |
|---|---|
| ATR | ✅ v1.4 — `.mqh` verified. Visual check via MT5 built-in |
| SupportResistance | ✅ v1.1 — logic verified |
| PivotSR | ✅ v1.4 — V-structure pivot + direction validation |
| FibTypes | ✅ v1.0 — struct only |
| Fibonacci | ✅ v3.10 — M5 lock/unlock + H1 S/R priority + direction validation |
| Stochastic | ✅ v1.0 — K/D cross + OB/OS. Visual check via MT5 built-in |
| EngulfPinBar | ✅ v1.0 — Engulfing + Pin Bar detection. Visual check passed |
| BOS | ⏳ Pending |
| ReversalCandle | ⏳ Pending |
| BodyShrinkage | ⏳ Pending |
| VolumeRelative | ⏳ Pending |
| VPIN | ⏳ Pending |
| Regime | ⏳ Pending |
