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

| Indicator | Folder | Files | Description |
|---|---|---|---|
| ATR | [`Momentum/ATR/`](./Momentum/ATR) | `ATR.mqh` | ATR value + derived calculations: SL distance, trailing stop, Fib proximity threshold, pip size. Visual check: use MT5 built-in ATR indicator |
| Swing High / Low | [`Market Structure/SwingHighLow/`](./Market%20Structure/SwingHighLow) | `SwingHighLow.mqh` `SwingHighLow_M5.mq5` `SwingHighLow_H1.mq5` | Highest high and lowest low over N bars. M5 (20 bars) and H1 (30 bars). Anchor for Fibonacci and BOS |
| Fibonacci | [`Fibonacci/`](./Fibonacci) | `Fibonacci.mqh` `Fibonacci.mq5` | Retracement (0.236–0.786) and extension (1.618–3.618) levels based on Swing High/Low. Proximity check and exhaustion signal at 3.618 |

### Signal layer
*Coming after foundation layer is verified*

| Indicator | Folder | Description |
|---|---|---|
| Stochastic | [`Momentum/Stochastic/`](./Momentum/Stochastic) | K/D cross detection, OB/OS zones, bar latch, CSV log. Visual check: use MT5 built-in Stochastic indicator |
| Engulf / Pin Bar | [`Candle Pattern/EngulfPinBar/`](./Candle%20Pattern/EngulfPinBar) | Bullish/Bearish Engulfing and Pin Bar detection, bar latch, CSV log |
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
| SwingHighLow_M5 | M5 chart | Purple-red + blue dashed lines |
| SwingHighLow_H1 | H1 chart | Dark red + dark blue solid lines |
| Fibonacci | M5 or H1 chart | 9 horizontal lines, follows chart TF |
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

All `.mqh` files use `#ifndef` include guards — `#pragma once` is not supported in MQL5.

Indicators using MT5 built-in engines (`iATR`, `iStochastic`) require a handle created in `OnInit()` and released in `OnDeinit()`. Never create and release handles inside individual function calls.

All `.mq5` visual indicators use `PERIOD_CURRENT` to follow the chart timeframe. In EA code, always specify the timeframe explicitly (e.g. `PERIOD_M5`) and log it in `OnInit()` to confirm correct configuration.

---

## Status

| Indicator | Status |
|---|---|
| ATR | ✅ v1.4 — `.mqh` verified. Visual check via MT5 built-in |
| SwingHighLow | ✅ v1.3 — visual check passed |
| Fibonacci | 🔧 v1.1 — visual check in progress |
| Stochastic | ⏳ Pending visual check |
| EngulfPinBar | ⏳ Pending visual check |
| BOS | ⏳ Pending |
| ReversalCandle | ⏳ Pending |
| BodyShrinkage | ⏳ Pending |
| VolumeRelative | ⏳ Pending |
| VPIN | ⏳ Pending |
| Regime | ⏳ Pending |
