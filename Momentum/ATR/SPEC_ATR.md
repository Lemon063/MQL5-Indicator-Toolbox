# ATR — SPEC.md

版本 Version: 1.0
最後更新 Last updated: 2026-04
狀態 Status: Active

---

## 1. 用途 Purpose

提供 ATR 值及所有基於 ATR 的衍生計算，係大部分其他 indicator 的共用底層。

用途：
- **SL 計算** — `1.5 × ATR`（正常）/ `2.0 × ATR`（Event window）
- **Trailing Stop（Leg B Phase 2）** — `1.5 × ATR`
- **Fib Proximity Threshold** — `ATR × 0.20`
- **BOS Momentum 確認** — bar movement vs ATR（BOS.mqh 調用）
- **Pip Size 轉換** — 所有品種統一計算

---

## 2. 函數 API

```mql5
// 基礎
double GetPipSize(string symbol)
double GetATR(string symbol, ENUM_TIMEFRAMES tf, int period, int shift = 1)
double GetATRPips(string symbol, ENUM_TIMEFRAMES tf, int period, int shift = 1)

// SL 計算
double GetSL_ATR(string symbol, ENUM_TIMEFRAMES tf, int period,
                 double mult = 1.5, int shift = 1)
double GetSL_ATR_Pips(string symbol, ENUM_TIMEFRAMES tf, int period,
                      double mult = 1.5, int shift = 1)
double GetMinSL_Pips(string symbol)
double GetEffectiveSL_Pips(string symbol, ENUM_TIMEFRAMES tf, int period,
                            double mult = 1.5, int shift = 1)

// Trailing + Fib
double GetTrailingStop_ATR(string symbol, ENUM_TIMEFRAMES tf,
                           int period, double mult = 1.5, int shift = 1)
double GetFibProximityThreshold(string symbol, ENUM_TIMEFRAMES tf,
                                int period, double mult = 0.20, int shift = 1)
```

---

## 3. 參數 Parameters

| 參數 | 預設 | 說明 |
|---|---|---|
| `period` | 14 | ATR 計算 bar 數（市場標準）|
| `shift` | 1 | 用最後一根已收盤 bar |
| `InpSL_Mult` | 1.50 | 正常 SL 乘數（v3 spec 起點）|
| `InpEventSL_Mult` | 2.00 | Event window SL 乘數（v3 spec）|
| `InpFibMult` | 0.20 | Fib proximity 乘數（Pro spec 預設）|

---

## 4. 計算邏輯

### Pip Size
```
pip = SYMBOL_POINT × 10

USDJPY (3 digits): point = 0.001 → pip = 0.010
GBPUSD (5 digits): point = 0.00001 → pip = 0.0001
EURUSD (5 digits): point = 0.00001 → pip = 0.0001
AUDUSD (5 digits): point = 0.00001 → pip = 0.0001
```

### Effective SL
```
ATR_SL     = ATR × mult
Min_SL     = GetMinSL_Pips() × pip
Effective  = max(ATR_SL, Min_SL)
```

### Minimum SL Floor（v3 spec）
| Symbol | Min SL |
|---|---|
| USDJPY | 6 pips |
| 其他 | 4 pips（待 forward test 確認）|

---

## 5. 視覺輸出（.mq5）

Sub-window 顯示三條線：

| 線條 | 顏色 | 說明 |
|---|---|---|
| ATR | 白色 | Raw ATR 值 |
| SL 1.5x | 橙色虛線 | 正常 SL 距離 |
| SL 2.0x | 紅色虛線 | Event window SL 距離 |

### Journal Print 格式

```
=== ATR 真實波幅 | USDJPY | 2026.04.10 14:35 ===
  ATR 原始值   | 0.00130  (13.0 pips)
  正常止損 SL  | 1.5x ATR = 0.00195  (19.5 pips)  |  最低下限: 6.0 pips  |  有效 SL: 19.5 pips
  新聞止損 SL  | 2.0x ATR = 0.00260  (26.0 pips)  |  有效 SL: 26.0 pips
  追蹤止損     | 1.5x ATR = 0.00195  (19.5 pips)
  Fib 接近閾值 | 0.20x ATR = 0.00026  (2.6 pips)
```

---

## 6. Edge Cases

| 情況 | 處理 |
|---|---|
| `iATR()` 返回 `INVALID_HANDLE` | 返回 `0.0`，caller 負責 validate |
| `CopyBuffer()` 失敗 | 返回 `0.0` |
| `pip = 0`（無效 symbol）| `GetATRPips()` 返回 `0.0` |
| ATR = 0（數據不足）| `GetEffectiveSL_Pips()` 返回 `GetMinSL_Pips()`，保底保護 |

---

## 7. 待調教 Pending Tuning

- [ ] `InpSL_Mult = 1.5` — v3 spec 起點，forward test 後驗證
- [ ] `InpEventSL_Mult = 2.0` — v3 spec，event mode 開發時一併測試
- [ ] GBPUSD / EURUSD / AUDUSD 的 `GetMinSL_Pips()` 下限（現為 4 pips 暫定）
- [ ] ATR period 14 vs 20 — backtest 比較

---

## 8. Changelog

見 `CHANGELOG.md`
