# Alterf Manual Trade Analyzer v0.1 Implementation Report
# Alterf 人手交易分析器 v0.1 實作報告

## Files

- Pine Script: `/Users/avislai/Documents/Codex/Toolbox/TradingView/Alterf_Manual_Trade_Analyzer_v0_1.pine`
- Implementation report: `/Users/avislai/Documents/Codex/Toolbox/TradingView/Alterf_Manual_Trade_Analyzer_v0_1_IMPLEMENTATION_REPORT.md`
- Validation checklist: `/Users/avislai/Documents/Codex/Toolbox/TradingView/Alterf_Manual_Trade_Analyzer_v0_1_VALIDATION_CHECKLIST.md`

## Pre-Implementation Checks

- Spec exists: IMPLEMENTED. Read from `/Users/avislai/Documents/Codex/Alterf-MT5/docs/spec/Alterf_TradingView_Manual_Trade_Reconstruction_Spec_v0.4.md`.
- Target folder exists: IMPLEMENTED. `/Users/avislai/Documents/Codex/Toolbox/TradingView`.
- Script type: IMPLEMENTED. Uses `indicator(...)`, not `strategy(...)`.
- One-file architecture: IMPLEMENTED. All modules are logical sections inside one Pine file.
- Official compile status: PARTIALLY_IMPLEMENTED. This environment has no TradingView Pine compiler or TradingView app automation available, so official compile must be verified inside TradingView Pine Editor. Local static checks were run for file presence, line count, `indicator()`/`strategy()` usage, alert/table/security calls, and obvious string `nz()` risk.

## Implementation Status

Important correction after strict review: this deliverable should be treated as a testable v0.1 skeleton/evidence engine, not a complete analytical implementation of every requirement in the specification. The code now exposes more evidence and avoids several hidden assumptions, but Bar Replay validation is still required before any module should be considered analytically reliable.

### IMPLEMENTED

- Common candle calculations:
  - Range, Body, Upper Wick, Lower Wick
  - Body Ratio, Upper Wick Ratio, Lower Wick Ratio
  - Close Location
  - Bullish/Bearish Progress
  - Safe division and clamping helpers
- Multi-timeframe confirmed evidence:
  - M5, M15, M30, H1 via `request.security()`
  - Uses prior completed higher-timeframe values in the MTF function
  - Per-timeframe confirmed Open, High, Low, Close, Volume, Time
  - Per-timeframe structure direction, latest swing high/low, efficiency ratio, bullish/bearish directional close ratio
- Manual SR:
  - Resistance 1-3 and Support 1-3
  - Individual enable toggles
  - Signed/absolute/ATR-normalised distance helpers
  - Nearest manual level source and distance
- Manual Fibonacci:
  - Manual Anchor A, Anchor B, direction
  - 38.2%, 50.0%, 61.8% levels
  - No automatic swing selection
- Manual VAH/VAL/POC:
  - Manual VAH, Manual VAL, Manual POC
  - Display and debug table evidence
- Previous High/Low:
  - Previous Day High/Low through daily confirmed values
  - Previous London and New York session high/low captured from session boundaries
  - Current previous-session high/low context
- Confirmed swings:
  - `ta.pivothigh()` / `ta.pivotlow()` with left/right confirmation
  - Output delayed by right bars
  - Local structure classification from latest/previous confirmed swings
- Consolidation:
  - Window High/Low/Range
  - Normalised Window Range
  - Net Progress, Total Path, Efficiency Ratio
  - Average Overlap Ratio
  - Direction Change Ratio
  - Consolidation Candidate
  - Frozen consolidation high/low during breakout lifecycle
- Candle Behaviour:
  - Bullish/Bearish Engulfing
  - Bullish/Bearish Rejection
  - Long Upper/Lower Wick
  - Doji-like Hesitation
  - Small-body Hesitation
  - Inside Bar / Outside Bar
  - Consecutive Directional Closes
  - Consecutive Bullish/Bearish Bodies
  - Expansion Candle
  - Weak Close
- Breakout lifecycle:
  - State machine includes IDLE, LEVEL_APPROACH, LEVEL_BREAK, WAITING_FOR_FOLLOW_THROUGH, CONFIRMED_BREAKOUT, FAILED_BREAKOUT, WAITING_FOR_RETEST, RETEST_IN_PROGRESS, RETEST_HOLD, RETEST_FAIL, EXPIRED
  - `BREAKOUT_CANDIDATE` is not used as a live state in v0.1; candidate is stored as `activeBreakoutCandidateQualified` on the breakout bar
  - Active level price, source, direction, creation bar/time, age
  - Level approach, level break, wick break, break distance, normalised break distance
  - Breakout quality components: body, close, distance, expansion, opposite wick penalty
  - State machine is restricted to one transition per bar so `LEVEL_BREAK` and `CONFIRMED_BREAKOUT` are observable checkpoints
  - Breakout lifecycle state/count updates are gated to confirmed bars
  - `EXPIRED` is retained for one confirmed bar, then the next confirmed bar resets the lifecycle to `IDLE` with trigger `LIFECYCLE_RESET`
  - Runtime reset clears the active breakout level/source/direction/creation time, breakout bar index/time, age/offset, consecutive outside closes, follow-through result, candidate flags, and active consolidation snapshot without deleting the latest completed transition record
  - Breakout bar = bar 1. The immediate next completed bar, `bar_index == breakoutBarIndex + 1`, is the second-bar follow-through evaluation bar
  - Candidate qualification is retained as a breakout-bar classification flag; it no longer delays follow-through evaluation to the third bar
  - Strong/weak second-bar follow-through can only confirm or continue a qualified candidate; non-candidate breaks move to waiting/failure handling instead of direct strong/weak confirmation
  - Route B requires consecutive outside closes, not only the final outside close
  - Every new breakout attempt increments `breakoutAttemptId` and resets follow-through result/evaluation flags
  - Follow-through checkpoint detection is attempt-aware, so two separate attempts with the same result string can both alert
  - Follow-through result: strong, weak, no follow-through, immediate failure
  - Failed-break ratio
  - Retest zone, retest hold, retest fail
- Momentum:
  - Directional Progress
  - Range Expansion Ratio
  - Body Expansion Ratio
  - Pullback Ratio
  - Opposite Wick
  - Follow-through evidence
  - Important Level Context
  - States: ACCELERATING, HEALTHY_CONTINUATION, SLOWING, EXHAUSTION_CANDIDATE, REVERSING, UNRESOLVED
- Market Regime:
  - Trend Score with components
  - Consolidation Score with components
  - Messy Score with components
  - Breakout Attempt override when lifecycle is active
  - Transition/Unresolved fallback
- Session Context:
  - Asian/Overnight, Pre-London, London Open, London Mid, London Late, New York Open, New York session, London/New York Overlap, Post-London/Close Decline
  - Session range, net progress, efficiency
  - Overnight consolidation evidence
  - Close momentum decline evidence
- Manual News Context:
  - Event Active, Event Time, Currency, Impact, Expected Direction, Before/After windows
  - Pre-news, release, post-news states
  - Initial reaction direction, reaction distance, normalised reaction
  - Follow-through, fade ratio, divergence, divergence persistence
- State Transition:
  - Records latest transition previous state, new state, time, price, triggering evidence, relevant level, and timeframe through labels/debug evidence
  - Latest transition fields update only when a real transition occurs; no-transition bars do not overwrite the record
- Debug Table:
  - Current Regime, scores and components
  - M5/M15/M30/H1 confirmed OHLCV and structure evidence
  - Momentum State
  - Efficiency, overlap, direction change
  - Candle pattern and equation values
  - Breakout state, level/source/quality/follow-through
  - Breakout Attempt ID, Breakout Bar Index/Time, bar offset from breakout, transition occurred this bar, latest transition previous/new/trigger/time, follow-through evaluated this bar, consecutive outside close count, lifecycle reset pending
  - Manual levels, previous levels, consolidation, VAH/VAL/POC, session, news
- Alerts:
  - Checkpoint-only `alert()` calls
  - Confirmed-bar-only by default
  - Duplicate alert prevention per bar
  - JSON output with real sourced fields and `null` for unavailable numeric values
  - JSON includes MTF OHLCV/evidence, breakout age/creation/direction/outside-close count, nearest manual level, previous levels, consolidation boundaries, VAH/VAL/POC, and latest transition record
  - JSON includes breakout attempt id, breakout bar index/time, bar offset from breakout, transition occurred this bar, follow-through evaluated this bar, and lifecycle reset pending
  - Alert de-duplication records checkpoint event, breakout attempt id, and bar index
- Visuals:
  - Manual SR, Manual Fib, previous day/session levels
  - Confirmed swings
  - Frozen consolidation boundaries
  - Active breakout level
  - Retest zone
  - Candle, breakout, and transition labels
  - Managed label array cleanup

### PARTIALLY_IMPLEMENTED

- Pine Approximation Mode for VAH/VAL/POC:
  - Inputs exist: profile start/end, bins, value area percentage, lower timeframe, allocation method description.
  - It is explicitly marked `PARTIALLY_IMPLEMENTED`.
  - No fake VAH/VAL/POC values are generated.
  - Reason: a reliable bin allocator with lower-timeframe volume distribution is possible but materially heavier, can hit Pine loop/object/time limits, and would still not match TradingView built-in Volume Profile.
- Session taxonomy:
  - Fine-grained sessions are implemented as configurable session windows.
  - The exact market meaning still depends on user-configured session strings and timezone.
- State transition records:
  - The latest complete transition record is visible in labels/debug/JSON.
  - A full persistent multi-transition log table is not implemented because Pine has limited table/object capacity and no durable external storage.
- News analysis:
  - Manual event windows and reaction math are implemented.
  - Pine cannot fetch or interpret live economic news, so all narrative context remains manual.

### PLACEHOLDER

- None used as fake analytical output.
- The constants include `PLACEHOLDER` and `NOT_POSSIBLE_IN_PINE` status labels for future explicit reporting, but no production classification is filled with dummy values.

### NOT_POSSIBLE_IN_PINE

- Downloading or understanding live news/economic calendar data inside Pine.
- Guaranteeing equivalence with TradingView built-in Volume Profile internals.
- Official Pine compilation outside TradingView's editor/runtime.
- Exporting a durable historical state-transition log to a file directly from Pine.

## Main Equations

- Range = High - Low
- Body = abs(Close - Open)
- Upper Wick = High - max(Open, Close)
- Lower Wick = min(Open, Close) - Low
- Body Ratio = Body / Range
- Upper Wick Ratio = Upper Wick / Range
- Lower Wick Ratio = Lower Wick / Range
- Close Location = (Close - Low) / Range
- Common progress note: the spec contains two progress definitions. Section 4 defines Bullish/Bearish Progress from Close - Open, while Section 14 momentum defines progress from Current Close - Previous Close. v0.1 uses Close-to-Previous-Close for momentum progress because it better matches the momentum classification section. Candle direction still uses Close vs Open.
- ATR-normalised distance = abs(Close - Level) / ATR
- Near Level = abs(Close - Level) <= Level Tolerance
- Consolidation Efficiency = abs(Close - Close[N-1]) / sum(abs(Close - Close[1]), N)
- Overlap Ratio = max(0, min(High, High[1]) - max(Low, Low[1])) / min(Range, Range[1])
- Direction Change Ratio = direction changes / valid comparisons
- Consolidation Candidate = low efficiency + high overlap + contained range + sufficient direction change
- Alignment Score = weighted sum of M5/M15/M30/H1 directions divided by total weight
- Trend Score = weighted structure + efficiency + alignment + directional close score
- Consolidation Score = weighted low efficiency + overlap + contained range + direction change
- Messy Score = weighted direction change + failed break + timeframe conflict + alternating expansion
- Breakout Quality = weighted body + close + distance + expansion - opposite wick penalty
- Second-Bar Follow-Through Bar = the first completed bar after breakout, where `bar_index == breakoutBarIndex + 1`
- Route B Confirmed Breakout = consecutive outside closes >= Follow-Through Bars
- Lifecycle Reset = `EXPIRED` on bar N, then `IDLE` on bar N+1 with transition trigger `LIFECYCLE_RESET`
- Pullback Ratio = pullback distance / impulse distance
- News Reaction Distance = abs(Post-News Close - Pre-News Close)
- Fade Ratio = abs(Current Price - Reaction Extreme) / Initial Reaction Distance

## Important Threshold Inputs

- ATR length
- Structure lookback
- Swing left/right confirmation bars
- Level tolerance ATR
- Breakout buffer ATR
- Approach tolerance ATR
- Retest tolerance ATR
- Break distance full-quality ATR
- Follow-through bars
- Maximum failure bars
- State expiry bars
- Close momentum decline lookback
- Close momentum prior comparison offset
- Consolidation lookback
- Maximum consolidation efficiency
- Minimum overlap threshold
- Maximum window range ATR
- Minimum direction change ratio
- Candle wick/body/close-location thresholds
- Expansion thresholds
- Momentum lookback and progress decay thresholds
- MTF alignment weights
- Trend/consolidation/messy thresholds
- Regime score weights
- Breakout quality weights
- News before/after windows
- News fade ratio threshold
- News divergence persistence bars
- Fine-grained session windows: Pre-London, London Open, London Mid, London Late, New York Open, Post-London

## Repainting Handling

- Alerts default to confirmed bars only.
- MTF metrics use completed higher-timeframe evidence in the MTF calculation.
- Confirmed swings use left/right pivots and are only plotted after right-side confirmation.
- Consolidation high/low are frozen once breakout evaluation starts.
- Label creation occurs on confirmed bars for candle/breakout/transition labels.
- Known residual risk: `request.security()` still depends on chart symbol feed/session definitions and should be checked in Bar Replay, especially when chart timeframe is higher than one of the requested MTFs.

## TradingView Performance / Object Risks

- `request.security()` calls: 6 total, currently acceptable.
- Labels are capped through a managed array of 80 labels.
- `max_lines_count=120`, `max_labels_count=120`, `max_boxes_count=20`.
- Debug table has 32 rows and updates on the last bar only.
- Volume Profile approximation is not fully implemented to avoid heavy nested loops in v0.1.

## Known Limitations

- The script is an evidence engine, not an auto-trading strategy.
- Score thresholds are experimental and must be tuned through Bar Replay.
- Breakout source selection chooses the nearest eligible level, which is debuggable but may not always match the user's discretionary priority.
- Previous session high/low depends on configured session strings and timezone.
- Manual SR/Fib/VAH/VAL/POC require the user to input meaningful prices.
- News context requires manual event input and cannot validate real-world news content.
- JSON timestamp is emitted as TradingView/Pine UNIX millisecond time, not ISO-8601 text.

## First Bar Replay Test Method

1. Load the script on the intended symbol and chart timeframe, preferably M5 for first validation.
2. Set manual SR levels, Fib anchors, VAH/VAL/POC, and session timezone before replay.
3. Enable debug table and only the essential visual layers first.
4. Replay each validation case slowly through the setup, approach, break, follow-through, retest, and failure phases.
5. For every checkpoint alert, record:
   - What the chart looked like manually
   - Which checkpoint fired
   - Breakout state and level source
   - Trend/consolidation/messy scores
   - Candle equation values
   - Momentum state
   - Whether the state was correct, early, late, noisy, or not useful
6. Tune thresholds only after collecting several examples from different regimes.
