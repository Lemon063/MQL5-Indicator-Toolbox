# Alterf Manual Trade Analyzer v0.2

# Alert na Deadlock Bug Incident Note

## 1. Metadata

| Field | Status |
| --- | --- |
| Incident date | 2026-07-26 |
| Script name and version | Alterf Manual Trade Analyzer v0.2 |
| Indicator title | `Alterf Manual Trade Analyzer v0.2 - Trading Logic Validation Layer` |
| Target file | `/Users/avislai/Documents/Codex/Toolbox/TradingView/Alterf_Manual_Trade_Analyzer_v0_2.pine` |
| Investigation status | Source reviewed for alert gate, `lastAlertBar`, `enableAlerts`, and `confirmedAlertsOnly` control flow |
| Root cause status | ROOT CAUSE PROVEN |
| Code fix status | FIX APPLIED |
| Live end-to-end verification status | LIVE VERIFICATION PENDING |

Important separation of status:

- ROOT CAUSE PROVEN: the original `na` initialization deadlock is sufficient to explain zero TradingView alert execution.
- FIX APPLIED: the current source now contains the explicit `na(lastAlertBar)` guard.
- LIVE VERIFICATION PENDING: no live TradingView Alert Log, Cloud Run request, or Pub/Sub message evidence is recorded in this note.

## 2. Incident Summary

TradingView main indicator alert was reported to run without producing Alert Log entries, email notifications, app notifications, or Cloud Run requests.

Cloud Run and Pub/Sub worked correctly when tested with test JSON. A separate minimal diagnostic Pine Script successfully triggered on BTCUSDT M5 bar close. Deleting the old script, adding the current source again, and rebuilding the alert still did not make the main indicator trigger.

Based on those observations, the problem was narrowed to the main Pine Script execution path rather than Cloud Run, Pub/Sub, or TradingView notification delivery.

## 3. Faulty Code

Current source evidence:

- Line 1308 declares `lastAlertBar` as a persistent `var int` initialized to `na`.
- Line 1311 reads `lastAlertBar` in `alertAlreadySent`.
- Line 1369 currently gates `alert()` with the fixed condition: `alertAllowed and (na(lastAlertBar) or lastAlertBar != bar_index)`.
- Line 1370 calls `alert(jsonOutput, alert.freq_once_per_bar_close)`.
- Line 1371 writes `lastAlertBar := bar_index`.

Current source excerpt:

```pine
// Alterf_Manual_Trade_Analyzer_v0_2.pine:1308
var int lastAlertBar = na

// Alterf_Manual_Trade_Analyzer_v0_2.pine:1311
alertAlreadySent = lastAlertBar == bar_index and lastAlertEvent == checkpointEvent and lastAlertAttemptId == breakoutAttemptId

// Alterf_Manual_Trade_Analyzer_v0_2.pine:1369-1371
if alertAllowed and (na(lastAlertBar) or lastAlertBar != bar_index)
    alert(jsonOutput, alert.freq_once_per_bar_close)
    lastAlertBar := bar_index
```

The faulty incident pattern was this same-bar duplicate gate without the explicit `na(lastAlertBar)` first-run escape:

```pine
var int lastAlertBar = na
if alertAllowed and lastAlertBar != bar_index
    alert(jsonOutput, alert.freq_once_per_bar_close)
    lastAlertBar := bar_index
```

This exact faulty condition is not present in the current source reviewed on 2026-07-26. The current source has already been changed to include `na(lastAlertBar)`.

## 4. Root Cause — Plain Language

`lastAlertBar` 一開始並不是一個數字，而是 `na`，即未知值。

Bug 版本的程式嘗試問：「一個未知值是否不等於目前 bar 編號？」在 Pine 裏面，涉及 `na` 的 comparison 不會變成一個正常可用的 `true`。所以第一次不能進入 `if`。

最致命的是，更新 `lastAlertBar` 的 statement 又放在同一個 `if` 入面。第一次入不到去，就永遠無機會把 `lastAlertBar` 改成正常數字。下一支 bar 仍然面對同一個 `na` 問題，形成永久 deadlock。

實際數字例子：

| Step | Condition result | Behaviour |
| --- | --- | --- |
| 起始：`lastAlertBar = na` | N/A | 尚未有任何 bar index 被記錄 |
| Bar 100：`na != 100` | false | 不發 alert，`lastAlertBar` 仍是 `na` |
| Bar 101：`na != 101` | false | 不發 alert，`lastAlertBar` 仍是 `na` |
| Bar 102：`na != 102` | false | 繼續永遠不發 alert |

## 5. Pine na Comparison Rule

Pine 的 `na` 代表 unavailable / unknown value。涉及 `na` 的普通 comparison，例如 `==`、`!=`、`>`、`<`，不能當作一般數字比較去期待得到正常 `true` 結果。要檢查一個值是否 `na`，應使用 `na(variable)`。

Official references:

- [TradingView Pine Script FAQ: Variables and operators](https://www.tradingview.com/pine-script-docs/faq/variables-and-operators/)
- [TradingView Pine Script language: Operators](https://www.tradingview.com/pine-script-docs/language/operators/)

## 6. Minimal Correct Fix

The minimal correct fix is:

```pine
if alertAllowed and (na(lastAlertBar) or lastAlertBar != bar_index)
    alert(jsonOutput, alert.freq_once_per_bar_close)
    lastAlertBar := bar_index
```

Why this works:

- 第一次執行時，`na(lastAlertBar)` 是 `true`，所以可以發 alert。
- 發送後，`lastAlertBar := bar_index` 記錄目前 bar。
- 同一支 bar 再次 execution 時，`lastAlertBar != bar_index` 是 false，所以不會重複發送。
- 下一支 bar 的 `bar_index` 不同，所以可以再次發送。

Current source status: this fix is already present at line 1369.

## 7. Before/After Behaviour

| Scenario | Bug version: `lastAlertBar != bar_index` | Fixed version: `na(lastAlertBar) or lastAlertBar != bar_index` |
| --- | --- | --- |
| First confirmed realtime bar | No alert, because `lastAlertBar` is `na` | Alert allowed, because `na(lastAlertBar)` is true |
| Same bar executes again | No alert; `lastAlertBar` is still `na` in bug version | No duplicate alert, because `lastAlertBar == bar_index` |
| Next confirmed realtime bar | No alert; deadlock continues | Alert allowed, because `bar_index` changed |

## 8. Why the Earlier Audit Missed It

The earlier audit saw both `lastAlertBar != bar_index` and `lastAlertBar = na`, but incorrectly assumed the first bar would pass the condition.

The issue was not that the code was invisible. The issue was a wrong understanding of Pine's `na` comparison semantics.

Therefore, the old conclusion that the duplicate same-bar gate was a PASS was incorrect.

The old TradingView alert snapshot theory should be treated only as a hypothesis at that time. Because rebuilding the alert with the current source still reportedly failed before this root cause was isolated, the old snapshot theory is not the main proven root cause for the complete absence of alerts.

## 9. Evidence and Validation Status

Proven:

- Diagnostic alert can trigger.
- Cloud Run and Pub/Sub tests succeeded with test JSON.
- The original condition had an `na` initialization deadlock pattern.
- This deadlock is sufficient to explain why there was no TradingView Alert Log at all.
- Current source now includes the `na(lastAlertBar)` guard at line 1369.

Still pending:

- Whether the fixed main indicator triggers on every confirmed realtime M5 bar.
- Whether the full `jsonOutput` successfully reaches Cloud Run.
- Whether Pub/Sub receives the full TradingView JSON.
- Whether JSON length and format are normal in live alert runtime.

Only after there is TradingView Alert Log evidence and Pub/Sub message evidence should the incident be marked LIVE VERIFIED.

## 10. Additional Findings to Follow Up

These findings are recorded only; no Pine Script changes were made in this note.

- `enableAlerts` is declared at line 211 but no other usage was found in the current source.
- `confirmedAlertsOnly` is declared at line 212 but no other usage was found in the current source.
- Because they do not currently participate in the alert control flow, they appear to be independent control-flow issues.
- They are not the direct root cause of the complete no-alert symptom described in this incident note.
- The full JSON should be checked in live runtime, but this note does not claim a JSON problem without live evidence.
- After any Pine code change, the TradingView alert must be rebuilt because existing alerts use the script snapshot from the time the alert was created.

Current alert control-flow evidence:

```pine
// Alterf_Manual_Trade_Analyzer_v0_2.pine:1312
alertAllowed = barstate.isrealtime and barstate.isconfirmed

// Alterf_Manual_Trade_Analyzer_v0_2.pine:1369
if alertAllowed and (na(lastAlertBar) or lastAlertBar != bar_index)
```

`enableAlerts` and `confirmedAlertsOnly` are not included in this gate in the reviewed source.

## 11. Regression Prevention Rule

Review rule:

Any state variable initialized with `var ... = na` must explicitly handle `na(variable)` before using `==`, `!=`, `>`, or `<` comparisons.

Review checklist:

- Find all `var ... = na`.
- Find all comparisons involving those variables.
- Confirm the first execution has a valid initialization path.
- Confirm the update statement is not wrapped inside a gate that can never pass for the first execution.
- Use first bar, same bar, and next bar truth-table testing.
