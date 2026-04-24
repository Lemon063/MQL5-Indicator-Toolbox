# CHANGELOG_PivotSR.md

## v1.0 — 2026-04
- 初版，取代 SwingHighLow.mqh v1.x
- `IsPivotHigh()` / `IsPivotLow()` — 真正 V 字結構轉折點判斷
- `FindPivotHighs()` / `FindPivotLows()` — 搵所有候選清單
- `SelectBestAnchor()` — 距離優先，S/R 強度做 tiebreaker
- `GetAnchorPoints()` — 主函數，結合 Pivot + S/R 輸出最佳錨點
- `PivotSR_M5.mq5` — M5 chart 視覺 check，紫紅/藍箭咀
- `PivotSR_H1.mq5` — H1 chart 視覺 check，深紅/深藍箭咀

## 舊版記錄 Legacy
SwingHighLow.mqh v1.3（N-bar 算法）已棄用
原因：最高價唔一定係 V 字結構點
