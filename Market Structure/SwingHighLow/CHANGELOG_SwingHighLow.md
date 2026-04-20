# CHANGELOG_SwingHighLow.md

## v1.2 — 2026-04
- `SwingHighLow.mq5` 拆分為兩個獨立 indicator：
  - `SwingHighLow_M5.mq5` — attach M5 chart，只畫 M5 swing，預設 20 bars
  - `SwingHighLow_H1.mq5` — attach H1 chart，只畫 H1 swing，預設 30 bars
- 原因：M5 swing 畫喺 H1 chart 冇意義，分開 check 更清晰
- `SwingHighLow.mq5`（原版）保留作參考，唔再主動使用

## v1.3 — 2026-04
- 修正：`array out of range` bug
- loop 改用 `limit = rates_total - InpSwingBars - 1`，唔再越出 buffer 範圍
- `shift = i + 1` 確保永遠用已收盤 bar
- 移除多餘嘅 `ArraySetAsSeries(time, true)`
- 兩個 file 版本號改為 1.10

## v1.1 — 2026-04
- 修正 H1 lookback 預設值：20 → 30
- Journal Print 改為中英夾雜格式

## v1.0 — 2026-04
- 初版
- `GetSwingHigh()`, `GetSwingLow()`, `GetSwingHighShift()`, `GetSwingLowShift()`, `GetSwing()`
- M5 + H1 雙時間框架視覺輸出
- Journal print：價格、bar index、range pips
- 預設 N-bar = 20
