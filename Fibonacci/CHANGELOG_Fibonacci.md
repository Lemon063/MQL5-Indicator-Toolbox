
## v2.0 — 2026-04
- 重大更新：`CalcFibAuto()` 改用 PivotSR 錨點算法
- 唔再依賴 SwingHighLow.mqh，改為依賴 PivotSR.mqh
- `Fibonacci.mq5` 加入 Pivot + S/R 相關 inputs
- 錨點搵唔到時 Journal 印出提示，唔會靜靜地用錯數值
- version 改為 2.00

## v2.1 — 2026-04
- 修正問題 1：`PREFIX` / `PREFIX_LABEL` 加 `const`，防止意外修改影響 `DeleteFibObjects()`
- 修正問題 3：`Fibonacci.mq5` Journal log 嘅 pip 計算改用 `GetPipSize()`，修正 JPY pair 顯示錯誤
- 修正問題 4：`OnCalculate` 新 bar 判斷改用 `static datetime`，避免每個 tick 重複計算 PivotSR
- 修正問題 5：`DrawFibLabel` label 位置固定喺最新 bar 左邊 5 格，唔再隨 scroll 跳動
