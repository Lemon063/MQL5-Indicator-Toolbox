# CHANGELOG_SupportResistance.md

## v1.1 — 2026-04
- 修正：`_Point * 10` 改為 `GetPipSize()`，修正 JPY pair pip 計算問題
- 依賴加入 `ATR.mqh`（GetPipSize）

## v1.0 — 2026-04
- 初版
- `CalcSRZones()` — High + Low 兩點計入密集區
- `RoundToGrid()` — 價格四捨五入到格
- `IsPriceNearSR()` — 最近 S/R zone 配對
- `GetStrongestSR()` — 返回強度最高 zone

## v1.1 — 2026-04
- 修正 Bug 2：pip 計算改用 `ATR.mqh` 嘅 `GetPipSize()`，支援 JPY + 所有品種
- 加入 `#include <Toolbox/ATR.mqh>`
