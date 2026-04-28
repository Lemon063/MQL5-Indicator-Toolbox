# SPEC_Fibonacci.md

版本 Version: 4.1
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

## 6. 錨點來源（v4.1 更新）

v2.0 開始，錨點由 `PivotSR.mqh` 嘅 `GetAnchorPoints()` 提供。  
v4.1 起，H1 會用 representative swing scoring 喺 `InpPivotLook` 窗口內揀最具代表性 high/low：
- 必須係真正嘅 V 字結構轉折點（Pivot）
- H1：優先揀完整、幅度夠、接近窗口極值、跨 bars 較長嘅 swing
- M5：仍然係 8 小時窗口內距離現價最近配對優先
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
| `InpLineLookback` | 100 | H1 已保留兼容；`OBJ_FIBO` 畫法唔再使用固定左延伸 bars |

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

### H1 畫法（v4.1）
- `Fibonacci_H1.mq5` 使用單一 `OBJ_FIBO`
- 起點/終點直接綁定真實 anchor time：
  - BUY：`low_bar -> high_bar`
  - SELL：`high_bar -> low_bar`
- 唔再固定畫到最新 bar，所以 Fib 唔會再視覺上永遠痴住最尾
- tooltip 顯示 representative `score / span / range`

### 舊畫法
- 舊版 H1 用 `OBJ_TREND` + `OBJ_TEXT`
- v4.1 `DeleteFibObjects()` 仍會清理舊 objects，避免升級後圖上殘留舊線

### Journal Print 格式
```
=== Fibonacci H1 | USDJPY | BUY | 2026.04.23 02:17 ===
  窗口 Window    | lookback: 336 bars (~14.0 days)  pivotN: 8
  錨點 Anchors   | 波段高 1.000: 159.49300 (bar 84 @ 2026.04.20 09:00)  波段低 0.000: 159.23000 (bar 24 @ 2026.04.22 21:00)  幅度: 26.3 pips
  代表性評分 Rep | anchor_score: 38.72  span: 60 bars  range: 26.3 pips  range_ok: true
  回撤 Retrace   | 0.236: 159.29200  0.382: 159.33000  0.500: 159.36200  0.618: 159.39300  0.786: 159.43700
  延伸 Ext       | 1.618: 159.65600  2.618: 159.91900  3.618: 160.18200（耗盡位）
  重疊 Overlap   | 3  Fib-SR 分數 Score: 8.0
  ATR 接近閾值   | ATR: 0.00069  閾值: 0.00014 (1.4 pips)
  >>> 價格接近 Fib 0.236 (159.29200) — 當前價: 159.30000  距離: 0.8 pips
```

### PivotSR Debug（當 `InpPrintLog=true`）
```
PivotSR DBG | lookback=336 ...
PivotSR DBG | rank=1 ...
PivotSR DBG | chosen score=...
```

---

## 9. Edge Cases

| 情況 | 處理 |
|---|---|
| 搵唔到有效 Pivot 錨點 | `CalcFibAuto()` 返回 range=0，`Fibonacci.mq5` 印出提示並 return |
| `high <= low`（橫行市況）| `GetAnchorPoints()` 返回 valid=false，同上 |
| ATR = 0 | threshold = 0，`IsFibNear()` 永遠返回 false |
| `InpShowExtensions = false` | 唔畫 1.618–3.618，Journal 唔印延伸位 |
| `OBJ_FIBO` 建立失敗 | `Fibonacci_H1.mq5` Journal 印出 `OBJ_FIBO 建立/更新失敗` |

---

## 10. 已知限制及設計決定

| 項目 | 狀態 | 說明 |
|---|---|---|
| H1 畫法 | ✅ `OBJ_FIBO` | 真實 anchor time 畫 Fib，唔再固定畫到最新 bar |
| 舊 objects 清理 | ✅ backward compatible | 會刪除舊版 `OBJ_TREND` / `OBJ_TEXT` |
| pip 計算 | ✅ `GetPipSize()` | 支援 JPY + 所有品種 |
| 新 bar 判斷 | ✅ `static datetime` | 避免每 tick 重算 PivotSR |
| `InpLineLookback` | ⚠️ Legacy | H1 保留 input，但 v4.1 已唔影響 `OBJ_FIBO` 畫法 |
| Buffer vs shift（PivotSR）| ⚠️ Brittle | AsSeries=true 令兩者對齊，改動時要小心 |

---

## 11. 待調教 Pending Tuning

- [ ] `InpAtrMult = 0.20` — Pro spec 預設，forward test 後驗證
- [ ] H1 representative swing 權重 — 配合不同品種檢查會唔會過分偏向大 swing
- [ ] `InpPivotN = 8`（H1）— forward test 比較 n=5,8,10
- [ ] `InpSRZonePips = 10.0` — forward test 後驗證最優格距

---

## 12. Changelog

見 `CHANGELOG_Fibonacci.md`
