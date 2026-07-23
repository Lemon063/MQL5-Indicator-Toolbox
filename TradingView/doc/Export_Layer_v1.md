# Export Layer v1

File: `Alterf_Manual_Trade_Analyzer_v0_2.pine`

Export Layer v1 adds two export surfaces:

- Realtime alert JSON: one snapshot per confirmed realtime bar via `alert(jsonOutput, alert.freq_once_per_bar_close)`.
- Historical chart export: hidden numerical `plot(..., display=display.none)` columns for TradingView Export Chart Data.

The Export Layer changes are intended to avoid modifying trading logic, breakout lifecycle, interpretation rules, confidence calculations, labels, tables, and visible UI.

## Realtime JSON Schema

The realtime payload uses `schema_version = "export_layer_v1"` and `indicator_version = "Alterf_Manual_Trade_Analyzer_v0_2"`.

Top-level fields:

- `schema_version`
- `indicator_version`
- `event`
- `primary_event`
- `secondary_events`
- `checkpoint_event`
- `symbol`
- `exchange`
- `timeframe`
- `chart_timeframe`
- `bar_index`
- `bar_time`
- `confirmed`
- `timestamp`
- `ohlcv`
- `interpretation`
- `evidence`
- `raw_candle_evidence`
- `context_flags`
- `session_context`
- `breakout_attempt_id`
- `breakout_bar_index`
- `breakout_bar_time`
- `bar_offset_from_breakout`
- `transition_occurred_this_bar`
- `follow_through_evaluated_this_bar`
- `lifecycle_reset_pending`
- `session`
- `regime`
- `structure`
- `momentum`
- `enum_codes`
- `breakout`
- `candle`
- `scores`
- `levels`
- `transition`
- `news`

Nested content:

- `ohlcv`: open, high, low, close, volume.
- `candle`: body size, body ratio, body expansion ratio, range, range expansion ratio, upper/lower wick size, upper/lower wick ratio, close location, ATR, ATR-normalised range.
- `raw_candle_evidence`: expansion, bullish/bearish engulfing, bullish/bearish rejection, inside bar, outside bar, doji, small body, weak close, strong close.
- `context_flags`: manual/previous-day/previous-session/consolidation/value-area proximity, breakout lifecycle context, expansion/failed-push context, MTF alignment, progress acceleration/decline, range expansion/contraction, close-quality changes, session phase flags, important-level flag, decision-checkpoint flag.
- `structure`: M5, M15, M30, H1 previous confirmed OHLCV, time, trend/direction, range, ATR, swing high/low, efficiency, bullish/bearish close ratios.
- `session_context`: session phase/name, minutes from start, session open/high/low, range ATR, net progress ATR, efficiency, direction, sweeps, Asian/London context, post-London momentum decline.
- `levels`: enabled manual levels, manual fibs, nearest manual level, nearest selected level, previous day, previous session, consolidation, value area.
- `breakout`: state, attempt id, level/source/direction, breakout high/low, candidate flags, follow-through result, failed/expired flags, creation time, age, outside closes, quality scores.
- `interpretation`: current name, direction, rule status, confidence, created/updated time and bar index, changed-this-bar flag.
- `evidence`: support reasons 1-3, contradiction reasons 1-3, missing evidence 1-2.
- `scores`: all calculated score components currently available in the script, including trend/consolidation/messy, MTF conflict/alignment, breakout quality components, evidence counts, important-level context, candidate confidence, and current confidence.
- `events`: represented by `primary_event`, `secondary_events`, and `checkpoint_event`.
- `enum_codes`: numeric codes for string states.

`na` numerical values are emitted as JSON `null`. String values are emitted through `f_jsonString()` so quotes, backslashes, and line breaks do not break JSON validity.

## Hidden Historical Export Columns

The script exposes 44 hidden plot columns:

- `export_open`
- `export_high`
- `export_low`
- `export_close`
- `export_volume`
- `export_atr`
- `export_body_ratio`
- `export_body_expansion_ratio`
- `export_range_expansion_ratio`
- `export_close_location`
- `export_atr_normalised_range`
- `export_nearest_manual_distance_atr`
- `export_score_trend`
- `export_score_structure`
- `export_score_efficiency`
- `export_score_alignment_signed`
- `export_score_timeframe_conflict`
- `export_score_directional_close`
- `export_score_consolidation`
- `export_score_low_efficiency`
- `export_score_high_overlap`
- `export_score_contained_range`
- `export_score_direction_change`
- `export_score_messy`
- `export_score_alternating_expansion`
- `export_score_failed_break`
- `export_score_breakout_quality`
- `export_score_body_quality`
- `export_score_close_quality`
- `export_score_break_distance_quality`
- `export_score_expansion_quality`
- `export_score_opposite_wick_penalty`
- `export_support_evidence_count`
- `export_contradiction_evidence_count`
- `export_confidence`
- `export_enum_breakout_state`
- `export_enum_interpretation`
- `export_enum_market_regime`
- `export_enum_momentum_state`
- `export_enum_session_phase`
- `export_mtf_m5_trend`
- `export_mtf_m15_trend`
- `export_mtf_m30_trend`
- `export_mtf_h1_trend`

This hidden plot set does not include every realtime JSON numeric value. It stays within TradingView's 64-output plot budget while preserving the most important historical reconstruction columns.

Realtime JSON score fields not exposed as hidden chart-export plots:

- `breakout_quality_raw`
- `active_breakout_quality`
- `important_level_context`
- `candidate_confidence_raw`
- `interpretation_candidate_confidence`

Realtime JSON numeric fields not exposed as hidden chart-export plots:

- Candle fields reconstructable from exported OHLC where needed: `body_size`, `range`, `upper_wick`, `lower_wick`, `upper_wick_ratio`, `lower_wick_ratio`.
- Session fields: `minutes_from_start`, `session_open`, `session_high`, `session_low`, `range_atr`, `net_progress_atr`, `efficiency`.
- Level fields: raw nearest manual level, raw nearest manual distance, nearest selected level, nearest selected distance, previous day/session levels, consolidation levels, value-area levels.
- MTF fields beyond trend: M5/M15/M30/H1 confirmed OHLCV, time, range, ATR, swing high/low, efficiency, bullish/bearish close ratios.
- Breakout fields: attempt id, breakout bar/time, bar offset, active breakout level, breakout high/low, age bars, consecutive outside closes.
- Interpretation timestamps/bar indexes and transition timestamps/prices.

`export_score_alignment_abs` is reconstructable as `abs(export_score_alignment_signed)`. Fields listed above remain realtime JSON only unless visible plots are removed or TradingView's output budget is otherwise freed.

## Enum Definitions

Direction:

- `-1` = `BEARISH`
- `0` = `NEUTRAL`
- `1` = `BULLISH`
- `99` = `UNRESOLVED` or unknown

Breakout state:

- `0` = `IDLE`
- `1` = `LEVEL_APPROACH`
- `2` = `LEVEL_BREAK`
- `3` = `WAITING_FOR_FOLLOW_THROUGH`
- `4` = `CONFIRMED_BREAKOUT`
- `5` = `FAILED_BREAKOUT`
- `6` = `WAITING_FOR_RETEST`
- `7` = `RETEST_IN_PROGRESS`
- `8` = `RETEST_HOLD`
- `9` = `RETEST_FAIL`
- `10` = `EXPIRED`
- `99` = unknown

Interpretation:

- `0` = `NO_CLEAR_INTERPRETATION`
- `1` = `HEALTHY_CONTINUATION`
- `2` = `MESSY_CONTINUATION`
- `3` = `BREAKOUT_WITH_STRONG_FOLLOW_THROUGH`
- `4` = `BREAKOUT_WITH_WEAK_FOLLOW_THROUGH`
- `5` = `FAILED_BREAKOUT`
- `6` = `RETEST_HOLDING`
- `7` = `RETEST_FAILING`
- `8` = `PULLBACK_ORDERLY`
- `9` = `PULLBACK_MESSY`
- `10` = `MOMENTUM_ACCELERATION`
- `11` = `MOMENTUM_SLOWING`
- `12` = `MOMENTUM_EXHAUSTION_CANDIDATE`
- `13` = `SECOND_PUSH_ATTEMPT`
- `14` = `FAILED_CONTINUATION`
- `15` = `CONFLICTING_EVIDENCE`
- `16` = `INSUFFICIENT_EVIDENCE`
- `17` = `RULE_NOT_DEFINED`
- `99` = unknown

Market regime:

- `1` = `TREND`
- `2` = `CONSOLIDATION`
- `3` = `BREAKOUT_ATTEMPT`
- `4` = `MESSY`
- `5` = `TRANSITION_UNRESOLVED`
- `99` = unknown

Momentum state:

- `0` = `UNRESOLVED`
- `1` = `ACCELERATING`
- `2` = `HEALTHY_CONTINUATION`
- `3` = `SLOWING`
- `4` = `EXHAUSTION_CANDIDATE`
- `5` = `REVERSING`
- `99` = unknown

Session phase:

- `0` = `OUT_OF_DEFINED_SESSIONS`
- `1` = `PRE_LONDON`
- `2` = `LONDON_OPEN`
- `3` = `LONDON_MID`
- `4` = `LONDON_LATE`
- `5` = `LONDON_NEW_YORK_OVERLAP`
- `6` = `NEW_YORK_OPEN`
- `7` = `NEW_YORK_SESSION`
- `8` = `POST_LONDON_CLOSE_DECLINE`
- `9` = `ASIAN_OVERNIGHT`
- `99` = unknown

Profile status:

- `1` = `IMPLEMENTED`
- `2` = `PARTIALLY_IMPLEMENTED`
- `3` = `PLACEHOLDER`
- `4` = `NOT_POSSIBLE_IN_PINE`
- `99` = unknown

## Realtime-Only Fields

TradingView chart export can only export numeric plot series. These fields are realtime JSON only:

- Strings: symbol, exchange, timeframe, state names, interpretation names, evidence reason text, event names, level source names, news strings.
- Arrays and nested objects: support/contradiction/missing evidence arrays and nested JSON groups.
- Boolean flags unless represented by a dedicated numeric plot. Most booleans remain realtime JSON only to preserve plot budget.
- Millisecond timestamps not selected for hidden plots.
- Additional numerical details listed above because the script already uses visible outputs and TradingView enforces a 64-output budget.
