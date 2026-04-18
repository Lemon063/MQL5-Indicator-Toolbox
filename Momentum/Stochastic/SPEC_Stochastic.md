# SPEC_Stochastic.md

版本 Version: 1.0
最後更新 Last updated: 2026-04
狀態 Status: Active

---

## 1. 用途 Purpose

偵測 Stochastic K/D 金叉、死叉、超買、超賣。

用途：
- **Scoring #1（v3 spec）** — Stoch cross → 觸發條件 + 加分 +1
- **Scoring #2（v3 spec）** — K1 在 OB/OS 區 → 加分 +1
- **MTF Scoring #5（v3 spec）** — M15 CrossUp 或在 OS 區 → 加分 +1

---

## 2. 函數 API

```mql5
// 建立 handle（喺 OnInit() 調用）
int CreateStochHandle(string symbol, ENUM_TIMEFRAMES tf,
                      int k_period, int d_period, int smooth)

// 取得單一 bar 嘅 K/D 值
StochBar GetStochValues(int handle, int shift)

// 一次過取得 bar0/1/2 並判斷 cross + OB/OS（主要函數）
StochSignal DetectStochSignal(int handle,
                              double ob_level = 80.0,
                              double os_level = 20.0)
```

---

## 3. Structs

```mql5
struct StochBar {
    double K;   // K 值
    double D;   // D 值
}

struct StochSignal {
    bool   crossUp;    // 金叉：K 由下穿上 D
    bool   crossDown;  // 死叉：K 由上穿下 D
    bool   isOB;       // 超買：K1 >= ob_level
    bool   isOS;       // 超賣：K1 <= os_level
    double K0, D0;     // bar0（當前未收盤）
    double K1, D1;     // bar1（最後收盤，cross 判斷用）
    double K2, D2;     // bar2（前一收盤，cross 判斷用）
}
```

---

## 4. 計算邏輯

### Cross 定義（spec_v3_trader_logic.md §5.3）
```
CrossUp   = K2 <= D2  AND  K1 > D1   ← 金叉
CrossDown = K2 >= D2  AND  K1 < D1   ← 死叉
```

只用 bar1 / bar2（已收盤），唔用 bar0（未收盤）。

### CopyBuffer 索引說明
```
靜態 array，AsSeries = false（靜態 array 唔受影響）
index 0 = 最舊（bar2）
index 1 = 中間（bar1）
index 2 = 最新（bar0）
```

### OB / OS
```
isOB = K1 >= 80  （超買）
isOS = K1 <= 20  （超賣）
```

---

## 5. 參數 Parameters

| 參數 | 預設 | 說明 |
|---|---|---|
| `InpK` | 14 | K 週期 |
| `InpD` | 3 | D 週期 |
| `InpSmooth` | 3 | 平滑期數 |
| `InpOB` | 80.0 | 超買水平 |
| `InpOS` | 20.0 | 超賣水平 |
| `InpBarLatch` | true | 每根 bar 只接受一個信號 |

---

## 6. 視覺輸出（.mq5）

| 元素 | 說明 |
|---|---|
| 白色實線 | K line |
| 橙色虛線 | D line |
| 水平點線 | OB 80 / OS 20 |
| 箭咀（sub-window）| 金叉 / 死叉位置 |

### Journal Print 格式
```
[Stoch 隨機指標] USDJPY | bar1=2026.04.10 14:35
  K值   | K0=55.23  K1=21.45  K2=18.92
  D值   | D0=52.10  D1=19.88  D2=18.50
  狀態  | 金叉 CrossUp=1  死叉 CrossDown=0  超買 OB=0  超賣 OS=1
  結果  | 方向 Direction=BUY  接受 Accepted=1
```

### CSV 欄位
```
serverTime, bar0Time, bar1Time, bar2Time,
K0, D0, K1, D1, K2, D2,
crossUp, crossDown, isOS, isOB, direction
```

---

## 7. Edge Cases

| 情況 | 處理 |
|---|---|
| Handle 建立失敗 | `OnInit()` 返回 `INIT_FAILED` |
| CopyBuffer 失敗 | 返回空 struct（所有值 0 / false）|
| 同一根 bar 多次觸發 | `InpBarLatch = true` 拒絕重複 |
| CrossUp 同 CrossDown 同時 true | 理論上唔可能（K 唔可以同時穿上同穿落）|

---

## 8. 依賴 Dependencies

無外部依賴。純用 MQL5 built-in `iStochastic()`。

---

## 9. 待調教 Pending Tuning

- [ ] K=14, D=3, Smooth=3 係起點，forward test 後調整
- [ ] MTF Stoch（M15）開發時確認係用同一個 `.mqh` 還是獨立 handle

---

## 10. Changelog

見 `CHANGELOG_Stochastic.md`
