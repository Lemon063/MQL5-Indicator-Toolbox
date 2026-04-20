# CHANGELOG_Fibonacci.md

## v1.1 — 2026-04
- 修正：ATR handle 改為 persistent
  - `g_atrHandle` 喺 `OnInit()` 建立一次
  - `OnDeinit()` 釋放
  - `OnCalculate()` 唔再每次重複建立同釋放
- 修正：`PERIOD_M5` 寫死改為 `PERIOD_CURRENT`（Fib 同 ATR 兩處）
- 原因：寫死 TF 令 MT5 喺非對應 chart 強制 remove indicator

## v1.0 — 2026-04
- 初版
- `CalcFibLevels()` — 手動傳入 swing 價格計算
- `CalcFibAuto()` — 自動從 chart 取 swing 再計算
- `IsFibNear()` — ATR-based proximity check
- `IsWickBeyond3618()` — Exhaustion Condition 3
- BUY / SELL 雙方向
- Retracement: 0.236, 0.382, 0.500, 0.618, 0.786
- Extension: 1.618, 2.618, 3.618
- 視覺：9 條 HLINE
- Journal print：anchors, levels, ATR threshold, proximity alert
