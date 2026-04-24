# SPEC_Fibonacci.md

版本 Version: 2.1
最後更新 Last updated: 2026-04
狀態 Status: Active

---

## 1. 用途 Purpose

基於 PivotSR 錨點計算 Fibonacci retracement 同 extension levels。

用途：
- **Scoring #8（v3 spec）** — 價格接近 M5 Fib 支撐/阻力 → 加分 +1
- **H1 Veto** — 價格接近 H1 Fib 阻力/支撐 → 唔入場
- **Exhaustion Condition 3（Pro spec）** — wick 超過 Fib 3.618 → 動能耗盡信號
- **Retracement CSV logging（Pro spec）** — 記錄各 Fib level 到達時間

---

## 2. 依賴 Dependencies

```
Fibonacci.mqh
└── PivotSR.mqh
    └── SupportResistance.mqh
        └── ATR.mqh  (GetPipSize)
```

---

## 3. 函數 API

```mql5
// 手動傳入錨點計算 Fib levels
FibLevels CalcFibLevels(double swing_high, double swing_low, bool is_buy)

// 自動用 PivotSR 搵錨點再計算（主要函數）
FibLevels CalcFibAuto(string symbol, ENUM_TIMEFRAMES tf,
                      bool is_buy,
                      int pivot_n = 3, int pivot_look = 50,
                      int sr_lookback = 100, double sr_pips = 10.0,
                      int sr_min = 4, double sr_tol_pips = 10.0,
                      int shift = 1)

// 檢查價格係咪接近任何 Fib level
bool IsFibNear(double price, const FibLevels &f, double threshold,
               string &nearest_label, double &nearest_price)

// Exhaustion Condition 3：wick 係咪超過 3.618
bool IsWickBeyond3618(double bar_high, double bar_low, const FibLevels &f)
```

---

## 4. FibLevels Struct

```mql5
struct FibLevels {
    double swing_high;   // Pivot High 錨點（1.000）
    double swing_low;    // Pivot Low 錨點（0.000）
    double range;        // swing_high - swing_low

    // Retracement levels
    double fib_236;
    double fib_382;
    double fib_500;
    double fib_618;
    double fib_786;

    // Extension levels
    double fib_1000;     // = swing_high (BUY) 或 swing_low (SELL)
    double fib_1618;
    double fib_2618;
    double fib_3618;

    bool   is_buy;
}
```

---

## 5. 計算邏輯

### BUY 方向
```
range   = swing_high - swing_low

Retracements（由下往上）：
fib_236 = swing_low + 0.236 × range
fib_382 = swing_low + 0.382 × range
fib_500 = swing_low + 0.500 × range
fib_618 = swing_low + 0.618 × range
fib_786 = swing_low + 0.786 × range

Extensions（由上往上）：
fib_1000 = swing_high
fib_1618 = swing_high + 0.618 × range
fib_2618 = swing_high + 1.618 × range
fib_3618 = swing_high + 2.618 × range
```

### SELL 方向
上下對調：retracements 由 swing_high 往下，extensions 由 swing_low 往下。

---

## 6. 錨點來源（v2.0 起）

v2.0 開始，錨點由 `PivotSR.mqh` 嘅 `GetAnchorPoints()` 提供：
- 必須係真正嘅 V 字結構轉折點（Pivot）
- 優先揀距離現價最近嘅 Pivot
- S/R 密集區強度做 tiebreaker
- 確保 `high > low`，否則 `CalcFibAuto()` 返回空 `FibLevels`（range = 0）

舊版（v1.x）用 N-bar 最高/最低，已棄用。見 `PivotSR` SPEC 嘅 Legacy Note。

---

## 7. 參數 Parameters（.mq5 Inputs）

### Pivot 相關
| 參數 | 預設 | 說明 |
|---|---|---|
| `InpPivotN` | 3 | Pivot 左右確認 bars |
| `InpPivotLook` | 50 | Pivot 回望 bars |

### S/R 相關
| 參數 | 預設 | 說明 |
|---|---|---|
| `InpSRLookback` | 100 | S/R 回望 bars |
| `InpSRZonePips` | 10.0 | S/R 格距 pips |
| `InpSRMinCount` | 4 | S/R 最低出現次數 |
| `InpSRTolPips` | 10.0 | Pivot-SR 配對容忍度 pips |

### Fib 相關
| 參數 | 預設 | 說明 |
|---|---|---|
| `InpIsBuy` | true | true = BUY 方向，false = SELL 方向 |
| `InpShowExtensions` | true | 顯示 1.618 / 2.618 / 3.618 |
| `InpAtrMult` | 0.20 | Fib 接近閾值乘數（× ATR）|
| `InpAtrPeriod` | 14 | ATR 週期 |

---

## 8. 視覺輸出（.mq5）

| Level | 顏色 | 樣式 |
|---|---|---|
| 0.000 Swing Low anchor | 淺藍 `clrSkyBlue` | 點線 |
| 0.236 | 金色 | 虛線 |
| 0.382 | 橙色 | 虛線 |
| 0.500 | 深橙 | 實線 |
| 0.618 | 橙紅 | 實線粗 |
| 0.786 | 紅色 | 實線 |
| 1.000 Swing High anchor | 白色 `clrWhite` | 點線 |
| 1.618 | 紫色 | 虛線 |
| 2.618 | 深紫 | 虛線 |
| 3.618 | 暗紫 | 實線粗（Exhaustion）|

每條線右邊有 `OBJ_TEXT` label 顯示 level + 價格，mouse hover 顯示 tooltip。

### Journal Print 格式
```
=== Fibonacci 費波那契 | USDJPY | BUY | 2026.04.23 02:17 ===
  錨點 Anchors    | 波段高 1.000: 159.493  波段低 0.000: 159.230  幅度 Range: 26.3 pips
  回撤 Retrace    | 0.236: 159.292  0.382: 159.330  0.500: 159.362  0.618: 159.393  0.786: 159.437
  延伸 Extensions | 1.618: 159.656  2.618: 159.919  3.618: 160.182（耗盡位 Exhaustion）
  ATR 接近閾值    | ATR: 0.00069  閾值 Threshold: 0.00014 (1.4 pips)
  >>> 價格接近 Fib 0.236 (159.292) — 當前價 Current: 159.300  距離 Dist: 0.8 pips
```

---

## 9. Edge Cases

| 情況 | 處理 |
|---|---|
| 搵唔到有效 Pivot 錨點 | `CalcFibAuto()` 返回 range=0，`Fibonacci.mq5` 印出提示並 return |
| `high <= low`（橫行市況）| `GetAnchorPoints()` 返回 valid=false，同上 |
| ATR = 0 | threshold = 0，`IsFibNear()` 永遠返回 false |
| `InpShowExtensions = false` | 唔畫 1.618–3.618，Journal 唔印延伸位 |

---

## 10. 已知限制及設計決定

| 項目 | 狀態 | 說明 |
|---|---|---|
| `PREFIX` / `PREFIX_LABEL` | ✅ const | 防止意外修改影響 `DeleteFibObjects()` |
| pip 計算 | ✅ `GetPipSize()` | 支援 JPY + 所有品種 |
| 新 bar 判斷 | ✅ `static datetime` | 避免每 tick 重算 PivotSR |
| Label 位置 | ✅ 固定 bar[5] | 唔隨 scroll 跳動 |
| Buffer vs shift（PivotSR）| ⚠️ Brittle | AsSeries=true 令兩者對齊，改動時要小心 |

---

## 11. 待調教 Pending Tuning

- [ ] `InpAtrMult = 0.20` — Pro spec 預設，forward test 後驗證
- [ ] `InpPivotN = 3` — forward test 比較 n=2,3,5
- [ ] `InpSRZonePips = 10.0` — forward test 後驗證最優格距
- [ ] Label 固定位置 bar[5] — 如果 chart zoom 太大可能睇唔到，考慮動態調整

---

## 12. Changelog

見 `CHANGELOG_Fibonacci.md`
