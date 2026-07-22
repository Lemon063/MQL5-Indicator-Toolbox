# Alterf Manual Trade Analyzer v0.2 Implementation Report

## Status

This remains a TradingView `indicator()`, not a `strategy()`.

Version v0.2 is a Trading Logic Validation Layer. Its purpose is to make the existing market observation logic visible, explainable, and manually verifiable in TradingView Bar Replay. It does not prove that the script observes the market the same way as the trader. That still requires manual Bar Replay comparison against historical discretionary decisions.

## Core Design Change

v0.1 displayed raw candle patterns as prominent chart labels and also allowed raw candle events to appear inside the alert checkpoint priority chain.

v0.2 separates:

1. Raw Candle Evidence
2. Contextual Evidence
3. Trading Interpretation
4. Decision Event / State Change

Raw candle evidence is no longer treated as equal to decision events. Bearish engulfing, bullish engulfing, rejection, expansion, weak close, strong close, inside bar, outside bar, doji-like hesitation, and small-body hesitation are recorded as raw evidence fields. They become visible Priority 2 markers only when context filtering allows them.

## Preserved v0.1 Logic

The v0.1 implementation was copied into `Alterf_Manual_Trade_Analyzer_v0_2.pine` and then extended. The v0.1 Pine file was not overwritten.

Preserved systems include:

- `indicator()`, not `strategy()`
- confirmed MTF M5/M15/M30/H1 evidence through `request.security(..., lookahead=barmerge.lookahead_off)`
- manual support/resistance inputs
- manual Fibonacci inputs
- previous day levels
- previous session levels
- consolidation detection and frozen boundaries
- breakout level selection
- breakout lifecycle states
- `breakoutAttemptId`
- immediate second-bar follow-through timing
- `EXPIRED -> IDLE` lifecycle reset
- latest transition record fields
- market regime calculations
- momentum calculations
- session detection
- manual news context
- Alert JSON capability
- confirmed-bar alert option
- non-repainting confirmed MTF data rules

## Original Logic Changes

### Candle label behaviour

Previous behaviour: raw candle patterns could print full pattern labels by default.

New behaviour: raw candle evidence is hidden by default in clean mode and appears only as compact Priority 2 abbreviations in validation/debug views when context filtering allows it, or when `Show All Raw Evidence` is enabled.

Reason: v0.2 prioritises decision events and interpretation changes over raw candle pattern names.

Potential Bar Replay effect: historical bars become less visually noisy; raw pattern evidence must be inspected through tooltips, the panel, or JSON.

### Checkpoint priority

Previous behaviour: raw candle events such as `BULLISH_ENGULFING`, `BEARISH_ENGULFING`, and `STRONG_REJECTION` could appear directly in the checkpoint chain.

New behaviour: raw candle checkpoint alerts are disabled by default and require `Alert Contextual Candle Evidence` plus context filtering. Breakout lifecycle events and material interpretation changes now outrank raw candle evidence.

Reason: a raw candle event must not hide a failed breakout, follow-through result, retest event, or material interpretation change occurring on the same bar.

Potential Bar Replay effect: alert records focus on lifecycle and interpretation events first; raw candle evidence appears as supporting/contradicting evidence.

## Visual Priority Design

### Priority 1 - Decision events

Full text labels are reserved for:

- `BO` breakout
- `FT` follow-through result
- `FB` failed breakout
- `RT` retest start
- `RH` retest hold
- `RF` retest fail
- `ME` momentum exhaustion candidate
- `MS` momentum slowing
- `MA` momentum acceleration
- `HC` healthy continuation
- `MC` messy continuation
- `FC` failed continuation
- `TC` trading interpretation changed

Priority 1 labels only appear when the event first occurs or the interpretation materially changes.

### Priority 2 - Contextual evidence markers

Compact markers are used:

- `E` expansion
- `BE` bearish engulfing
- `UE` bullish engulfing
- `BR` bearish rejection
- `UR` bullish rejection
- `W` weak close
- `S` strong close
- `I` inside bar
- `O` outside bar
- `D` doji / hesitation
- `H` small-body hesitation

These markers are shown only when at least one of the following is true:

- near an important level
- inside an active breakout lifecycle
- at a decision checkpoint
- interpretation changed on the current bar
- momentum state changed
- `Show All Raw Evidence` is enabled

Each marker has a tooltip using current calculated values such as body ratio, range expansion ratio, body expansion ratio, close location, ATR-normalised range, level context, breakout lifecycle activity, and interpretation effect.

### Priority 3 - Hidden raw evidence

Raw measurements are exposed in tooltip text, the validation/debug table, and Alert JSON. They do not create large chart labels by default.

## Display Modes

Default: `VALIDATION_VIEW`.

### CLEAN_TRADING_VIEW

Shows important levels, active breakout level, Priority 1 events, and the compact current interpretation panel. Raw candle markers are hidden.

### VALIDATION_VIEW

Shows Priority 1 events, context-filtered Priority 2 markers, compact reasoning table, latest transition, current interpretation, and selected supporting/contradicting/missing evidence.

### FULL_DEBUG_VIEW

Shows all evidence markers allowed by filters, full debug table, transition details, calculations, scores, raw candle measurements, and internal state fields.

## Interpretation Rules Implemented

The interpretation engine currently implements rules for:

- `NO_CLEAR_INTERPRETATION`
- `HEALTHY_CONTINUATION`
- `MESSY_CONTINUATION`
- `BREAKOUT_WITH_STRONG_FOLLOW_THROUGH`
- `BREAKOUT_WITH_WEAK_FOLLOW_THROUGH`
- `FAILED_BREAKOUT`
- `RETEST_HOLDING`
- `RETEST_FAILING`
- `PULLBACK_ORDERLY`
- `PULLBACK_MESSY`
- `MOMENTUM_ACCELERATION`
- `MOMENTUM_SLOWING`
- `MOMENTUM_EXHAUSTION_CANDIDATE`
- `SECOND_PUSH_ATTEMPT`
- `FAILED_CONTINUATION`
- `CONFLICTING_EVIDENCE`
- `INSUFFICIENT_EVIDENCE`

Each interpretation records:

- name
- direction
- rule status
- confidence
- supporting evidence
- contradicting evidence
- missing evidence
- creation time
- creation bar index
- latest update time
- latest update bar index

## Interpretation Rules With Conservative Definitions

The following rules are implemented with explicit, conservative definitions using existing inputs and measurements:

- `PULLBACK_ORDERLY`: local structure direction exists, pullback ratio is below `Deep Pullback Ratio`, range is contracting, and no strong opposite rejection is present.
- `PULLBACK_MESSY`: local structure direction exists, pullback is deep or disorderly, and weak close / range expansion / MTF conflict is present.
- `SECOND_PUSH_ATTEMPT`: prior failed-push evidence exists and current directional progress accelerates in the local structure direction.
- `FAILED_CONTINUATION`: prior healthy continuation or momentum acceleration is followed by declining progress plus weak close, opposite rejection, or MTF conflict.

These are validation candidates only. They do not create automated trade commands.

## Rule Not Defined / Insufficient Evidence

`RULE_NOT_DEFINED` is now exposed as `interpretation.rule_status` when no implemented rule fits the current evidence combination.

`UNRESOLVED_SECOND_BAR` is no longer forced into `BREAKOUT_WITH_WEAK_FOLLOW_THROUGH`; it becomes `INSUFFICIENT_EVIDENCE` with `RULE_NOT_DEFINED` status until Bar Replay review defines a clearer interpretation.

## Evidence Selection Priority

Supporting evidence is selected in this order:

1. active breakout lifecycle or momentum state
2. second-bar follow-through / important level proximity / progress acceleration / close quality improvement
3. strong close / expansion / range expansion / session open context

Contradicting evidence is selected in this order:

1. against MTF direction or high MTF conflict
2. progress declining / close quality weakening / weak close
3. range contraction / opposite rejection / messy regime

Missing evidence is selected in this order:

1. no important level proximity or unresolved MTF direction
2. missing breakout lifecycle for breakout-specific interpretations, or undefined rule combination

The engine deliberately does not list every true Boolean.

## New Thresholds And Weights

All new thresholds/weights are Pine inputs:

- `Minimum Interpretation Confidence Change`
- `Base Interpretation Confidence`
- `Supporting Evidence Weight`
- `Contradiction Evidence Weight`
- `Breakout Interpretation Weight`
- `Momentum Interpretation Weight`
- `Context Evidence Weight`
- `Conflict Evidence Count Threshold`
- `MTF Conflict Contradiction Threshold`

No new unexplained hard-coded trading threshold was intentionally introduced. Existing v0.1 thresholds remain inputs.

## Session Context

Session data is contextual evidence only unless a future explicit rule uses it. London Open is not treated as bullish, reliable, or confirmatory by default.

New session context fields include:

- `session_phase`
- `minutes_from_session_start`
- `session_open`
- `session_high`
- `session_low`
- `session_range_atr`
- `session_net_progress_atr`
- `session_efficiency`
- `session_direction`
- `session_high_swept`
- `session_low_swept`
- `overnight_consolidation`
- `london_breaks_asian_high`
- `london_breaks_asian_low`
- `post_london_momentum_decline`

## Alert JSON Changes

The original JSON output is preserved and extended.

Added blocks:

- `primary_event`
- `secondary_events`
- `interpretation`, including `rule_status`
- `evidence.supporting`
- `evidence.contradicting`
- `evidence.missing`
- `raw_candle_evidence`
- `session_context`

`session_context` now includes `session_open`, `session_high`, and `session_low` in addition to phase, minutes from start, ATR-normalised range/progress, efficiency, direction, sweeps, Asian high/low breaks, and post-London momentum decline.

Default alert priority now favours:

1. breakout lifecycle events
2. material interpretation changes
3. momentum interpretation changes
4. regime interpretation changes
5. news events
6. session changes
7. contextual candle evidence only when explicitly enabled

## Validation Inputs

Added Bar Replay annotation inputs:

- `Validation Case ID`
- `Manual Expected Interpretation`
- `Manual Expected Direction`
- `Manual Notes`
- `Show Validation Comparison`

The comparison is exact-match only. If text differs, the panel reports `MISMATCH`; if no manual expectation is supplied, it reports `NOT_ASSESSED`.

## Pine Platform Limitations

- Pine cannot store unrestricted dynamic objects; v0.2 uses fixed reason fields.
- Tooltips and tables are constrained by TradingView object limits.
- Manual expected interpretation inputs cannot vary automatically bar by bar.
- TradingView compile must be performed in TradingView. Static local audit does not replace official TradingView compilation.
- String escaping in alert JSON should be kept simple; current generated reasons avoid embedded quote characters.

## Compile Status

TradingView official compile has not been completed in this environment. The file has received a static source audit only.

## Final Status

v0.2 is a testable Trading Logic Validation Layer that still requires manual Bar Replay comparison against the trader's own historical decisions.
