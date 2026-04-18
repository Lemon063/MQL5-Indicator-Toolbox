# SPEC_EngulfPinBar.md

版本 Version: 1.0
最後更新 Last updated: 2026-04
狀態 Status: Active

---

## 1. 用途 Purpose

偵測 Bullish/Bearish Engulfing 同 Bullish/Bearish Pin Bar。

用途：
- **Scoring #3（v3 spec）** — Candle pattern → 加分 +1
- **觸發條件（v3 spec）** — Candle pattern 係三個觸發條件之一

---

## 2. 依賴 Dependencies

```
EngulfPinBar
└── ATR.mqh   (GetPipSize — 多品種統一 pip 計算)
```

---

## 3. 函數 API

```mql5
// 由 OHLC 值建立 CandleData
CandleData BuildCandleData(double o, double h, double l, double c)

// 從 chart 取得指定 bar 嘅 CandleData
CandleData GetCandleData(string symbol, ENUM_TIMEFRAMES tf, int shift)

// 偵測 bar1 嘅 pattern（主要函數）
CandleSignal DetectCandlePattern(string symbol,
                                 ENUM_TIMEFRAMES tf,
                                 double pin_body_multi = 2.0,
                                 double pin_opp_multi  = 0.5,
                                 double min_body_pips  = 0.5)
```

---

## 4. Structs

```mql5
struct CandleData {
    double open, high, low, close;
    double body;        // |close - open|
    double upperWick;   // high - max(open, close)
    double lowerWick;   // min(open, close) - low
    bool   bullish;     // close > open
    bool   bearish;     // close < open
}

struct CandleSignal {
    bool   bullEngulf;  // 看漲吞噬
    bool   bearEngulf;  // 看跌吞噬
    bool   bullPin;     // 看漲針形
    bool   bearPin;     // 看跌針形
    bool   detected;    // 任何一個觸發
    string direction;   // "BUY" / "SELL" / "NONE"
}
```

---

## 5. 計算邏輯

### 看漲吞噬 Bullish Engulfing
```
bar2 係陰燭（bearish）
bar1 係陽燭（bullish）
bar1.open  < bar2.close    ← bar1 開市低於 bar2 收市
bar1.close > bar2.open     ← bar1 收市高於 bar2 開市
bar1.body  > minBodySize   ← 排除 Doji
```

### 看跌吞噬 Bearish Engulfing
```
bar2 係陽燭（bullish）
bar1 係陰燭（bearish）
bar1.open  > bar2.close    ← bar1 開市高於 bar2 收市
bar1.close < bar2.open     ← bar1 收市低於 bar2 開市
bar1.body  > minBodySize   ← 排除 Doji
```

### 看漲針形 Bullish Pin Bar
```
下影線 lowerWick >= body × pin_body_multi (2.0)
上影線 upperWick <= body × pin_opp_multi  (0.5)
燭身   body > minBodySize
```

### 看跌針形 Bearish Pin Bar
```
上影線 upperWick >= body × pin_body_multi (2.0)
下影線 lowerWick <= body × pin_opp_multi  (0.5)
燭身   body > minBodySize
```

### 方向優先順序
看漲（BullEngulf / BullPin）優先。同時觸發時取 BUY。

---

## 6. 參數 Parameters

| 參數 | 預設 | 說明 |
|---|---|---|
| `pin_body_multi` | 2.0 | Pin Bar 主影線倍數 |
| `pin_opp_multi` | 0.5 | Pin Bar 反向影線上限倍數 |
| `min_body_pips` | 0.5 | 最小燭身 pips，過濾 Doji |

Pip size 統一用 `ATR.mqh` 嘅 `GetPipSize()`，支援 USDJPY / GBPUSD / EURUSD / AUDUSD 無需額外設定。

---

## 7. 視覺輸出（.mq5）

| 元素 | 說明 |
|---|---|
| 綠色向上三角 | 看漲信號（BUY）— 位置：bar1 Low 下方 3 pips |
| 紅色向下三角 | 看跌信號（SELL）— 位置：bar1 High 上方 3 pips |

### Journal Print 格式
```
[EngulfPinBar 蠟燭形態] USDJPY | bar1=2026.04.10 14:35
  bar1 | O=153.250 H=153.380 L=153.200 C=153.360 | 燭身=11.0 pips | 上影=2.0 pips | 下影=5.0 pips | 陽燭
  bar2 | O=153.320 H=153.350 L=153.210 C=153.260 | 陰燭
  形態 | 看漲吞噬=1  看跌吞噬=0  看漲針=0  看跌針=0
  結果 | 方向 Direction=BUY  接受 Accepted=1
```

### CSV 欄位
```
serverTime, bar1Time, bar2Time,
BullEngulf, BearEngulf, BullPin, BearPin,
detected, direction
```

---

## 8. Edge Cases

| 情況 | 處理 |
|---|---|
| Doji（body ≈ 0）| `minBodySize` 過濾，唔觸發任何 pattern |
| 同時觸發 BullEngulf + BullPin | 兩個都記錄，direction = "BUY" |
| 同時觸發 BullEngulf + BearPin | 理論上可能，看漲優先，direction = "BUY" |
| Bar latch | 同一根 bar 唔重複接受 |

---

## 9. 待調教 Pending Tuning

- [ ] `pin_body_multi = 2.0` — forward test 後驗證
- [ ] `min_body_pips = 0.5` — 觀察 Doji 過濾效果後調整
- [ ] 考慮加入 bar1 嘅方向過濾（只喺趨勢方向入場）

---

## 10. Changelog

見 `CHANGELOG_EngulfPinBar.md`
