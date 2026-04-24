# SPEC_PivotSR.md

版本 Version: 1.0
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
                             int pivot_n = 3, int pivot_look = 50,
                             int sr_lookback = 100, double sr_pips = 10.0,
                             int sr_min = 4, double sr_tol_pips = 10.0,
                             int shift = 1)

// Pivot 判斷
bool IsPivotHigh(string symbol, ENUM_TIMEFRAMES tf, int i, int n)
bool IsPivotLow (string symbol, ENUM_TIMEFRAMES tf, int i, int n)

// 搵所有 Pivot 候選
int FindPivotHighs(string symbol, ENUM_TIMEFRAMES tf,
                   int pivot_n, int lookback, int shift,
                   PivotPoint &results[], double current_price)
int FindPivotLows (...)

// 揀最佳錨點
PivotPoint SelectBestAnchor(PivotPoint &candidates[], int count)
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
Step 4：SelectBestAnchor() 揀最佳錨點

選擇優先順序：
1. 距離現價最近（主要條件）
2. S/R 強度最高（tiebreaker）

注意：冇 S/R 支持嘅 Pivot 仍然有效，S/R 強度只係加分
      因為部分 Pivot 喺 S/R 計算窗口之外
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

- [ ] `pivot_n = 3` — forward test 比較 n=2,3,5
- [ ] `sr_tol_pips = 10.0` — 配對容忍度是否需要動態調整
- [ ] 加權排序 — 距離 vs S/R 強度嘅最優比例

---

## 11. Changelog

見 `CHANGELOG_PivotSR.md`
