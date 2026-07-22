# Alterf Manual Trade Analyzer v0.2 Validation Checklist

Use this checklist in TradingView Bar Replay. The expected status after testing is not "validated logic"; it is whether the script's observations can be compared against the trader's manual interpretation bar by bar.

## Test 1 - Clean view readability

Setup:

- Set `Display Mode` to `CLEAN_TRADING_VIEW`.

Expected:

- Price candles remain visible.
- No large raw-pattern label cloud appears.
- Only major events use full text labels.
- Raw evidence markers do not appear.
- Current interpretation panel remains compact and readable.

Result:

- Pass / Fail:
- Notes:

## Test 2 - Evidence hierarchy

Setup:

- Choose a Bar Replay area with a bearish engulfing candle.
- Set `Display Mode` to `VALIDATION_VIEW`.

Expected:

- Bearish engulfing is recorded as raw candle evidence.
- It may appear as compact `BE` only if context filtering allows it.
- It does not automatically become a reversal.
- Its contextual meaning depends on location, sequence, MTF alignment, momentum, and breakout lifecycle state.
- Tooltip states that it is not treated as an automatic reversal or trade signal.

Result:

- Pass / Fail:
- Notes:

## Test 3 - Priority conflict

Setup:

- Choose a bar where bearish engulfing and breakout failure occur together.

Expected:

- Failed breakout remains the primary event.
- `primary_event` is `FAILED_BREAKOUT`.
- Bearish engulfing appears only as supporting/contextual raw evidence if applicable.
- Raw pattern evidence does not hide the lifecycle event.

Result:

- Pass / Fail:
- Notes:

## Test 4 - Interpretation persistence

Setup:

- Replay several bars after an interpretation is created.

Expected:

- Current interpretation persists across bars.
- It does not recreate itself every bar.
- Created time remains unchanged while the same interpretation persists.
- Updated time changes only for a material update.

Result:

- Pass / Fail:
- Notes:

## Test 5 - Interpretation change

Setup:

- Use an area where confidence or evidence fluctuates slightly.
- Adjust `Minimum Interpretation Confidence Change` if needed.

Expected:

- `interpretationChangedThisBar` is true only when market meaning changes materially.
- Small score fluctuations do not trigger repeated `TC` events.
- Material changes show a reason in the panel.

Result:

- Pass / Fail:
- Notes:

## Test 6 - Supporting and contradicting evidence

Setup:

- Choose a bar with mixed evidence, such as strong location but weakening progress.

Expected:

- Supporting and contradicting evidence can coexist.
- Contradictory evidence does not disappear merely because confidence is high.
- Maximum displayed reasons follow the documented priority order.
- `support_reason_1..3`, `contradiction_reason_1..3`, and `missing_evidence_1..2` appear in the panel/JSON.

Result:

- Pass / Fail:
- Notes:

## Test 7 - Session as context

Setup:

- Replay through London Open and New York Open.

Expected:

- Session phase and metrics are calculated.
- Session range ATR, net progress ATR, efficiency, direction, high/low sweeps, Asian high/low breaks, and post-London decline context update.
- Session does not automatically force direction.
- London Open is context, not automatic confirmation.

Result:

- Pass / Fail:
- Notes:

## Test 8 - Breakout reasoning

Setup:

- Choose a genuine breakout candidate.

Expected:

- Level break is detected.
- Candidate qualification is recorded.
- `BREAKOUT_CANDIDATE` remains a classification flag, not a live state.
- Second-bar result is evaluated on the immediate next completed bar.
- Support and contradiction reasons are visible.
- Final interpretation explains why follow-through is strong, weak, unresolved, or failed.

Result:

- Pass / Fail:
- Notes:

## Test 9 - Failed breakout reasoning

Setup:

- Choose a failed breakout sequence.

Expected:

- Failed breakout is a Priority 1 event.
- Raw rejection/engulfing patterns are supporting evidence only.
- Interpretation changes on the correct bar.
- The latest transition record identifies the trigger.

Result:

- Pass / Fail:
- Notes:

## Test 10 - Alert JSON validity

Setup:

- Trigger an alert on a known checkpoint bar.
- Copy the JSON payload into a JSON parser.

Expected:

- JSON parses successfully.
- `interpretation` block exists.
- `evidence.supporting`, `evidence.contradicting`, and `evidence.missing` arrays exist.
- `raw_candle_evidence` exists.
- `session_context` exists.
- `session_context.session_open`, `session_context.session_high`, and `session_context.session_low` exist.
- `interpretation.rule_status` exists.
- `primary_event` and `secondary_events` exist.
- No dummy values are inserted.
- `na` numeric values are represented safely as `null`.
- Raw candle patterns do not create alerts by default.

Result:

- Pass / Fail:
- Notes:

## Static Audit Checklist

- `indicator(...)` still exists.
- `strategy(...)` does not exist.
- No `strategy.entry()`.
- No `strategy.exit()`.
- No `strategy.close()`.
- v0.1 files remain unchanged.
- `Display Mode` input exists.
- Priority 1 and Priority 2 are separated.
- Raw candle events are not major alerts by default.
- `interpretationChangedThisBar` exists.
- Supporting evidence fields exist.
- Contradicting evidence fields exist.
- Missing evidence fields exist.
- Session context fields exist.
- Alert JSON includes interpretation and evidence.
- No unexplained hard-coded thresholds were introduced.

## TradingView Compile

TradingView official compile has not been completed unless manually tested in TradingView.
