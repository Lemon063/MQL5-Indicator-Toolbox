# Fibonacci — CHANGELOG

## v1.1 — 2026-04
- 修正 H1 lookback 預設值：20 → 30（SwingHighLow only）
- Journal Print 改為中英夾雜格式

## v1.0 — 2026-04
- 初版
- `CalcFibLevels()` — 手動傳入 swing 價格計算
- `CalcFibAuto()` — 自動從 chart 取 swing 再計算
- `IsFibNear()` — ATR-based proximity check，返回最近 level label
- `IsWickBeyond3618()` — Exhaustion Condition 3 檢測
- BUY / SELL 雙方向支援
- Retracement: 0.236, 0.382, 0.500, 0.618, 0.786
- Extension: 1.000, 1.618, 2.618, 3.618
- 視覺：9 條 HLINE，顏色按重要性區分
- Journal print：anchors, levels, ATR threshold, proximity alert
