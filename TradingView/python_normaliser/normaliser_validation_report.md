# Normaliser Validation Report

- Input filename: `2026-07-30_USDJPY.json`
- Output filename: `2026-07-30_USDJPY_analysis.csv`
- Input byte size: 2835209
- Output byte size: 179092
- Size reduction percentage: 93.68%
- Input record count: 288
- Output row count: 288
- Output column count: 70
- Duplicate count: bar_index=0, bar_time=0
- Missing required field count: 0
- Warning count: 0
- Optional missing field summary:
- none
- Out-of-window bar count: 1
- Earliest timestamp: 2026-07-29T22:55:00Z
- Latest timestamp: 2026-07-30T22:50:00Z
- Candle recalculation mismatch count: 0

## Candle Recalculation Mismatches

- PASS: no material mismatches above tolerance

## 13:30 London Checkpoint

- bar_index 21209:
  - bar_time_london: 2026-07-30T13:30:00+01:00
  - open: 162.895
  - high: 162.936
  - low: 162.777
  - close: 162.871
  - body_atr: 0.2724177072
  - range_atr: 1.8047673099
  - body_ratio: 0.1509433962
  - close_location: 0.5911949686

## 13:35 London Checkpoint

- bar_index 21210:
  - bar_time_london: 2026-07-30T13:35:00+01:00
  - open: 162.87
  - high: 162.893
  - low: 162.768
  - close: 162.781
  - body_atr: 0.9801762115
  - range_atr: 1.3766519824
  - body_ratio: 0.712
  - close_location: 0.104

## H1 Multiple-Version Preservation

- Result: PASS
- h1_time 1785412800000 swing_low 162.288: bars 21215 to 21221 (7 rows)
- h1_time 1785412800000 swing_low 163.209: bars 21222 to 21226 (5 rows)

## Excluded-Field Verification

- Result: PASS
- Excluded fields present in CSV header: none

## Test Result

- Test command: `.venv/bin/python -m pytest -q`
- Test result: 18 passed in 0.10s
