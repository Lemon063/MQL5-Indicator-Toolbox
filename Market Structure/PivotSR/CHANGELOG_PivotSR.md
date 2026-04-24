# CHANGELOG_PivotSR.md

## v1.1 — 2026-04
修正三個 bug（code review 發現）：

1. `SelectBestAnchor()` — `same_dist` 容忍度由 `0.000001` 改為 `pip * 5`
   原因：0.000001 喺 forex price 單位下幾乎永遠唔會觸發，S/R tiebreaker 無效

2. `GetAnchorPoints()` — 加入 `anchor.high > anchor.low` 驗證
   原因：橫行市況下可能搵到 High < Low 嘅錨點，令 Fib range 係負數

3. `SupportResistance.mqh` — pip 計算改用 `GetPipSize()`
   原因：`_Point * 10` 對 JPY pair 計算錯誤

## v1.0 — 2026-04
- 初版，取代 SwingHighLow.mqh v1.x
- `IsPivotHigh()` / `IsPivotLow()` — V 字結構轉折點
- `FindPivotHighs()` / `FindPivotLows()` — 候選清單
- `SelectBestAnchor()` — 距離優先，S/R 做 tiebreaker
- `GetAnchorPoints()` — 主函數
- `PivotSR_M5.mq5` / `PivotSR_H1.mq5` — 視覺 check

## v1.1 — 2026-04
- 修正 Bug 3：`SelectBestAnchor()` 加入 `symbol` 參數，`same_dist` 容忍度改為 pip-based（5 pips），確保 S/R tiebreaker 實際生效
- 修正 Bug 4：`GetAnchorPoints()` 加入 `high > low` 驗證，橫行市場唔會輸出錯誤錨點
- Bug 1（Buffer vs shift 對齊）：記錄喺 SPEC，而家係啱，但屬 brittle design，改動時要小心

## v1.2 — 2026-04
- 修正：`PivotSR_M5.mq5` + `PivotSR_H1.mq5` pip 計算改用 `GetPipSize()`，修正 JPY pair 顯示錯誤
- 修正：`SelectBestAnchor()` closer 同 same_dist 改為互斥邏輯
  - 舊版：`closer || (same_dist && stronger)` — 兩個條件可同時 true，邏輯衝突
  - 新版：`(closer && !same_dist)` 或 `(same_dist && stronger)` — 明確互斥

## v1.3 — 2026-04
- `PivotSR_M5.mq5` 預設 `InpPivotN` 由 3 改為 8
- 原因：N=3 對 M5 太細（左右只需 15 分鐘），產生大量假 Pivot
- N=8 = 左右各 40 分鐘確認，更接近真正 V 字結構
- H1 保持 N=3（H1 每 bar = 1 小時，3 bars = 3 小時，結構意義足夠）
