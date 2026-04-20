# CHANGELOG_ATR.md

## v1.3 — 2026-04
- 修正：`PERIOD_M5` 寫死改為 `PERIOD_CURRENT`
- `ATR.mq5` version 改為 1.20

## v1.4 — 2026-04
- 修正：`array out of range` bug
- loop 改用 `limit = rates_total - InpATRPeriod - 1`
- `shift = i + 1` 確保永遠用已收盤 bar
- `ATR.mq5` version 改為 1.30

## v1.2 — 2026-04
- 修正根本 bug：`GetATR()` 唔再自己建立同釋放 handle
- 新增 `CreateATRHandle()` / `ReleaseATRHandle()`
- `GetATR()` 改為接受 handle 作第一個參數
- 所有衍生 functions 同步更新 signature
- `ATR.mq5`：加入 `g_atrHandle`，`OnInit()` 建立，`OnDeinit()` 釋放

## v1.1 — 2026-04
- 修正：`#pragma once` 改為 MQL5 標準 `#ifndef` include guard

## v1.0 — 2026-04
- 初版
- `GetPipSize()`, `GetATR()`, `GetATRPips()`
- `GetSL_ATR()`, `GetSL_ATR_Pips()`, `GetMinSL_Pips()`, `GetEffectiveSL_Pips()`
- `GetTrailingStop_ATR()`, `GetFibProximityThreshold()`
- 視覺：sub-window 三條線（ATR, SL 1.5x, SL 2.0x）
