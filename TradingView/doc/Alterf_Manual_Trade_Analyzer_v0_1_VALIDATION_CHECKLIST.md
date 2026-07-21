# Alterf Manual Trade Analyzer v0.1 Validation Checklist
# Alterf 人手交易分析器 v0.1 驗證清單

Use this checklist in TradingView Bar Replay. For each case, record the chart, manual interpretation, Pine output, and whether the result is correct, partially correct, incorrect, too early, too late, or technically correct but not useful.

每個 case 都要記錄人手判斷、Pine 分類、中間數值、同結果評價。重點唔係單次準確，而係 Pine 證據可唔可以同人手睇圖作有意義比較。

## Shared Setup

- [ ] Confirm script compiles in TradingView Pine Editor.
- [ ] Confirm it is an `indicator`, not a `strategy`.
- [ ] Set chart timeframe, ideally M5 for first pass.
- [ ] Set session timezone and session strings.
- [ ] Enter Manual Resistance 1-3 and Manual Support 1-3.
- [ ] Enter Fib Anchor A, Fib Anchor B, and Fib Direction.
- [ ] Enter Manual VAH, VAL, POC if relevant.
- [ ] Enable Debug Table.
- [ ] Enable only needed visual layers to avoid clutter.
- [ ] Keep alerts confirmed-bar-only for baseline validation.
- [ ] Record default thresholds before changing them.
- [ ] Confirm debug table shows confirmed OHLCV evidence for M5, M15, M30, and H1.
- [ ] Confirm alert JSON includes MTF OHLCV, levels, breakout metadata, and latest transition record fields.

## Case 1: Healthy Trend

- [ ] Manual observation: clear HH/HL or LH/LL.
- [ ] M5/M15/M30/H1 structures mostly aligned.
- [ ] Trend Score rises above threshold.
- [ ] Consolidation Score remains lower than Trend Score.
- [ ] Messy Score remains low.
- [ ] Momentum State shows `HEALTHY_CONTINUATION` or `ACCELERATING` during strong legs.
- [ ] Debug values to record: Efficiency Ratio, Directional Close Ratio, Alignment Score, Pullback Ratio.
- [ ] Result rating:

## Case 2: Messy Trend-Like Movement

- [ ] Manual observation: price appears directional but whippy or overlapping.
- [ ] Direction Change Ratio increases.
- [ ] Average Overlap Ratio increases.
- [ ] Timeframe Conflict Score increases.
- [ ] Alternating Expansion Score appears during opposite expansion candles.
- [ ] Messy Score competes with or exceeds Trend Score.
- [ ] Debug values to record: Failed Break Ratio, Direction Change Ratio, Timeframe Conflict Score.
- [ ] Result rating:

## Case 3: Clear Consolidation

- [ ] Manual observation: tight range with repeated overlap.
- [ ] Efficiency Ratio below max threshold.
- [ ] Average Overlap Ratio above min threshold.
- [ ] Normalised Window Range below max threshold.
- [ ] Direction Change Ratio above min threshold.
- [ ] Frozen Consolidation High/Low matches window high/low at confirmation.
- [ ] Result rating:

## Case 4: Loose Consolidation

- [ ] Manual observation: broad or imperfect range.
- [ ] Check whether Consolidation Score is partial rather than overconfident.
- [ ] Confirm debug table shows which component blocks/permits consolidation.
- [ ] Confirm boundaries do not keep moving after breakout observation starts.
- [ ] Result rating:

## Case 5: Genuine Breakout

- [ ] Manual observation: price approaches named level, breaks, and accepts outside.
- [ ] Breakout Level Source is not `NONE`.
- [ ] State sequence includes `LEVEL_APPROACH`, `LEVEL_BREAK`, then `CONFIRMED_BREAKOUT`, `WAITING_FOR_FOLLOW_THROUGH`, or `FAILED_BREAKOUT`.
- [ ] Candidate qualification is visible as a breakout-bar classification flag, not as a separate live state/checkpoint.
- [ ] `LEVEL_BREAK` remains visible as its own checkpoint and is not skipped on the same bar.
- [ ] Breakout Quality Score exceeds candidate threshold.
- [ ] Follow-through or several closes outside confirm breakout.
- [ ] Route B confirmation only occurs after consecutive outside closes reach Follow-Through Bars.
- [ ] `CONFIRMED_BREAKOUT` remains visible as its own checkpoint before waiting for retest.
- [ ] Alert JSON fires only at checkpoints.
- [ ] Alert JSON includes breakout direction, creation time, age, source, level, and consecutive outside close count.
- [ ] Result rating:

## Case 6: Fake Breakout

- [ ] Manual observation: price closes outside then quickly returns inside.
- [ ] State becomes `FAILED_BREAKOUT`.
- [ ] Failed Break Ratio increases.
- [ ] Messy Score may increase afterward.
- [ ] Alert JSON event is `FAILED_BREAKOUT`.
- [ ] Result rating:

## Case 7: Second-Bar Follow-Through

- [ ] First breakout candle becomes candidate.
- [ ] Second candle progresses beyond previous close.
- [ ] Second candle remains outside breakout level.
- [ ] Close Location is strong.
- [ ] No strong opposite rejection appears.
- [ ] Follow-Through Result is `STRONG_FOLLOW_THROUGH`.
- [ ] If breakout candle is not a qualified candidate, strong/weak second-bar follow-through must not directly confirm the breakout.
- [ ] Result rating:

## Case 8: No Follow-Through

- [ ] First breakout candle becomes candidate.
- [ ] Next candle does not progress.
- [ ] Price does not meaningfully accept outside level.
- [ ] Follow-Through Result is `NO_FOLLOW_THROUGH` or `WEAK_FOLLOW_THROUGH`.
- [ ] Confirm no repeated duplicate alert on every bar.
- [ ] Result rating:

## Case 9: Successful Retest

- [ ] Confirmed breakout transitions to waiting for retest.
- [ ] Price enters retest zone.
- [ ] Close remains outside or recovers outside breakout level.
- [ ] Directional rejection or continuation evidence appears.
- [ ] State becomes `RETEST_HOLD`.
- [ ] Transition record includes previous state, new state, time, price, trigger, relevant level, and timeframe.
- [ ] Result rating:

## Case 10: Failed Retest

- [ ] Price enters retest zone.
- [ ] Close returns through breakout level.
- [ ] Follow-up price continues inside old range.
- [ ] State becomes `RETEST_FAIL`.
- [ ] Failed Break Ratio increases.
- [ ] Result rating:

## Case 11: Momentum Slowing

- [ ] Manual observation: trend still moves but progress per candle decays.
- [ ] Directional Progress declines.
- [ ] Body size declines.
- [ ] Opposite Wick increases.
- [ ] Progress Decay Ratio falls below threshold.
- [ ] Momentum State becomes `SLOWING`.
- [ ] Result rating:

## Case 12: Exhaustion Candidate

- [ ] Price reaches important level.
- [ ] Range or opposite wick expands.
- [ ] Close fails to remain near directional extreme.
- [ ] Next candle fails to continue.
- [ ] Momentum State becomes `EXHAUSTION_CANDIDATE`.
- [ ] Confirm this is not automatically treated as reversal.
- [ ] Result rating:

## Case 13: Actual Reversal

- [ ] Exhaustion or failed continuation occurs first.
- [ ] Opposite candle evidence appears.
- [ ] Relevant minor structure level breaks.
- [ ] Opposite follow-through appears.
- [ ] Momentum State becomes `REVERSING`.
- [ ] Check whether timing is too late or appropriately conservative.
- [ ] Result rating:

## Case 14: News Follow-Through

- [ ] Enable manual event inputs.
- [ ] Set event time, currency, impact, expected direction.
- [ ] Replay through pre-news window.
- [ ] Initial Reaction Direction is recorded.
- [ ] Reaction Distance and Normalised Reaction update.
- [ ] Subsequent closes continue in same direction.
- [ ] News State becomes `NEWS_FOLLOW_THROUGH`.
- [ ] Alert JSON event is `NEWS_FOLLOW_THROUGH`.
- [ ] Result rating:

## Case 15: News Fade

- [ ] Enable manual event inputs.
- [ ] Initial reaction creates reaction extreme.
- [ ] Price fades away from reaction extreme.
- [ ] Fade Ratio exceeds threshold used by script.
- [ ] News State becomes `NEWS_FADE`.
- [ ] Alert JSON event is `NEWS_FADE`.
- [ ] Result rating:

## Case 16: Price / News Divergence

- [ ] Set Expected Direction to Bullish or Bearish.
- [ ] Observed Reaction Direction is opposite.
- [ ] News Divergence becomes true.
- [ ] Divergence Persistence increases if divergence remains.
- [ ] Confirm this is shown as context evidence, not a trade signal.
- [ ] Result rating:

## Breakout Lifecycle Regression Tests

### Test A: EXPIRED Reset

- [ ] Bar N: state becomes `EXPIRED`.
- [ ] Bar N: `BREAKOUT_EXPIRED` checkpoint can be seen in label/debug/alert.
- [ ] Bar N+1: state becomes `IDLE`.
- [ ] Bar N+1: latest transition previous state is `EXPIRED`.
- [ ] Bar N+1: latest transition new state is `IDLE`.
- [ ] Bar N+1: latest transition trigger is `LIFECYCLE_RESET`.
- [ ] Bar N+1: active breakout level/source/direction/creation time are cleared.
- [ ] Bar N+1: breakout bar index/time, bar offset, consecutive outside close count, and follow-through result are reset.
- [ ] Later bars: a new breakout can start normally.
- [ ] Result rating:

### Test B: True Second-Bar Follow-Through

- [ ] Bar N: breakout occurs.
- [ ] Bar N: state is `LEVEL_BREAK`.
- [ ] Bar N: breakout bar index equals current `bar_index`.
- [ ] Bar N+1: bar offset from breakout equals `1`.
- [ ] Bar N+1: follow-through is evaluated on this bar.
- [ ] Bar N+1: follow-through result is recorded on this bar.
- [ ] Bar N+1: state transitions directly from `LEVEL_BREAK` to `CONFIRMED_BREAKOUT`, `WAITING_FOR_FOLLOW_THROUGH`, or `FAILED_BREAKOUT`.
- [ ] Confirm first follow-through evaluation does not wait until Bar N+2.
- [ ] Result rating:

### Test C: Transition Record Persistence

- [ ] Bar N: a real transition occurs.
- [ ] Record latest transition previous state, new state, time, price, trigger, relevant level, and timeframe.
- [ ] Bar N+1: no transition occurs.
- [ ] Expected: latest transition record remains unchanged.
- [ ] Expected: `transition_occurred_this_bar` is false on Bar N+1.
- [ ] Confirm no `CANDIDATE -> CANDIDATE` or same-state transition appears.
- [ ] Result rating:

### Test D: Repeated Same Follow-Through Result

- [ ] Attempt 1: follow-through result is `WEAK_FOLLOW_THROUGH`.
- [ ] Attempt 1: `SECOND_BAR_FOLLOW_THROUGH_RESULT` alert fires.
- [ ] Let lifecycle complete, fail, or expire/reset.
- [ ] Attempt 2: follow-through result is also `WEAK_FOLLOW_THROUGH`.
- [ ] Attempt 2: `SECOND_BAR_FOLLOW_THROUGH_RESULT` alert also fires.
- [ ] Confirm the second alert is not blocked by the result string matching Attempt 1.
- [ ] Confirm alert JSON has a different `breakout_attempt_id`.
- [ ] Result rating:

## Final Review Questions

- [ ] Which debug values were most useful for matching manual judgment?
- [ ] Which classifications were too early?
- [ ] Which classifications were too late?
- [ ] Which thresholds needed symbol-specific tuning?
- [ ] Did any visual object clutter or object limit warning appear?
- [ ] Did any historical state appear to repaint unexpectedly?
- [ ] Did alert JSON include only sourced fields?
- [ ] Did checkpoint alerts avoid per-bar spam?
- [ ] Which module should be improved first in v0.2?
