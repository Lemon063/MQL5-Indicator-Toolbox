# SPEC_FibTypes.md

版本 Version: 1.0
最後更新 Last updated: 2026-04
狀態 Status: Active

---

## 1. 用途 Purpose

儲存 `FibLevels` struct 定義。

抽出獨立 file 嘅原因：
- `PivotSR.mqh` 需要 `FibLevels`（用於 `CalcFibSRScore()`）
- `Fibonacci.mqh` include `PivotSR.mqh`
- 如果 `FibLevels` 定義喺 `Fibonacci.mqh`，會造成循環依賴
- 解決方案：`FibLevels` 抽出去 `FibTypes.mqh`，兩個都 include 佢

---

## 2. Struct

```mql5
struct FibLevels {
    double swing_high;   // Pivot High 錨點（1.000）
    double swing_low;    // Pivot Low 錨點（0.000）
    double range;        // swing_high - swing_low
    double fib_236;
    double fib_382;
    double fib_500;
    double fib_618;
    double fib_786;
    double fib_1000;
    double fib_1618;
    double fib_2618;
    double fib_3618;
    bool   is_buy;
}
```

---

## 3. 依賴 Dependencies

無。純 struct 定義，冇任何 include。

---

## 4. Changelog

見 `CHANGELOG_FibTypes.md`
