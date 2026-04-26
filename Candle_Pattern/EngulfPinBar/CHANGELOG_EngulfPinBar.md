# CHANGELOG_EngulfPinBar.md

## v1.1 — 2026-04
- 加 `DetectCandlePatternAt(symbol, tf, engulf_shift, prior_shift, min_body_pips)`
- 用途：支援任意 bar shift 嘅 Engulfing 偵測，供 M3Mode1 trigger 用（bar2 vs bar3）
- Pin Bar 唔支援任意 shift（影線定義依賴 bar1 方向），此 function 只偵測 Engulfing
- 原有 `DetectCandlePattern()` 保持不變（backward compatible）
- Header comment 加版本標記 v1.1

## v1.0 — 2026-04
- 初版，由 CandlePattern_Sandbox_1.mq5 sandbox EA 重構
- 邏輯抽出至 `EngulfPinBar.mqh`（純 function，冇 input，冇 print）
- `CandleData` struct：OHLC + body, upperWick, lowerWick, bullish, bearish
- `CandleSignal` struct：bullEngulf, bearEngulf, bullPin, bearPin, detected, direction
- `BuildCandleData()` — 由 OHLC 值計算衍生數據
- `GetCandleData()` — 從 chart 直接取得 CandleData
- `DetectCandlePattern()` — 一次過偵測四種 pattern
- Pip size 改用 `ATR.mqh` 嘅 `GetPipSize()`，唔再用 `_Digits` 判斷
- 支援品種：USDJPY / GBPUSD / EURUSD / AUDUSD（無需改動）
- `.mq5`：chart 畫看漲/看跌箭咀（bar1 High/Low ± 3 pips）
- Journal print：中英夾雜，bar1/bar2 OHLC，形態，結果
- CSV log：欄位同 Sandbox EA 一致，方便對比
- Bar latch：同一根 bar 唔重複接受信號
