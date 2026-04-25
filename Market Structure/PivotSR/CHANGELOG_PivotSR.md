# CHANGELOG_PivotSR.md

## v2.1 — 2026-04
代表性錨點更新：H1 改為 14 日窗口 representative swing scoring

**新增：**
- `AnchorResult` 加入 `score` / `range_pips` / `span_bars`
- `Clamp01()` — 正規化分數用 helper
- `GetWindowExtremes()` — 取得整個 `pivot_look` 窗口高低位
- `CalcH1PairScore()` — H1 mode 專用 representative swing 評分
- `GetAnchorPoints(..., debug_log=false)` — 可輸出 top pairs / chosen pair debug log

**修改：**
- `FindPivotHighs()` / `FindPivotLows()` 唔再硬性限制最多 50 個候選，改為覆蓋完整 `lookback`
- `BuildWavePairs()` H1 mode 唔再只按 `high.sr_count + low.sr_count` 排序
- H1 score 依家同時考慮：
  - S/R 強度
  - 波段 range 佔整個窗口比例
  - High/Low 與窗口極值貼近程度
  - 波段 span bars
  - 過分貼近最新 bars 嘅輕微懲罰
- 同分時加入 tie-breaker：
  - range 較大優先
  - span 較長優先
  - 較舊（recent bar 較大）優先

**Debug Journal：**
- `PivotSR DBG | lookback=... highs=... lows=... pairs=...`
- `PivotSR DBG | rank=1...5 ...`
- `PivotSR DBG | chosen score=... range=... span=...`

## v2.0 — 2026-04
重大更新：配對驗證架構，取代獨立揀 High/Low

**新增：**
- `WavePair` struct — 儲存 High/Low 配對 + score + range_ok
- `IsWaveIntact()` — H1 only，驗證波段中間冇出現破壞性價格
- `BuildWavePairs()` — 生成所有合格配對，按 mode 計分並排序

**修改：**
- `GetAnchorPoints()` — 改用配對架構（Step 4 → BuildWavePairs → 揀最高 score 配對）
- H1 mode：方向性驗證 + 波段完整性驗證（IsWaveIntact），S/R 強度最強配對優先
- M5 mode：8小時窗口（bar <= 96），冇方向/波段限制，距離最近配對優先
- `PivotSR_H1.mq5` `InpPivotN` 預設值 3 → 8（減少假 Pivot）
- `PivotSR_M5.mq5` `InpPivotLook` 預設值 50 → 96（覆蓋 8小時）

**移除：**
- `SelectBestAnchor()` — 由 `BuildWavePairs()` 取代

**問題根源（解決）：**
```
舊架構：獨立揀最佳 High + 最佳 Low → 唔保證同一個波段
  High bar:48 S/R:24 + Low bar:9 S/R:24
  方向性通過（9 < 48），但中間可能有更高 High → 唔係完整波段

新架構：先配對再驗證
  H1：IsWaveIntact 確保 bar:9 到 bar:48 之間冇更高 High
  M5：只取 8小時內配對，距離最近優先
```

## v1.4 — 2026-04
- `GetAnchorPoints()` 加入 `is_buy` 參數
- 新增 Step 4b 方向性驗證：
  - BUY：`low_bar < high_bar`（Low 更近期，即先見頂後見底）
  - SELL：`high_bar < low_bar`（High 更近期，即先見底後見頂）
  - 驗證失敗 → 返回 `valid=false` + Journal 印出警告
- `PivotSR_H1.mq5` / `PivotSR_M5.mq5` 加入 `InpIsBuy` input
- `PivotSR_H1.mq5` / `PivotSR_M5.mq5` shortname 加入 BUY/SELL 顯示

## v1.3 — 2026-04
- `PivotSR_M5.mq5` 預設 `InpPivotN` 由 3 改為 8
- 原因：N=3 對 M5 太細，產生大量假 Pivot

## v1.2 — 2026-04
- 修正：pip 計算改用 `GetPipSize()`，修正 JPY pair 顯示錯誤
- 修正：`SelectBestAnchor()` closer 同 same_dist 改為互斥邏輯

## v1.1 — 2026-04
- 修正 Bug 3：`SelectBestAnchor()` `same_dist` 容忍度改為 pip-based（5 pips）
- 修正 Bug 4：`GetAnchorPoints()` 加入 `high > low` 驗證

## v1.0 — 2026-04
- 初版，取代 SwingHighLow.mqh v1.x
- `IsPivotHigh()` / `IsPivotLow()` — V 字結構轉折點
- `FindPivotHighs()` / `FindPivotLows()` — 候選清單
- `SelectBestAnchor()` — 距離優先，S/R 做 tiebreaker
- `GetAnchorPoints()` — 主函數
