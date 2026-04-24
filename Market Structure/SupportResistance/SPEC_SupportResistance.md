# SPEC_SupportResistance.md

版本 Version: 1.0
最後更新 Last updated: 2026-04
狀態 Status: Active

---

## 1. 用途 Purpose

計算過去 N bars 嘅 High/Low 價格密集區，輸出帶強度分數嘅 S/R zone 清單。

用途：
- 為 `PivotSR.mqh` 提供 S/R 強度驗證
- Pivot 錨點需要 S/R 支持先係有效錨點
- 強度分數用作錨點選擇嘅 tiebreaker

---

## 2. 函數 API

```mql5
// 計算 S/R 密集區
SRResult CalcSRZones(string symbol, ENUM_TIMEFRAMES tf,
                     int lookback = 100, double zone_pips = 10.0,
                     int min_count = 4, int shift = 1)

// 檢查某價格係咪接近任何 S/R zone
bool IsPriceNearSR(double price, const SRResult &sr,
                   double tolerance, SRZone &best_zone)

// 返回強度最高嘅 S/R zone
SRZone GetStrongestSR(const SRResult &sr)
```

---

## 3. Structs

```mql5
struct SRZone {
    double price;   // 密集區中心價格
    int    count;   // 出現次數（High + Low 合計）
    bool   valid;   // 係咪符合最低門檻
}

struct SRResult {
    SRZone zones[200]; // 最多 200 個密集區
    int    total;      // 實際數量
}
```

---

## 4. 計算邏輯

```
每根 bar 貢獻兩個點：High + Low

1. 將 High/Low 四捨五入到最近嘅 grid：
   grid_price = Round(price / grid_size) × grid_size
   grid_size  = zone_pips × pip

2. 統計每個 grid price 出現次數

3. 過濾：count >= min_count 先保留

4. 輸出：SRResult（帶價格同強度）
```

---

## 5. 參數 Parameters

| 參數 | 預設 | 說明 |
|---|---|---|
| `lookback` | 100 | 回望 bars 數 |
| `zone_pips` | 10.0 | 密集區格距 pips |
| `min_count` | 4 | 最低出現次數門檻 |
| `shift` | 1 | 從最後收盤 bar 開始 |

---

## 6. Edge Cases

| 情況 | 處理 |
|---|---|
| 密集區超過 200 個 | 截停，唔再加入（實際唔會發生）|
| count < min_count | 直接 ignore |
| tolerance = 0 | `IsPriceNearSR()` 永遠返回 false |

---

## 7. 依賴 Dependencies

無外部依賴。純用 `iHigh()` / `iLow()`。

---

## 8. 待調教 Pending Tuning

- [ ] `zone_pips = 10.0` — forward test 後驗證最優格距
- [ ] `min_count = 4` — forward test 後調整門檻

---

## 9. Changelog

見 `CHANGELOG_SupportResistance.md`

---

## 10. 版本記錄 Version Notes

### v1.1 變更
- pip 計算改用 `ATR.mqh` 嘅 `GetPipSize()`
- 加入 `#include <Toolbox/ATR.mqh>`
- 原因：`SYMBOL_POINT * 10` 喺 JPY pair 計算錯誤

### 依賴更新
```
SupportResistance.mqh
└── ATR.mqh  (GetPipSize) ← v1.1 新增
```
