# Fibonacci — SPEC.md

版本 Version: 1.0
最後更新 Last updated: 2026-04
狀態 Status: Active

---

## 1. 用途 Purpose

基於 SwingHighLow 計算 Fib retracement 同 extension levels。

用途：
- **Scoring #8（v3 spec）** — 價格接近 M5 Fib 支撐/阻力 → 加分 +1
- **H1 Veto** — 價格接近 H1 Fib 阻力/支撐 → 唔入場
- **Exhaustion Condition 3（Pro spec）** — wick 超過 Fib 3.618 → 動能耗盡信號
- **Retracement CSV logging（Pro spec）** — 記錄各 Fib level 到達時間

---

## 2. 依賴 Dependencies

```
Fibonacci.mqh
└── SwingHighLow.mqh   (GetSwing, SwingResult)
```

---

## 3. 函數 API

```mql5
// 手動傳入 swing 價格
FibLevels CalcFibLevels(double swing_high, double swing_low, bool is_buy)

// 自動從 chart 計算 swing 再計 Fib（推薦）
FibLevels CalcFibAuto(string symbol, ENUM_TIMEFRAMES tf,
                      int n_bars, bool is_buy, int shift = 1)

// 檢查價格是否接近任何 Fib level
bool IsFibNear(double price, const FibLevels &f, double threshold,
               string &nearest_label, double &nearest_price)

// Exhaustion Condition 3：wick 是否超過 3.618
bool IsWickBeyond3618(double bar_high, double bar_low, const FibLevels &f)
```

---

## 4. FibLevels Struct

```mql5
struct FibLevels {
    double swing_high;   // Swing High 錨點
    double swing_low;    // Swing Low 錨點
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

    bool   is_buy;       // true = BUY 方向
}
```

---

## 5. 計算邏輯

### BUY 方向
```
range   = SwingHigh - SwingLow

Retracements（由下往上）：
fib_236 = SwingLow + 0.236 × range
fib_382 = SwingLow + 0.382 × range
fib_500 = SwingLow + 0.500 × range
fib_618 = SwingLow + 0.618 × range
fib_786 = SwingLow + 0.786 × range

Extensions（由上往上）：
fib_1000 = SwingHigh
fib_1618 = SwingHigh + 0.618 × range
fib_2618 = SwingHigh + 1.618 × range
fib_3618 = SwingHigh + 2.618 × range
```

### SELL 方向
上下對調：retracements 由 SwingHigh 往下，extensions 由 SwingLow 往下。

---

## 6. Proximity Check 邏輯

```
threshold = ATR × InpAtrMult (預設 0.20)
near      = abs(price - fib_level) < threshold
```

`IsFibNear()` 返回最近嘅 level label 同價格，方便 caller log 或決策。

---

## 7. 視覺輸出（.mq5）

| Level | 顏色 | 樣式 |
|---|---|---|
| 0.236 | 金色 | 虛線 |
| 0.382 | 橙色 | 虛線 |
| 0.500 | 深橙 | 實線 |
| 0.618 | 橙紅 | 實線粗 |
| 0.786 | 紅色 | 實線 |
| Swing High/Low | 深紅/深藍 | 點線 |
| 1.618 | 紫色 | 虛線 |
| 2.618 | 深紫 | 虛線 |
| 3.618 | 暗紫 | 實線粗（Exhaustion 標記）|

### Journal Print 格式

```
=== Fibonacci 費波那契 | USDJPY | BUY | 2026.04.10 14:35 ===
  錨點 Anchors    | 波段高: 153.450  波段低: 152.800  幅度 Range: 65.0 pips
  回撤 Retrace    | 0.236: 152.953  0.382: 153.049  0.500: 153.125  0.618: 153.201  0.786: 153.311
  延伸 Extensions | 1.618: 153.851  2.618: 154.501  3.618: 155.151（耗盡位 Exhaustion）
  ATR 接近閾值    | ATR: 0.00130  閾值 Threshold: 0.00026 (2.6 pips)
  >>> 價格接近 Fib 0.618 (153.201) — 當前價 Current: 153.198  距離 Dist: 0.3 pips
```

---

## 8. Edge Cases

| 情況 | 處理 |
|---|---|
| `range = 0`（SwingHigh == SwingLow）| 所有 levels 相同，`IsFibNear()` 唔會誤觸發（threshold > 0）|
| `swing_high < swing_low` | 計算仍然正確，但邏輯錯誤應由 caller 保證 |
| ATR = 0 | threshold = 0，`IsFibNear()` 永遠返回 false |

---

## 9. 待調教 Pending Tuning

- [ ] `InpAtrMult = 0.20` 係 Pro spec 預設，forward test 後驗證
- [ ] 決定 v3 bot 用 M5 Fib 定 H1 Fib 做 Scoring #8
- [ ] H1 Veto 開發時確認 H1 Fib proximity 閾值

---

## 10. Changelog

見 `CHANGELOG.md`
