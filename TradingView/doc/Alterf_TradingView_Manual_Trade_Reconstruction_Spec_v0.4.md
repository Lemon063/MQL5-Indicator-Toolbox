# Alterf TradingView Manual Trade Reconstruction Specification
# Alterf TradingView 人手交易判斷重建規格

**Original Date / 原始日期:** 20 July 2026  
**Last Updated / 最後更新:** 21 July 2026  
**Version / 版本:** 0.4 Working Draft  
**Implementation Language / 實作語言:** TradingView Pine Script v6  
**File Structure / 檔案結構:** One integrated Pine Script file / 單一整合式 Pine Script 檔案

---

# 1. Purpose / 文件目的

This specification defines one TradingView Pine Script that observes and classifies market behaviour using measurable price data.

本規格定義一個 TradingView Pine Script，利用可以量化嘅價格資料，觀察及分類市場行為。

The script is not assumed to reproduce the user's manual trading performance before testing.

喺實際測試之前，唔可以假設個程式已經能夠複製用戶人手交易表現。

The purpose is to discover:

目的係實際測試：

- Which parts of manual market reading Pine can reconstruct reliably / Pine可以可靠重建邊部分人手市場判斷
- Which parts produce useful but imperfect evidence / 邊部分只可以提供有用但唔完整嘅證據
- Which parts require human or AI interpretation / 邊部分仍然需要人手或者AI判斷
- Which functions may later be moved into MT5 / 邊部分日後適合搬入MT5

The script must explain its classifications through visible intermediate values.

程式唔可以只輸出結論，必須顯示推導結論所使用嘅中間數值。

---

# 2. Non-Goals / 非目標

This Pine Script will not:

- Execute trades / 執行交易
- Automatically choose discretionary Fibonacci swings / 自動決定應該畫邊一段Fibonacci
- Automatically replace manually selected support and resistance / 自動取代用戶人手選擇嘅支持阻力
- Guarantee profitable signals / 保證交易訊號有盈利
- Assume one equation can fully describe healthy or messy markets / 假設一條公式可以完整定義健康或混亂市場
- Use EMA as a core feature / 使用EMA作為核心功能

EMA-related logic is excluded because EMA is not part of the user's current manual trading process.

EMA唔屬於用戶目前人手交易流程，因此從核心規格刪除。

---

# 3. File Architecture / 檔案架構

Use one Pine Script file:

`Alterf_Manual_Trade_Analyzer.pine`

The file contains logical sections, not separate Pine libraries.

檔案內會分功能區，但唔會拆成多個Pine Library。

Recommended internal sections:

1. Constants, Types and Inputs / 常數、資料類型與輸入
2. Shared Price Calculations / 共用價格計算
3. Multi-Timeframe Data / 多時間框架資料
4. Manual Levels and Price Location / 人手水平與價格位置
5. Previous High / Low / 前高與前低
6. Consolidation Analysis / 整固分析
7. Market Structure and Regime Evidence / 市場結構與市場狀態證據
8. Momentum Analysis / 動能分析
9. Candle Behaviour / 蠟燭行為
10. Breakout Lifecycle / 突破生命週期
11. Session and News Context / 交易時段與新聞背景
12. State Transition / 狀態轉換
13. Output, Alerts and Debug / 輸出、警報與除錯

These sections are organisational only.

以上只係程式組織方式，唔代表市場必然由13個獨立系統組成。

---

# 4. Common Price Equations / 共用價格公式

```text
Range = High - Low
Body = abs(Close - Open)
Upper Wick = High - max(Open, Close)
Lower Wick = min(Open, Close) - Low
Body Ratio = Body / Range
Upper Wick Ratio = Upper Wick / Range
Lower Wick Ratio = Lower Wick / Range
Close Location = (Close - Low) / Range
Bullish Progress = max(Close - Open, 0)
Bearish Progress = max(Open - Close, 0)
```

Interpretation:

```text
Close Location ≈ 1.00 = Close near candle high / 收市接近最高位
Close Location ≈ 0.00 = Close near candle low / 收市接近最低位
```

If `Range = 0`, ratio values must return zero or `na` according to the function requirements.

如果 `Range = 0`，必須避免除零錯誤。

---

# 5. Inputs and Settings / 輸入與設定

## 5.1 Display Settings / 顯示設定

- Show Debug Table / 顯示除錯表格
- Show Candle Labels / 顯示蠟燭標籤
- Show Breakout States / 顯示突破狀態
- Show Manual Levels / 顯示人手水平
- Show Previous High / Low / 顯示前高前低
- Show Consolidation Boundaries / 顯示整固邊界

These settings control display only and must not change analytical results.

以上設定只控制顯示，不得改變分析結果。

## 5.2 Calculation Settings / 計算設定

Every threshold must be exposed as an input.

所有threshold都必須可以喺TradingView設定修改。

Examples:

- Structure Lookback / 結構回望長度
- Consolidation Lookback / 整固回望長度
- Minimum Body Ratio / 最低實體比例
- Minimum Wick Ratio / 最低影線比例
- Breakout Buffer / 突破緩衝距離
- Follow-Through Bars / 確認突破等待支數
- Retest Tolerance / 回測容許距離

No threshold may be hard-coded without being documented.

不得加入無記錄嘅隱藏固定參數。

---

# 6. Multi-Timeframe Data / 多時間框架資料

The script must analyse M5, M15, M30 and H1.

For each timeframe, obtain confirmed-bar values:

- Open
- High
- Low
- Close
- Volume
- Time

Higher-timeframe calculations should use completed higher-timeframe bars where possible.

高時間框架分析應優先使用已完成蠟燭，避免未收市數據不斷改變。

For each timeframe, calculate:

- Current directional structure / 目前方向結構
- Recent swing high and swing low / 最近擺動高低
- Directional efficiency / 方向效率
- Candle sequence / 蠟燭序列
- Range expansion or contraction / 波幅擴張或收縮

---

# 7. Manual Support, Resistance and Fibonacci / 人手支持、阻力與Fibonacci

The user determines important SR and Fibonacci anchors manually.

重要SR及Fibonacci範圍由用戶人手判斷。

## 7.1 Manual SR Inputs / 人手SR輸入

Provide configurable price inputs:

- Manual Resistance 1-3
- Manual Support 1-3

Each level may be enabled or disabled individually.

```text
Signed Distance = Close - Level
Absolute Distance = abs(Close - Level)
Normalised Distance = abs(Close - Level) / ATR
Near Level = abs(Close - Level) <= Level Tolerance
```

ATR is used only as a volatility unit, not as a trading signal.

ATR只用作比較距離單位，唔係入場indicator。

## 7.2 Manual Fibonacci Anchors / 人手Fibonacci起點終點

Inputs:

- Fib Anchor A
- Fib Anchor B
- Fib Direction

For a bullish swing:

```text
Swing Range = High Anchor - Low Anchor
Fib 38.2 = High Anchor - Swing Range × 0.382
Fib 50.0 = High Anchor - Swing Range × 0.500
Fib 61.8 = High Anchor - Swing Range × 0.618
```

For a bearish swing:

```text
Swing Range = High Anchor - Low Anchor
Fib 38.2 = Low Anchor + Swing Range × 0.382
Fib 50.0 = Low Anchor + Swing Range × 0.500
Fib 61.8 = Low Anchor + Swing Range × 0.618
```

Pine calculates the levels after the user chooses the anchors. It must not decide which swing should be used.

---

# 8. VAH, VAL and POC / 價值區高位、低位與成交量控制點

Two operating modes must be supported.

## 8.1 Manual Mode / 人手模式

Inputs:

- Manual VAH
- Manual VAL
- Manual POC

This is the preferred initial mode.

## 8.2 Pine Approximation Mode / Pine估算模式

Required inputs:

- Profile Start Time
- Profile End Time
- Number of Price Bins
- Value Area Percentage
- Lower-Timeframe Resolution

```text
Profile High = highest High inside profile period
Profile Low = lowest Low inside profile period
Bin Size = (Profile High - Profile Low) / Number of Bins
Typical Price = (High + Low + Close) / 3
POC Bin = bin with maximum allocated volume
Total Volume = sum of all bin volumes
Target Volume = Total Volume × Value Area Percentage
VAH = upper edge of included bins
VAL = lower edge of included bins
```

Starting from POC, include adjacent bins with the higher volume until cumulative volume reaches the target.

Limitations:

- Results may differ from TradingView built-in Volume Profile.
- 外匯volume可能只係tick volume。
- Results depend on chart feed, lower timeframe and bin allocation method.

---

# 9. Previous High and Previous Low / 前高與前低

Required types:

- Previous Day High / Low
- Previous London Session High / Low
- Previous New York Session High / Low
- Confirmed Swing High / Low

```text
Previous Day High = highest price during previous trading day
Previous Day Low = lowest price during previous trading day

Previous London High = highest High during previous London session
Previous London Low = lowest Low during previous London session
```

Confirmed swing:

```text
Swing High at bar i:
High[i] is greater than the highs of L bars before and R bars after

Swing Low at bar i:
Low[i] is lower than the lows of L bars before and R bars after
```

Swing output is delayed by `R` bars because right-side confirmation is required.

---

# 10. Consolidation Analysis / 整固分析

```text
Window High = highest High over N bars
Window Low = lowest Low over N bars
Window Range = Window High - Window Low
Normalised Window Range = Window Range / ATR
Net Progress = abs(Close - Close[N-1])
Total Path = sum(abs(Close[i] - Close[i-1])) over N bars
Efficiency Ratio = Net Progress / Total Path
```

Candle overlap:

```text
Overlap =
max(0, min(Current High, Previous High) - max(Current Low, Previous Low))

Minimum Range = min(Current Range, Previous Range)
Overlap Ratio = Overlap / Minimum Range
Average Overlap Ratio = average Overlap Ratio over N bars
```

Direction change:

```text
Direction = +1 when Close > Open
Direction = -1 when Close < Open
Direction = 0 when Close = Open

Direction Change Ratio =
Number of direction changes / valid comparisons
```

Consolidation candidate:

```text
Consolidation Candidate =
Efficiency Ratio <= Maximum Efficiency Threshold
AND
Average Overlap Ratio >= Minimum Overlap Threshold
AND
Normalised Window Range <= Maximum Range Threshold
```

Optional:

```text
Direction Change Ratio >= Minimum Change Threshold
```

When valid:

```text
Consolidation High = Window High
Consolidation Low = Window Low
```

The boundary must be frozen during breakout evaluation.

---

# 11. Market Structure / 市場結構

Bullish:

```text
Latest Swing High > Previous Swing High
AND
Latest Swing Low > Previous Swing Low
```

Bearish:

```text
Latest Swing High < Previous Swing High
AND
Latest Swing Low < Previous Swing Low
```

Mixed structure:

```text
Expanding =
Latest Swing High > Previous Swing High
AND
Latest Swing Low < Previous Swing Low

Contracting =
Latest Swing High < Previous Swing High
AND
Latest Swing Low > Previous Swing Low
```

---

# 12. Multi-Timeframe Alignment / 多時間框架一致性

Each timeframe returns:

```text
+1 Bullish
0 Neutral / Unresolved
-1 Bearish
```

```text
Alignment Score =
M5 Weight × M5 Direction
+
M15 Weight × M15 Direction
+
M30 Weight × M30 Direction
+
H1 Weight × H1 Direction
```

Weights must be configurable and each timeframe must be shown separately.

---

# 13. Market Regime Classification / 市場狀態分類

Required outputs:

- Trend / 趨勢
- Consolidation / 整固
- Breakout Attempt / 突破嘗試
- Messy / 混亂
- Transition / Unresolved / 轉換中或未解決

Trend Score:

```text
Efficiency Score =
clamp(
    (Efficiency Ratio - Trend Efficiency Minimum)
    /
    (Trend Efficiency Maximum - Trend Efficiency Minimum),
    0,
    1
)

Bullish Directional Close Ratio = count(Close > Close[1]) / N
Bearish Directional Close Ratio = count(Close < Close[1]) / N

Trend Score =
w1 × Structure Score
+
w2 × Efficiency Score
+
w3 × Alignment Score
+
w4 × Directional Close Score
```

Consolidation Score:

```text
Low Efficiency Score = 1 - normalised Efficiency Ratio
High Overlap Score = normalised Average Overlap Ratio

Consolidation Score =
w1 × Low Efficiency Score
+
w2 × High Overlap Score
+
w3 × Contained Range Score
+
w4 × Direction Change Score
```

Breakout attempt:

```text
Bullish Boundary Exit =
Previous Close <= Breakout Level
AND
Current Close > Breakout Level

Bearish Boundary Exit =
Previous Close >= Breakout Level
AND
Current Close < Breakout Level
```

Messy evidence:

```text
Failed Break Ratio =
Number of failed breaks / Number of breakout attempts

Alternating Expansion =
Current candle direction opposite to previous candle
AND
Current Range >= Median Range × Expansion Threshold
AND
Previous Range >= Median Range × Expansion Threshold

Messy Score =
w1 × Direction Change Score
+
w2 × Failed Break Score
+
w3 × Timeframe Conflict Score
+
w4 × Alternating Expansion Score
```

Regime selection:

```text
If active breakout lifecycle exists:
    Regime = Breakout Attempt
Else if Trend Score >= Trend Threshold:
    Regime = Trend
Else if Consolidation Score >= Consolidation Threshold:
    Regime = Consolidation
Else if Messy Score >= Messy Threshold:
    Regime = Messy
Else:
    Regime = Transition / Unresolved
```

All scores must be visible.

---

# 14. Momentum Analysis / 動能分析

```text
Median Range = median candle Range over N bars
Range Expansion Ratio = Current Range / Median Range
Median Body = median candle Body over N bars
Body Expansion Ratio = Current Body / Median Body
Bullish Progress = max(Close - Previous Close, 0)
Bearish Progress = max(Previous Close - Close, 0)
```

Pullback:

```text
Impulse Distance = Impulse High - Impulse Start
Pullback Distance = Impulse High - Current Low
Pullback Ratio = Pullback Distance / Impulse Distance
```

Accelerating candidate:

```text
Current directional progress > Previous directional progress
AND
Range Expansion Ratio increasing
AND
Body Expansion Ratio increasing
AND
Close Location remains strong
```

Healthy continuation candidate:

```text
Structure remains directional
AND
Directional closes continue
AND
No deep pullback
AND
No strong opposite rejection
AND
Progress remains positive but is not rapidly expanding
```

Slowing candidate:

```text
Directional progress decreases
AND
Body size decreases
AND
Wicks against movement increase
AND
Price still makes progress but progress per candle declines
```

```text
Progress Decay Ratio =
Current Directional Progress
/
average Directional Progress of previous K candles
```

Exhaustion candidate:

```text
Price reaches or exceeds important level
AND
Range or wick expands
AND
Close fails to remain near directional extreme
AND
Next candle fails to continue
```

Reversal candidate:

```text
Exhaustion or failed continuation occurred
AND
Opposite candle evidence appears
AND
A relevant minor structure level is broken
AND
Opposite follow-through appears
```

---

# 15. Candle Behaviour Engine / 蠟燭行為分析

Bullish Engulfing:

```text
Previous Close < Previous Open
AND
Current Close > Current Open
AND
Current Open <= Previous Close
AND
Current Close >= Previous Open
```

Bearish Engulfing:

```text
Previous Close > Previous Open
AND
Current Close < Current Open
AND
Current Open >= Previous Close
AND
Current Close <= Previous Open
```

Bullish Rejection:

```text
Lower Wick Ratio >= Minimum Lower Wick Ratio
AND
Lower Wick >= Body × Minimum Wick-to-Body Ratio
AND
Close Location >= Minimum Bullish Close Location
```

Bearish Rejection:

```text
Upper Wick Ratio >= Minimum Upper Wick Ratio
AND
Upper Wick >= Body × Minimum Wick-to-Body Ratio
AND
Close Location <= Maximum Bearish Close Location
```

Long wick:

```text
Long Upper Wick = Upper Wick Ratio >= Long Wick Threshold
Long Lower Wick = Lower Wick Ratio >= Long Wick Threshold
```

Doji-like hesitation:

```text
Body Ratio <= Doji Body Threshold
```

Small-body hesitation:

```text
Body Ratio <= Small Body Threshold
AND
Range Expansion Ratio is not extremely small
```

Inside bar:

```text
Current High <= Previous High
AND
Current Low >= Previous Low
```

Outside bar:

```text
Current High >= Previous High
AND
Current Low <= Previous Low
```

Consecutive directional closes:

```text
Bullish: Close > Close[1] > Close[2] > ...
Bearish: Close < Close[1] < Close[2] < ...
```

Expansion candle:

```text
Expansion Candle =
Range Expansion Ratio >= Range Expansion Threshold
AND
Body Expansion Ratio >= Body Expansion Threshold
```

Weak close:

```text
Bullish candle with weak close =
Close > Open
AND
Close Location < Bullish Strong Close Threshold

Bearish candle with weak close =
Close < Open
AND
Close Location > Bearish Strong Close Threshold
```

---

# 16. Important-Level Context Score / 重要水平背景分數

```text
Near Manual SR               +1
Near Manual Fibonacci        +1
Near Previous Day High/Low   +1
Near Session High/Low        +1
Near VAH/VAL/POC             +1
Near Consolidation Boundary  +1
```

This is context evidence, not a trade signal.

---

# 17. Breakout Level Selection / 突破水平選擇

Possible sources:

- Manual Resistance / Support
- Manual Fibonacci
- Previous Day High / Low
- Previous Session High / Low
- Confirmed Swing High / Low
- Consolidation High / Low
- Manual or calculated VAH / VAL

Output must include level price, type, direction, creation time and age.

---

# 18. Breakout Lifecycle / 突破生命週期

Required states:

- IDLE
- LEVEL_APPROACH
- LEVEL_BREAK
- BREAKOUT_CANDIDATE
- WAITING_FOR_FOLLOW_THROUGH
- CONFIRMED_BREAKOUT
- FAILED_BREAKOUT
- WAITING_FOR_RETEST
- RETEST_IN_PROGRESS
- RETEST_HOLD
- RETEST_FAIL
- EXPIRED

Level approach:

```text
abs(Close - Breakout Level) <= Approach Tolerance
```

Level break:

```text
Bullish = Previous Close <= Level AND Current Close > Level
Bearish = Previous Close >= Level AND Current Close < Level
```

Wick break:

```text
Bullish Wick Break = High > Level AND Close <= Level
Bearish Wick Break = Low < Level AND Close >= Level
```

Break distance:

```text
Bullish Break Distance = Close - Level
Bearish Break Distance = Level - Close
Normalised Break Distance = Break Distance / ATR
```

Breakout quality:

```text
Bullish Breakout Quality =
w1 × Body Quality
+
w2 × Close Quality
+
w3 × Break Distance Quality
+
w4 × Expansion Quality
-
w5 × Opposite Wick Penalty
```

Breakout candidate:

```text
Level Break = true
AND
Breakout Quality >= Candidate Threshold
```

Second-bar follow-through:

```text
Previous State = BREAKOUT_CANDIDATE
AND
Current Close progresses beyond Previous Close
AND
Current Close remains outside Breakout Level
AND
Current Close Location is strong
AND
No strong opposite rejection appears
```

Classifications:

- Strong Follow-Through
- Weak Follow-Through
- No Follow-Through
- Immediate Failure

Confirmed breakout routes:

```text
Route A: Candidate → strong second-bar follow-through
Route B: Candidate → several closes outside level
Route C: Candidate → retest → hold → renewed continuation
```

Failed breakout:

```text
Price previously closed outside level
AND
Price closes back inside within Maximum Failure Bars
```

Retest zone:

```text
Lower Bound = Breakout Level - Retest Tolerance
Upper Bound = Breakout Level + Retest Tolerance
```

Retest hold:

```text
Price enters retest zone
AND
Close remains outside or recovers outside breakout level
AND
Directional rejection or continuation evidence appears
AND
Price does not close deeply inside old range
```

Retest fail:

```text
Price enters retest zone
AND
Close returns through breakout level
AND
Follow-up price continues inside old range
```

---

# 19. Session Context / 交易時段背景

Required states:

- Asian / Overnight
- Pre-London
- London Open
- London Mid
- London Late
- New York Open
- London / New York Overlap
- Post-London / Close Decline

For each session:

```text
Session Range = Session High - Session Low
Session Net Progress = abs(Current Close - Session Open)
Session Efficiency =
Session Net Progress / sum(abs(Close[i] - Close[i-1]))
```

Overnight consolidation:

```text
Overnight session active
AND
Consolidation Candidate = true
AND
Session Range below threshold
```

Close momentum decline:

```text
Recent Average Range < Earlier Session Average Range
AND
Directional progress declining
AND
Volume or tick volume declining, if available
```

---

# 20. News and Event Context / 新聞與事件背景

First implementation uses manual event inputs:

- Event Active
- Event Time
- Event Currency
- Event Impact
- Expected Direction or Narrative
- Event Window Before
- Event Window After

Initial reaction:

```text
Reaction Direction = sign(Post-News Close - Pre-News Close)
Reaction Distance = abs(Post-News Close - Pre-News Close)
Normalised Reaction = Reaction Distance / ATR
```

News follow-through:

```text
Initial reaction direction remains intact
AND
subsequent closes continue in same direction
AND
price remains beyond pre-news reference
```

News fade:

```text
Fade Distance = abs(Current Price - Reaction Extreme)
Initial Reaction Distance = abs(Reaction Extreme - Pre-News Price)
Fade Ratio = Fade Distance / Initial Reaction Distance
```

Price/news divergence:

```text
Divergence = Expected Direction != Observed Reaction Direction
```

---

# 21. State Transition Engine / 狀態轉換

Required transitions:

- Consolidation → Breakout Attempt
- Breakout Attempt → Confirmed Breakout
- Breakout Attempt → Failed Breakout
- Confirmed Breakout → Continuation
- Continuation → Slowing
- Slowing → Exhaustion Candidate
- Exhaustion Candidate → Reversal
- Exhaustion Candidate → Trend Resumption
- Breakout → Retest
- Retest → Hold
- Retest → Fail
- Trend → Messy
- Messy → Consolidation
- Transition → Trend

Every transition record must contain previous state, new state, time, price, triggering evidence, relevant level and timeframe.

---

# 22. Decision Checkpoints / 決策檢查點

Required checkpoint triggers:

- Session Change
- Approach to Important Level
- Level Break
- Breakout Candidate
- Second-Bar Follow-Through Result
- Failed Breakout
- Retest Start
- Retest Hold / Fail
- Bearish Engulfing
- Bullish Engulfing
- Strong Rejection
- Momentum Acceleration
- Momentum Slowing
- Exhaustion Candidate
- Regime Change
- News Window Start
- Post-News Follow-Through or Fade

Each checkpoint must include timestamp, symbol, timeframe, checkpoint type, regime, structure, momentum, candle evidence, relevant levels, breakout state, session, news context and intermediate scores.

---

# 23. Output and Debug Table / 輸出與除錯表格

The table must show at least:

- Current Regime
- Trend Score
- Consolidation Score
- Messy Score
- M5 / M15 / M30 / H1 Structure
- Alignment Score
- Momentum State
- Efficiency Ratio
- Average Overlap Ratio
- Direction Change Ratio
- Current Candle Pattern
- Breakout State
- Breakout Level and Source
- Breakout Quality Score
- Follow-Through Result
- Nearest Manual Level
- Previous Day High / Low
- Previous Session High / Low
- Consolidation High / Low
- VAH / VAL / POC
- Current Session
- News State

No classification should appear without supporting numbers.

---

# 24. Visual Output / 圖表顯示

The chart may display:

- Manual SR lines
- Manual Fib levels
- Previous Day High / Low
- Previous Session High / Low
- Confirmed Swing High / Low
- Consolidation Boundary
- Active Breakout Level
- Retest Zone
- Candle Pattern Labels
- Breakout Lifecycle Labels
- State Transition Labels

Visual objects must have an object limit and cleanup process.

---

# 25. Alert Output / 警報輸出

Alerts should be created only for checkpoints, not every candle.

Suggested JSON:

```json
{
  "event": "BREAKOUT_FOLLOW_THROUGH",
  "symbol": "AUDCHF",
  "chart_timeframe": "5",
  "timestamp": "2026-07-20T08:30:00+01:00",
  "session": "LONDON_OPEN",
  "regime": "BREAKOUT_ATTEMPT",
  "structure": {
    "m5": "BULLISH",
    "m15": "BULLISH",
    "m30": "NEUTRAL",
    "h1": "BEARISH"
  },
  "momentum": "ACCELERATING",
  "breakout": {
    "level": 0.56653,
    "level_type": "CONSOLIDATION_HIGH",
    "state": "STRONG_FOLLOW_THROUGH",
    "quality_score": 0.78
  },
  "candle": {
    "body_ratio": 0.68,
    "close_location": 0.86,
    "range_expansion_ratio": 1.42
  }
}
```

Every field must have a defined source.

---

# 26. Repainting and Confirmation Rules / 重畫與確認規則

The script must:

- Use confirmed bars for alerts unless an intrabar preview is clearly labelled.
- Distinguish preview state from confirmed state.
- Publish swing levels only after right-side confirmation.
- Avoid changing historical state labels after confirmation.
- Freeze active consolidation boundaries during breakout evaluation.

---

# 27. Validation Method / 驗證方法

Use TradingView Bar Replay and manual comparison.

For each historical example, record:

- What the user saw manually
- What Pine classified
- Which intermediate values caused the classification
- Whether the result was correct, partially correct, incorrect, too early, too late, or technically correct but not useful

Required validation categories:

- Healthy trend
- Messy trend-like movement
- Clear consolidation
- Loose consolidation
- Genuine breakout
- Fake breakout
- Second-bar follow-through
- Breakout with no follow-through
- Successful retest
- Failed retest
- Momentum slowing
- Exhaustion candidate
- Actual reversal
- News follow-through
- News fade
- Price / news divergence

---

# 28. Success Criteria / 成功標準

Compilation is necessary but not sufficient.

Technical success:

- No compile errors
- No uncontrolled repainting
- No duplicate checkpoint alerts
- State transitions work correctly
- Debug values are visible
- Multi-timeframe data are consistent

Analytical success:

```text
The script identifies observable evidence
that corresponds meaningfully with
the user's manual chart reading.
```

The initial goal is not:

```text
Replicate manual profit / 完全複製人手盈利
```

The initial goal is:

```text
Measure how much of the user's manual market interpretation
can be represented reliably through Pine-calculated evidence.
```

---

# 29. Known Open Questions / 尚未確定事項

The following remain configurable until tested:

- Best swing confirmation length
- Best consolidation lookback
- Best consolidation equation
- Required overlap threshold
- Required efficiency threshold
- Breakout buffer method
- Minimum breakout candle quality
- Number of follow-through bars
- Retest tolerance
- Regime score weights
- Momentum classification thresholds
- How VAH / VAL should be sourced
- Which timeframe should control each state

These are experimental parameters, not established facts.

---

# 30. Implementation Order / 實作次序

Final deliverable remains one integrated Pine Script.

Recommended order:

1. Common candle calculations
2. Multi-timeframe confirmed data
3. Manual levels and price distance
4. Previous high / low
5. Candle behaviour
6. Swing structure
7. Consolidation evidence and boundaries
8. Breakout lifecycle
9. Momentum classification
10. Market regime scores
11. Session context
12. Manual news context
13. State transitions
14. Debug table
15. Alerts and JSON output
16. Bar Replay validation

Each section must compile and display debug evidence before the next dependent section is considered complete.

---

# 31. Final Design Principle / 最終設計原則

No module is complete merely because it produces a label.

Every meaningful output must answer:

- What does this classification mean?
- Which data were used?
- What equation or rule produced it?
- Which threshold affected it?
- What would invalidate it?
- Can the user inspect the evidence?
- Does it match manual chart interpretation?

The Pine Script is an experimental market-observation and evidence engine.

呢個Pine Script係一個實驗性市場觀察及證據引擎。

It is not yet assumed to be a complete replacement for discretionary trading judgment.

目前唔假設佢可以完整取代人手交易判斷。
