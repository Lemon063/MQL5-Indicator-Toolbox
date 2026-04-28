# CHANGELOG_Fibonacci.md

## v4.1 — 2026-04
H1 畫法更新：改用真實 anchor time + `OBJ_FIBO`

**新增：**
- `Fibonacci_H1.mq5` 改用單一 `OBJ_FIBO` 物件畫 Fibonacci
- `DrawFibObject()` — 用 `anchor.high_bar` / `anchor.low_bar` 對應真實時間畫 Fib
- `OBJPROP_LEVELVALUE / LEVELTEXT / LEVELCOLOR / LEVELSTYLE / LEVELWIDTH`
- Tooltip 顯示 representative score / span / range
- H1 Journal 加入窗口資訊、anchor time、representative score

**修改：**
- H1 Fib 唔再固定畫到 `bar 0`
- `GetAnchorPoints()` 呼叫加入 `InpPrintLog`，可直接輸出 PivotSR debug log
- `DeleteFibObjects()` 會同時清理新 `OBJ_FIBO` 同舊版 trend/text objects
- `CalcFibSRScore()` 呼叫改用 `anchor.range_ok`

**相容性：**
- `InpLineLookback` 暫時保留，避免 breaking change，但 H1 `OBJ_FIBO` 已唔再使用固定左延伸 bars 畫法

## v4.0 — 2026-04
重大重構：`Fibonacci.mq5` 拆分為兩個獨立 file

**新增：**
- `Fibonacci_H1.mq5` — 專用於 H1 chart
  - `InpPivotN = 8`，`InpPivotLook = 336`（14日）
  - 冇鎖定機制，每 bar 重算
  - 冇 M5 相關 inputs
- `Fibonacci_M5.mq5` — 專用於 M5 chart
  - `InpPivotN = 5`，`InpPivotLook = 96`（8小時）
  - 保留鎖定/解鎖機制
  - 冇 H1 相關 inputs

**原因：**
- `Fibonacci.mq5` 單一 file 同時支援 H1/M5，H1/M5 參數預設值唔同，用家容易錯配
- 拆開後每個 file 只有自己 mode 嘅參數，唔需要手動調整

**移除：**
- `Fibonacci.mq5` 中嘅 `ENUM_FIB_MODE` enum 同 `InpFibMode` input

---

## v3.30 — 2026-04
- `Fibonacci.mq5` 將 `InpPivotN` / `InpPivotLook` 拆分為 H1/M5 各自參數：
  - `InpPivotN_M5 = 5`，`InpPivotN_H1 = 8`
  - `InpPivotLook_M5 = 96`，`InpPivotLook_H1 = 336`
- `OnCalculate` 按 mode 動態揀參數
- Shortname 顯示正確 N 值

## v3.20 — 2026-04
- `DrawFibLine` 改用 `OBJ_TREND` 取代 `OBJ_HLINE`
  - 固定起點（往左 `InpLineLookback` bars）同終點（bar 0）
  - `OBJPROP_RAY_RIGHT = false`，唔向右延伸
  - 新增 `InpLineLookback` input（預設 100 bars）
- `DeleteFibObjects` 改為清除 `OBJ_TREND`
- `InpPivotLook` 預設值改為 336（H1 14日）

## v3.10 — 2026-04
- `CalcFibAuto()` 傳入 `is_buy` 至 `GetAnchorPoints()`，確保方向性驗證生效
- H1 + M5 mode 均傳入 `InpIsBuy`
- Shortname 加入 BUY/SELL 顯示
- M5 `✅ 新錨點鎖定` log 加入 `high_bar` / `low_bar`

## v3.1 — 2026-04
- 修正：`PrintFibLog` 移到 `OnCalculate` 之前（MQL5 唔支援 forward declaration）
- 修正：移除 `PrintFibLog` 多餘嘅 `overlap=0, score=0` 傳入
- H1 mode：實際計算 Fib-SR overlap/score 再傳入 `PrintFibLog`
- M5 mode：鎖定狀態重新計算分數，Journal 顯示「🔒 已鎖定 | 重疊:X 分數:Y.Y」

## v2.1 — 2026-04
- 修正：`PREFIX` / `PREFIX_LABEL` 加 `const`
- 修正：pip 計算改用 `GetPipSize()`，修正 JPY pair 顯示錯誤
- 修正：`OnCalculate` 新 bar 判斷改用 `static datetime`
- 修正：`DrawFibLabel` label 位置固定喺最新 bar 左邊 5 格

## v2.0 — 2026-04
- 重大更新：`CalcFibAuto()` 改用 PivotSR 錨點算法
- 唔再依賴 SwingHighLow.mqh，改為依賴 PivotSR.mqh
- `Fibonacci.mq5` 加入 Pivot + S/R 相關 inputs
- 錨點搵唔到時 Journal 印出提示
