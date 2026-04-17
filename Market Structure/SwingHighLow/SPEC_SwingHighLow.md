# SwingHighLow — SPEC.md

版本 Version: 1.0
最後更新 Last updated: 2026-04
狀態 Status: Active

---

## 1. 用途 Purpose

計算過去 N 根 K 線的最高 High（Swing High）同最低 Low（Swing Low）。

係以下 indicator 的依賴底層：
- `Fibonacci.mqh` — 用 Swing High/Low 作為 Fib 計算起點
- `BOS.mqh` — 用 Swing High/Low 作為突破判斷基準
- `H1 Veto` — 用 H1 Swing 識別關鍵阻力/支撐位

---

## 2. 函數 API

```mql5
// 單獨取值
double GetSwingHigh(string symbol, ENUM_TIMEFRAMES tf, int n_bars, int shift = 1)
double GetSwingLow (string symbol, ENUM_TIMEFRAMES tf, int n_bars, int shift = 1)

// 取發生位置（bar index）
int GetSwingHighShift(string symbol, ENUM_TIMEFRAMES tf, int n_bars, int shift = 1)
int GetSwingLowShift (string symbol, ENUM_TIMEFRAMES tf, int n_bars, int shift = 1)

// 一次取得全部（推薦）
SwingResult GetSwing(string symbol, ENUM_TIMEFRAMES tf, int n_bars, int shift = 1)
```

### SwingResult Struct

```mql5
struct SwingResult {
    double high;        // Swing High 價格
    double low;         // Swing Low 價格
    int    high_shift;  // Swing High 發生的 bar index
    int    low_shift;   // Swing Low 發生的 bar index
}
```

---

## 3. 參數 Parameters

| 參數 | 預設 | 說明 |
|---|---|---|
| `symbol` | — | 交易品種，傳入 `_Symbol` |
| `tf` | — | 時間框架，`PERIOD_M5` 或 `PERIOD_H1` |
| `n_bars` | 20 | Lookback bar 數，可在 `.mq5` input 調整 |
| `shift` | 1 | 從第幾根 bar 開始計（1 = 最後一根已收盤 bar）|

### Lookback 預設值決策

| 時間框架 | 預設 N | 理由 |
|---|---|---|
| M5 | 20 | v3 spec (10-15) 同 Pro spec (30) 取中間值，forward test 後調整 |
| H1 | 30 | Pro spec 預設，H1 Veto 開發時再驗證 |

---

## 4. 計算邏輯

```
SwingHigh = max(High[shift], High[shift+1], ..., High[shift+n_bars-1])
SwingLow  = min(Low[shift],  Low[shift+1],  ..., Low[shift+n_bars-1])
```

`shift = 1` 確保永遠只用已收盤的 bar，唔會用到未收盤的當前 bar。

---

## 5. 視覺輸出（.mq5）

| 線條 | 顏色 | 樣式 | 說明 |
|---|---|---|---|
| M5 Swing High | 紅色 | 虛線 | M5 lookback 最高點 |
| M5 Swing Low | 藍色 | 虛線 | M5 lookback 最低點 |
| H1 Swing High | 深紅 | 實線粗 | H1 lookback 最高點 |
| H1 Swing Low | 深藍 | 實線粗 | H1 lookback 最低點 |

### Journal Print 格式

```
=== SwingHighLow 波段高低位 | USDJPY | 2026.04.10 14:35 ===
  M5(20 bars) | 波段高 SwingHigh: 153.450 (bar 7)  波段低 SwingLow: 152.800 (bar 15)  幅度 Range: 65.0 pips
  H1(30 bars) | 波段高 SwingHigh: 153.600 (bar 2)  波段低 SwingLow: 152.500 (bar 8)   幅度 Range: 110.0 pips
```

---

## 6. Edge Cases

| 情況 | 處理 |
|---|---|
| `rates_total < n_bars + 2` | 直接 return，唔計算 |
| `shift = 0`（當前未收盤 bar）| 強制設為 1，唔用未收盤 bar |
| 多個 bar 同樣係最高/最低 | 返回最近的（shift 最小的），符合 trader 習慣 |
| Symbol 唔存在 | `iHigh()`/`iLow()` 返回 0，caller 負責 validate |

---

## 7. 依賴 Dependencies

無外部依賴。純用 MQL5 built-in `iHigh()` / `iLow()`。

---

## 8. 待調教 Pending Tuning

- [ ] M5 N-bar 最優值：forward test 後比較 n=10, 15, 20, 30 的 BOS 假突破率
- [ ] H1 N-bar 最優值：H1 Veto 開發時一併測試

---

## 9. Changelog

見 `CHANGELOG.md`
