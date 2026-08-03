# Analysis CSV Schema v0.1

This schema defines the derived TradingView daily price-action reconstruction CSV produced by `tradingview_json_to_analysis_csv.py`.

The raw TradingView JSON remains the source of truth. The CSV is a deterministic, compact analysis input and intentionally excludes TradingView proposed interpretation/classification fields.

## File Naming

`YYYY-MM-DD_PAIR_analysis.csv`

Example:

`2026-07-30_USDJPY_analysis.csv`

## Ordering And Encoding

- Encoding: UTF-8
- One header row
- One output row per input record
- Rows sorted by `bar_time` ascending
- Missing optional values are blank
- Boolean values are `true` or `false`
- No Python `None` strings
- Stable column order

## Column Order

### A. Identity And Time

1. `bar_index`
2. `bar_time_epoch_ms`
3. `bar_time_utc`
4. `bar_time_london`
5. `within_export_window`
6. `symbol`
7. `timeframe`
8. `session`
9. `session_phase`

### B. Raw OHLCV

10. `open`
11. `high`
12. `low`
13. `close`
14. `volume`

### C. Deterministic Single-Bar Measurements

15. `direction`
16. `range`
17. `body_size`
18. `body_ratio`
19. `upper_wick`
20. `lower_wick`
21. `upper_wick_ratio`
22. `lower_wick_ratio`
23. `close_location`
24. `atr`
25. `body_atr`
26. `range_atr`

### D. Multi-Bar Measurements

27. `net_progress_3`
28. `net_progress_6`
29. `net_progress_12`
30. `net_progress_atr_3`
31. `net_progress_atr_6`
32. `net_progress_atr_12`
33. `directional_efficiency_3`
34. `directional_efficiency_6`
35. `directional_efficiency_12`

### E. Overlap And Consecutive Progress

36. `overlap_with_previous`
37. `overlap_ratio_previous`
38. `consecutive_higher_closes`
39. `consecutive_lower_closes`

### F. Levels

40. `nearest_level`
41. `nearest_level_source`
42. `nearest_level_distance`
43. `nearest_level_distance_atr`
44. `previous_day_high`
45. `previous_day_low`
46. `previous_session_high`
47. `previous_session_low`
48. `consolidation_high`
49. `consolidation_low`

Manual and value-area fields are intentionally excluded when they are zero/null in the source.

### G. Essential MTF Fields

50. `m15_time`
51. `m15_direction`
52. `m15_trend`
53. `m15_efficiency`
54. `m15_atr`
55. `m15_swing_high`
56. `m15_swing_low`
57. `m30_time`
58. `m30_direction`
59. `m30_trend`
60. `m30_efficiency`
61. `m30_atr`
62. `m30_swing_high`
63. `m30_swing_low`
64. `h1_time`
65. `h1_direction`
66. `h1_trend`
67. `h1_efficiency`
68. `h1_atr`
69. `h1_swing_high`
70. `h1_swing_low`

## Deterministic Calculations

All candle measurements are recalculated from raw OHLC:

- `direction`: `BULLISH` if `close > open`, `BEARISH` if `close < open`, otherwise `NEUTRAL`
- `range`: `high - low`
- `body_size`: `abs(close - open)`
- `body_ratio`: `body_size / range`; blank if `range == 0`
- `upper_wick`: `high - max(open, close)`
- `lower_wick`: `min(open, close) - low`
- `upper_wick_ratio`: `upper_wick / range`; blank if `range == 0`
- `lower_wick_ratio`: `lower_wick / range`; blank if `range == 0`
- `close_location`: `(close - low) / range`; blank if `range == 0`
- `atr`: source JSON `candle.atr`
- `body_atr`: `body_size / atr`; blank if ATR is missing or zero
- `range_atr`: `range / atr`; blank if ATR is missing or zero

Multi-bar windows use `N = 3, 6, 12`:

- `net_progress_N`: `close_t - close_t_minus_N`
- `net_progress_atr_N`: `net_progress_N / current_atr`
- `directional_efficiency_N`: `abs(close_t - close_t_minus_N) / sum(abs(close_i - close_i_minus_1))`

If there is insufficient history or the denominator is zero, the field is blank.

Overlap:

- `overlap_with_previous`: `max(0, min(current_high, previous_high) - max(current_low, previous_low))`
- `overlap_ratio_previous`: `overlap_with_previous / min(current_range, previous_range)`

If there is no previous bar or either range is zero, overlap fields are blank. Ratio is clamped to `[0, 1]`.

Consecutive progress:

- `consecutive_higher_closes`: increments when current close is higher than previous close; otherwise resets to zero
- `consecutive_lower_closes`: increments when current close is lower than previous close; otherwise resets to zero
- Equal closes reset both counts to zero

## Excluded Source Fields

The following source fields must not appear in the CSV header:

- `interpretation`
- `evidence`
- `scores`
- `context_flags`
- `enum_codes`
- `checkpoint_event`
- `event`
- `primary_event`
- `secondary_events`
- `regime`
- `momentum`
- `transition`
- `confirmed`
- `raw_candle_evidence`
- `_bq_metadata`
- `indicator_version`
- `schema_version`

