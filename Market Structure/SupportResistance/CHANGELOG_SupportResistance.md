# CHANGELOG_SupportResistance.md

## v1.0 — 2026-04
- 初版
- `CalcSRZones()` — High + Low 兩點計入密集區
- `RoundToGrid()` — 價格四捨五入到格
- `IsPriceNearSR()` — 最近 S/R zone 配對
- `GetStrongestSR()` — 返回強度最高 zone
- 最多 200 個 S/R zones
- 參數：lookback=100, zone_pips=10, min_count=4
