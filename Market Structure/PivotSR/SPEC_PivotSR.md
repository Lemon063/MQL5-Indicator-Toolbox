# SPEC_PivotSR.md

版本 Version: 2.1
最後更新 Last updated: 2026-04
狀態 Status: Active
取代 Replaces: SwingHighLow.mqh v1.x

---

## 1. 用途 Purpose

搵真正嘅 V 字結構轉折點（Pivot），結合 S/R 密集區驗證，輸出最佳 Fibonacci 錨點。

取代舊版 `SwingHighLow.mqh` 嘅原因：
- 舊版只搵 N bars 內最高/最低，唔係真正嘅結構轉折點
- 最高價可能係 spike bar，唔係 V 字頂
- 缺乏市場認可（S/R）驗證

---

## 2. 函數 API

```mql5
// 主函數：搵最佳錨點
AnchorResult GetAnchorPoints(string symbol, ENUM_TIMEFRAMES tf,
                             ENUM_ANCHOR_MODE mode, bool is_buy,
                             int pivot_n = 3, int pivot_look = 50,
                             int sr_lookback = 100, double sr_pips = 10.0,
                             int sr_min = 4, double sr_tol_pips = 10.0,
                             double min_range_pips = 0.0,
                             int shift = 1,
                             bool debug_log = false)

// Pivot 判斷
bool IsPivotHigh(string symbol, ENUM_TIMEFRAMES tf, int i, int n)
bool IsPivotLow (string symbol, ENUM_TIMEFRAMES tf, int i, int n)

// 搵所有 Pivot 候選
int FindPivotHighs(string symbol, ENUM_TIMEFRAMES tf,
                   int pivot_n, int lookback, int shift,
                   PivotPoint &results[], double current_price)
int FindPivotLows (...)

// 生成/排序配對
int BuildWavePairs(...)

// H1 representative swing scoring
double CalcH1PairScore(...)
```

---

## 3. Structs

```mql5
struct PivotPoint {
    double price;    // Pivot 價格
    int    bar;      // Bar index（shift）
    int    sr_count; // S/R 強度（0 = 冇對應）
    double dist;     // 距離現價
    bool   valid;
}

struct AnchorResult {
    double high;      // Pivot High 錨點
    double low;       // Pivot Low 錨點
    int    high_bar;  // Pivot High bar index
    int    low_bar;   // Pivot Low bar index
    int    high_sr;   // Pivot High S/R 強度
    int    low_sr;    // Pivot Low S/R 強度
    double score;     // 最終配對分數
    double range_pips;// 波段幅度（pips）
    int    span_bars; // 波段跨越 bars 數
    bool   range_ok;
    bool   valid;
}
```

---

## 4. Pivot 定義

```
Pivot High：bar[i].high 係左右各 N bars 入面每一條都低過佢
  bar[i].high > bar[i+1].high, bar[i+2].high ... bar[i+N].high（左邊，舊）
  bar[i].high > bar[i-1].high, bar[i-2].high ... bar[i-N].high（右邊，新）

Pivot Low：bar[i].low 係左右各 N bars 入面每一條都高過佢
```

**重要：Pivot 確認係滯後的。** `InpPivotRight = N` 即係最新可確認嘅 Pivot 係 bar[N]，唔係 bar[0]。呢個係正確行為，因為 Fibonacci 用嘅係過去已確認嘅結構點去 predict 未來。

---

## 5. 錨點選擇邏輯

```
Step 1：CalcSRZones() 計算 S/R 密集區
Step 2：FindPivotHighs() / FindPivotLows() 搵所有 Pivot 候選
Step 3：Cross-reference — 每個 Pivot 同 S/R 配對，記錄強度
Step 4：BuildWavePairs() 生成所有合格 high/low 配對
Step 5：按 mode 排序，揀最高 score 配對

H1 mode（`ANCHOR_H1`）：
1. 方向性驗證
   - BUY：`low_bar < high_bar`
   - SELL：`high_bar < low_bar`
2. 波段完整性驗證（`IsWaveIntact()`）
3. Representative swing scoring（主要條件）
   - S/R 強度
   - 波段 range 佔 `pivot_look` 窗口比例
   - High/Low 與窗口極值貼近程度
   - 波段 span bars
   - 過分貼近最新 bars 會有輕微懲罰
4. 同分 tie-breaker：
   - range 較大優先
   - span 較長優先
   - 較舊配對優先

M5 mode（`ANCHOR_M5`）：
1. 限制 high/low 都必須喺最近 96 bars（8 小時）內
2. 冇方向性驗證
3. 冇波段完整性驗證
4. 以距離現價最近為主：`score = -(high.dist + low.dist)`

注意：冇 S/R 支持嘅 Pivot 仍然有效，S/R 強度只係評分一部分
```

---

## 6. 參數 Parameters

| 參數 | 預設 | 說明 |
|---|---|---|
| `pivot_n` | 3 | Pivot 左右確認 bars |
| `pivot_look` | 50 | Pivot 回望 bars |
| `sr_lookback` | 100 | S/R 回望 bars |
| `sr_pips` | 10.0 | S/R 格距 pips |
| `sr_min` | 4 | S/R 最低出現次數 |
| `sr_tol_pips` | 10.0 | Pivot-SR 配對容忍度 pips |
| `min_range_pips` | 0.0 | 最低波段幅度，0 = 唔限制 |
| `debug_log` | false | 輸出 top candidates / chosen pair Journal log |

---

## 7. 視覺輸出（.mq5）

| 元素 | M5 顏色 | H1 顏色 | 說明 |
|---|---|---|---|
| Pivot High 箭咀 ↓ | 紫紅 | 深紅 | 向下箭咀喺 Pivot High 頂部 |
| Pivot Low 箭咀 ↑ | 藍色 | 深藍 | 向上箭咀喺 Pivot Low 底部 |

### Journal Print 格式
```
=== PivotSR M5 | USDJPY | 2026.04.23 02:17 ===
  錨點 Anchors | 高 Pivot High: 159.493 (bar 8, S/R強度:6)  低 Pivot Low: 159.230 (bar 15, S/R強度:4)
  幅度 Range   | 26.3 pips
```

### Debug Journal（可選）
```
PivotSR DBG | lookback=336 window_high=... window_low=... window_range=... highs=... lows=... pairs=...
PivotSR DBG | rank=1 score=... range=... span=... recent=... high=...(bar ... sr=... time) low=...(bar ... sr=... time)
PivotSR DBG | chosen score=... range=... span=... high_time=... low_time=... range_ok=true
```

---

## 8. 依賴 Dependencies

```
PivotSR.mqh
└── SupportResistance.mqh
```

---

## 9. 舊版記錄 Legacy Note

`SwingHighLow.mqh` v1.x（N-bar 最高/最低算法）已棄用。

| 版本 | 算法 | 問題 |
|---|---|---|
| v1.x SwingHighLow | N bars 最高/最低 | 最高價唔一定係 V 字，可能係 spike |
| v1.0 PivotSR | Pivot V字 + S/R 密集區 | 更接近 trader 手動揀點邏輯 |

---

## 10. 待調教 Pending Tuning

- [ ] H1 representative score 權重 — S/R / range / span / recency 比例再 forward test
- [ ] `pivot_n = 3` — forward test 比較 n=2,3,5
- [ ] `sr_tol_pips = 10.0` — 配對容忍度是否需要動態調整
- [ ] `min_range_pips` 是否要按品種 / timeframe 動態設定

---

## 11. Changelog

見 `CHANGELOG_PivotSR.md`

---

## 12. 版本記錄 Version Notes

### v2.1 變更

**H1 representative swing scoring**
```
舊版 H1：score = high.sr_count + low.sr_count
        → 336 bars 只係搜尋範圍，唔會真正偏向最具代表性 swing
        → 同分時容易留低較近期 pair

新版 H1：score = f(S/R 強度, window range ratio, edge proximity, span, recency penalty)
        → 14 日窗口內會更偏向完整、幅度夠、接近窗口極值嘅 swing
```

**Pivot 候選數量**
```
舊版：FindPivotHighs/Lows 最多只收 50 個候選
新版：候選數量覆蓋完整 lookback
```

### v1.1 變更

**Bug 3 — `SelectBestAnchor` tiebreaker 修正**
```
舊版：same_dist 容忍度 = 0.000001（price units）
      → forex 兩個 Pivot 差 0.5 pips 都唔會觸發 tiebreaker
      → S/R 強度做 tiebreaker 幾乎永遠唔生效

新版：same_dist 容忍度 = GetPipSize(symbol) × 5（5 pips）
      → 距離差 <= 5 pips 視為相同，用 S/R 強度決定
```

**Bug 4 — High > Low 驗證**
```
橫行市場可能搵到：
  Pivot High = 159.200（較舊）
  Pivot Low  = 159.350（較新，但距離更近）
  → high < low → range 係負數 → 所有 Fib levels 全錯

修正：加入 anchor.high > anchor.low 驗證
      唔符合 → valid = false + PrintFormat 警告
```

**已知設計限制**

| 項目 | 說明 |
|---|---|
| Pivot 滯後 | 最新可確認 Pivot 係 bar[pivot_n]，唔係 bar[0]。正確行為，唔係 bug |
| Buffer vs shift 對齊 | `PivotSR_M5/H1.mq5` 入面 buffer index 同 shift 因 AsSeries=true 啱啱對齊，屬 brittle design，改動時要小心 |
| S/R 唔係強制條件 | 冇 S/R 支持嘅 Pivot 仍然有效，S/R 強度只係 tiebreaker。原因：部分 Pivot 喺 S/R 計算窗口之外 |

### v1.2 變更

**Fix 1 — PivotSR_M5/H1 pip 計算**
```
舊版：SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10
      → JPY pair 顯示 Range pips 錯誤

新版：GetPipSize(_Symbol)
      → 支援所有品種
```

**Fix 2 — SelectBestAnchor 互斥邏輯**
```
舊版：if(closer || (same_dist && stronger))
      → closer 同 same_dist 可同時 true → 邏輯衝突

新版：if(closer && !same_dist)          → 明顯更近，直接取
      else if(same_dist && stronger)    → 距離相近，S/R 強度決定
      → 兩個條件完全互斥，行為清晰
```
