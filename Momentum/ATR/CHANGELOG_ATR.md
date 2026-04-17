# ATR — CHANGELOG

## v1.1 — 2026-04
- 修正 H1 lookback 預設值：20 → 30（SwingHighLow only）
- Journal Print 改為中英夾雜格式

## v1.0 — 2026-04
- 初版
- `GetPipSize()` — 多品種統一 pip 計算
- `GetATR()` / `GetATRPips()` — 基礎 ATR 取值
- `GetSL_ATR()` / `GetSL_ATR_Pips()` — ATR-based SL 計算
- `GetMinSL_Pips()` — 最低 SL floor（USDJPY: 6 pips）
- `GetEffectiveSL_Pips()` — max(ATR SL, min floor)
- `GetTrailingStop_ATR()` — Leg B trailing distance
- `GetFibProximityThreshold()` — ATR × 0.20 threshold
- 視覺：sub-window 三條線（ATR, SL 1.5x, SL 2.0x）
- Journal print：ATR, SL, Event SL, Trailing, Fib threshold 全部 pips
