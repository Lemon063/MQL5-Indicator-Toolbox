#!/usr/bin/env python3
"""Convert daily TradingView JSON exports into compact analysis CSV."""

from __future__ import annotations

import argparse
import csv
import io
import json
import os
import sys
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlparse
from zoneinfo import ZoneInfo


WINDOWS = (3, 6, 12)
LONDON_TZ = ZoneInfo("Europe/London")
FLOAT_TOLERANCE = 1e-4

EXCLUDED_FIELDS = {
    "interpretation",
    "evidence",
    "scores",
    "context_flags",
    "enum_codes",
    "checkpoint_event",
    "event",
    "primary_event",
    "secondary_events",
    "regime",
    "momentum",
    "transition",
    "confirmed",
    "raw_candle_evidence",
    "_bq_metadata",
    "indicator_version",
    "schema_version",
}

CSV_COLUMNS = [
    "bar_index",
    "bar_time_epoch_ms",
    "bar_time_utc",
    "bar_time_london",
    "within_export_window",
    "symbol",
    "timeframe",
    "session",
    "session_phase",
    "open",
    "high",
    "low",
    "close",
    "volume",
    "direction",
    "range",
    "body_size",
    "body_ratio",
    "upper_wick",
    "lower_wick",
    "upper_wick_ratio",
    "lower_wick_ratio",
    "close_location",
    "atr",
    "body_atr",
    "range_atr",
    "net_progress_3",
    "net_progress_6",
    "net_progress_12",
    "net_progress_atr_3",
    "net_progress_atr_6",
    "net_progress_atr_12",
    "directional_efficiency_3",
    "directional_efficiency_6",
    "directional_efficiency_12",
    "overlap_with_previous",
    "overlap_ratio_previous",
    "consecutive_higher_closes",
    "consecutive_lower_closes",
    "nearest_level",
    "nearest_level_source",
    "nearest_level_distance",
    "nearest_level_distance_atr",
    "previous_day_high",
    "previous_day_low",
    "previous_session_high",
    "previous_session_low",
    "consolidation_high",
    "consolidation_low",
    "m15_time",
    "m15_direction",
    "m15_trend",
    "m15_efficiency",
    "m15_atr",
    "m15_swing_high",
    "m15_swing_low",
    "m30_time",
    "m30_direction",
    "m30_trend",
    "m30_efficiency",
    "m30_atr",
    "m30_swing_high",
    "m30_swing_low",
    "h1_time",
    "h1_direction",
    "h1_trend",
    "h1_efficiency",
    "h1_atr",
    "h1_swing_high",
    "h1_swing_low",
]


class NormaliserError(Exception):
    """Raised for fatal validation or IO failures."""


@dataclass
class RecalcMismatch:
    bar_index: Any
    timestamp: Any
    field: str
    json_value: Any
    recalculated_value: Any
    difference: float


@dataclass
class ValidationState:
    warnings: list[str] = field(default_factory=list)
    fatal_errors: list[str] = field(default_factory=list)
    duplicate_bar_index_count: int = 0
    duplicate_bar_time_count: int = 0
    missing_required_field_count: int = 0
    optional_missing_counts: dict[str, int] = field(default_factory=dict)
    out_of_window_count: int = 0
    candle_mismatches: list[RecalcMismatch] = field(default_factory=list)
    earliest_timestamp: int | None = None
    latest_timestamp: int | None = None


@dataclass
class NormaliseResult:
    csv_text: str
    rows: list[dict[str, Any]]
    validation: ValidationState
    summary: dict[str, Any]


def parse_gs_uri(uri: str) -> tuple[str, str]:
    parsed = urlparse(uri)
    if parsed.scheme != "gs" or not parsed.netloc or not parsed.path.lstrip("/"):
        raise ValueError(f"Invalid GCS URI: {uri}")
    return parsed.netloc, parsed.path.lstrip("/")


def is_gs_uri(uri: str) -> bool:
    return uri.startswith("gs://")


def read_text(uri: str) -> str:
    if is_gs_uri(uri):
        bucket_name, blob_name = parse_gs_uri(uri)
        try:
            from google.cloud import storage
        except ImportError as exc:
            raise NormaliserError("google-cloud-storage is required for gs:// input") from exc
        try:
            client = storage.Client()
            return client.bucket(bucket_name).blob(blob_name).download_as_text()
        except Exception as exc:  # pragma: no cover - depends on external GCS
            raise NormaliserError(f"Failed to read GCS input {uri}: {exc}") from exc
    try:
        return Path(uri).read_text(encoding="utf-8")
    except Exception as exc:
        raise NormaliserError(f"Failed to read local input {uri}: {exc}") from exc


def write_text(uri: str, text: str, content_type: str = "text/csv") -> None:
    if is_gs_uri(uri):
        bucket_name, blob_name = parse_gs_uri(uri)
        try:
            from google.cloud import storage
        except ImportError as exc:
            raise NormaliserError("google-cloud-storage is required for gs:// output") from exc
        try:
            client = storage.Client()
            client.bucket(bucket_name).blob(blob_name).upload_from_string(text, content_type=content_type)
            return
        except Exception as exc:  # pragma: no cover - depends on external GCS
            raise NormaliserError(f"Failed to write GCS output {uri}: {exc}") from exc
    try:
        path = Path(uri)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8", newline="")
    except Exception as exc:
        raise NormaliserError(f"Failed to write local output {uri}: {exc}") from exc


def parse_json_payload(text: str) -> dict[str, Any]:
    try:
        payload = json.loads(text)
    except json.JSONDecodeError as exc:
        raise NormaliserError(f"Input is not valid JSON: {exc}") from exc
    if not isinstance(payload, dict):
        raise NormaliserError("Top-level JSON must be an object")
    return payload


def parse_utc_instant(value: Any) -> datetime | None:
    if not value:
        return None
    if isinstance(value, str):
        value = value.replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(value)
    except (TypeError, ValueError):
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def epoch_ms_to_utc(ms: int) -> datetime:
    return datetime.fromtimestamp(ms / 1000, tz=UTC)


def format_dt_utc(ms: int) -> str:
    return epoch_ms_to_utc(ms).isoformat().replace("+00:00", "Z")


def format_dt_london(ms: int) -> str:
    return epoch_ms_to_utc(ms).astimezone(LONDON_TZ).isoformat()


def as_float(value: Any) -> float | None:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def is_missing(value: Any) -> bool:
    return value is None or value == ""


def blank_zero(value: Any) -> Any:
    numeric = as_float(value)
    if numeric is None:
        return ""
    if abs(numeric) <= FLOAT_TOLERANCE:
        return ""
    return value


def fmt_value(value: Any) -> str:
    if value is None or value == "":
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int) and not isinstance(value, bool):
        return str(value)
    if isinstance(value, float):
        if value != value:
            return ""
        if value != 0 and (abs(value) >= 1e12 or abs(value) < 1e-9):
            return f"{value:.12g}"
        text = f"{value:.10f}".rstrip("0").rstrip(".")
        return "0" if text == "-0" else text
    return str(value)


def get_nested(mapping: dict[str, Any], *path: str) -> Any:
    value: Any = mapping
    for key in path:
        if not isinstance(value, dict):
            return None
        value = value.get(key)
    return value


def calculate_candle(open_: float, high: float, low: float, close: float, atr: float | None) -> dict[str, Any]:
    candle_range = high - low
    body_size = abs(close - open_)
    upper_wick = high - max(open_, close)
    lower_wick = min(open_, close) - low
    if close > open_:
        direction = "BULLISH"
    elif close < open_:
        direction = "BEARISH"
    else:
        direction = "NEUTRAL"
    ratios: dict[str, Any]
    if abs(candle_range) <= FLOAT_TOLERANCE:
        ratios = {
            "body_ratio": None,
            "upper_wick_ratio": None,
            "lower_wick_ratio": None,
            "close_location": None,
        }
    else:
        ratios = {
            "body_ratio": body_size / candle_range,
            "upper_wick_ratio": upper_wick / candle_range,
            "lower_wick_ratio": lower_wick / candle_range,
            "close_location": (close - low) / candle_range,
        }
    atr_ratios = {
        "body_atr": None if atr is None or abs(atr) <= FLOAT_TOLERANCE else body_size / atr,
        "range_atr": None if atr is None or abs(atr) <= FLOAT_TOLERANCE else candle_range / atr,
    }
    return {
        "direction": direction,
        "range": candle_range,
        "body_size": body_size,
        "upper_wick": upper_wick,
        "lower_wick": lower_wick,
        **ratios,
        "atr": atr,
        **atr_ratios,
    }


def compare_source_candle(
    record: dict[str, Any],
    calculated: dict[str, Any],
    validation: ValidationState,
) -> None:
    source = record.get("candle") if isinstance(record.get("candle"), dict) else {}
    compare_fields = [
        "body_size",
        "range",
        "upper_wick",
        "lower_wick",
        "body_ratio",
        "upper_wick_ratio",
        "lower_wick_ratio",
        "close_location",
    ]
    for field_name in compare_fields:
        if field_name not in source or source.get(field_name) is None or calculated.get(field_name) is None:
            continue
        source_value = as_float(source.get(field_name))
        calc_value = as_float(calculated.get(field_name))
        if source_value is None or calc_value is None:
            continue
        diff = abs(source_value - calc_value)
        if diff > FLOAT_TOLERANCE:
            validation.candle_mismatches.append(
                RecalcMismatch(
                    bar_index=record.get("bar_index"),
                    timestamp=record.get("bar_time"),
                    field=field_name,
                    json_value=source_value,
                    recalculated_value=calc_value,
                    difference=diff,
                )
            )


def require_record_field(record: dict[str, Any], field_name: str, validation: ValidationState) -> Any:
    value = record.get(field_name)
    if is_missing(value):
        validation.fatal_errors.append(f"Missing required field {field_name} at record {record.get('bar_index', '<unknown>')}")
        validation.missing_required_field_count += 1
    return value


def require_ohlc(record: dict[str, Any], validation: ValidationState) -> tuple[float, float, float, float]:
    ohlcv = record.get("ohlcv")
    if not isinstance(ohlcv, dict):
        validation.fatal_errors.append(f"Missing required ohlcv object at record {record.get('bar_index', '<unknown>')}")
        validation.missing_required_field_count += 4
        return (0.0, 0.0, 0.0, 0.0)
    values = []
    for name in ("open", "high", "low", "close"):
        numeric = as_float(ohlcv.get(name))
        if numeric is None:
            validation.fatal_errors.append(f"Missing or non-numeric OHLC field ohlcv.{name} at bar {record.get('bar_index', '<unknown>')}")
            validation.missing_required_field_count += 1
            numeric = 0.0
        values.append(numeric)
    return tuple(values)  # type: ignore[return-value]


def record_optional_missing(validation: ValidationState, field_name: str, value: Any) -> None:
    if is_missing(value):
        validation.optional_missing_counts[field_name] = validation.optional_missing_counts.get(field_name, 0) + 1


def validate_payload_shape(payload: dict[str, Any], validation: ValidationState) -> list[dict[str, Any]]:
    records = payload.get("records")
    if not isinstance(records, list):
        validation.fatal_errors.append("Top-level records must exist and be a list")
        return []
    record_count = payload.get("record_count")
    if record_count is not None and record_count != len(records):
        validation.fatal_errors.append(f"record_count {record_count} does not match actual records {len(records)}")
    if is_missing(payload.get("symbol")):
        validation.fatal_errors.append("Top-level symbol is required")
    return records


def validate_record_basics(records: list[dict[str, Any]], validation: ValidationState) -> None:
    seen_indexes: set[Any] = set()
    seen_times: set[Any] = set()
    previous_time: int | None = None
    for raw in records:
        if not isinstance(raw, dict):
            validation.fatal_errors.append("Each record must be an object")
            continue
        bar_index = require_record_field(raw, "bar_index", validation)
        bar_time = require_record_field(raw, "bar_time", validation)
        if bar_index in seen_indexes:
            validation.duplicate_bar_index_count += 1
        seen_indexes.add(bar_index)
        if bar_time in seen_times:
            validation.duplicate_bar_time_count += 1
        seen_times.add(bar_time)
        if isinstance(bar_time, int):
            if previous_time is not None and bar_time < previous_time:
                validation.fatal_errors.append(f"bar_time is not ascending at bar {bar_index}")
            previous_time = bar_time
            validation.earliest_timestamp = bar_time if validation.earliest_timestamp is None else min(validation.earliest_timestamp, bar_time)
            validation.latest_timestamp = bar_time if validation.latest_timestamp is None else max(validation.latest_timestamp, bar_time)
        else:
            validation.fatal_errors.append(f"bar_time must be an integer epoch ms at bar {bar_index}")
            validation.missing_required_field_count += 1
        timeframe = raw.get("chart_timeframe") or raw.get("timeframe")
        if is_missing(timeframe):
            validation.fatal_errors.append(f"Missing chart_timeframe/timeframe at bar {bar_index}")
            validation.missing_required_field_count += 1
        open_, high, low, close = require_ohlc(raw, validation)
        if high + FLOAT_TOLERANCE < max(open_, close, low):
            validation.fatal_errors.append(f"OHLC high is invalid at bar {bar_index}")
        if low - FLOAT_TOLERANCE > min(open_, close, high):
            validation.fatal_errors.append(f"OHLC low is invalid at bar {bar_index}")
        if high - low < -FLOAT_TOLERANCE:
            validation.fatal_errors.append(f"OHLC range is negative at bar {bar_index}")
        atr = as_float(get_nested(raw, "candle", "atr"))
        if atr is not None and atr < -FLOAT_TOLERANCE:
            validation.fatal_errors.append(f"ATR is negative at bar {bar_index}")


def normalise_payload(payload: dict[str, Any]) -> NormaliseResult:
    validation = ValidationState()
    records = validate_payload_shape(payload, validation)
    validate_record_basics(records, validation)
    if validation.fatal_errors:
        raise NormaliserError("; ".join(validation.fatal_errors[:10]))

    utc_start = parse_utc_instant(payload.get("utc_start_inclusive"))
    utc_end = parse_utc_instant(payload.get("utc_end_exclusive"))
    if utc_start is None or utc_end is None:
        validation.warnings.append("Missing or invalid utc_start_inclusive/utc_end_exclusive; within_export_window left false")

    sorted_records = sorted(records, key=lambda item: item["bar_time"])
    rows: list[dict[str, Any]] = []
    closes: list[float] = []
    ranges: list[float] = []
    higher_count = 0
    lower_count = 0

    for index, record in enumerate(sorted_records):
        ohlcv = record["ohlcv"]
        open_ = float(ohlcv["open"])
        high = float(ohlcv["high"])
        low = float(ohlcv["low"])
        close = float(ohlcv["close"])
        atr = as_float(get_nested(record, "candle", "atr"))
        calculated = calculate_candle(open_, high, low, close, atr)
        compare_source_candle(record, calculated, validation)

        bar_time = int(record["bar_time"])
        bar_dt = epoch_ms_to_utc(bar_time)
        within_export_window = bool(utc_start and utc_end and utc_start <= bar_dt < utc_end)
        if not within_export_window:
            validation.out_of_window_count += 1

        row: dict[str, Any] = {
            "bar_index": record.get("bar_index"),
            "bar_time_epoch_ms": bar_time,
            "bar_time_utc": format_dt_utc(bar_time),
            "bar_time_london": format_dt_london(bar_time),
            "within_export_window": within_export_window,
            "symbol": record.get("symbol") or payload.get("symbol"),
            "timeframe": record.get("chart_timeframe") or record.get("timeframe"),
            "session": record.get("session"),
            "session_phase": get_nested(record, "session_context", "phase") or get_nested(record, "context_flags", "session_phase"),
            "open": open_,
            "high": high,
            "low": low,
            "close": close,
            "volume": ohlcv.get("volume"),
            **calculated,
        }

        if index == 0:
            row["overlap_with_previous"] = None
            row["overlap_ratio_previous"] = None
        else:
            previous = sorted_records[index - 1]["ohlcv"]
            prev_high = float(previous["high"])
            prev_low = float(previous["low"])
            prev_range = ranges[-1]
            overlap = max(0.0, min(high, prev_high) - max(low, prev_low))
            if abs(calculated["range"]) <= FLOAT_TOLERANCE or abs(prev_range) <= FLOAT_TOLERANCE:
                row["overlap_with_previous"] = None
                row["overlap_ratio_previous"] = None
            else:
                row["overlap_with_previous"] = overlap
                row["overlap_ratio_previous"] = min(1.0, max(0.0, overlap / min(calculated["range"], prev_range)))

        previous_close = closes[-1] if closes else None
        if previous_close is None or close == previous_close:
            higher_count = 0
            lower_count = 0
        elif close > previous_close:
            higher_count += 1
            lower_count = 0
        else:
            lower_count += 1
            higher_count = 0
        row["consecutive_higher_closes"] = higher_count
        row["consecutive_lower_closes"] = lower_count

        for window in WINDOWS:
            if len(closes) < window:
                row[f"net_progress_{window}"] = None
                row[f"net_progress_atr_{window}"] = None
                row[f"directional_efficiency_{window}"] = None
                continue
            net_progress = close - closes[-window]
            denominator = sum(abs((closes + [close])[j] - (closes + [close])[j - 1]) for j in range(len(closes) + 1 - window, len(closes) + 1))
            row[f"net_progress_{window}"] = net_progress
            row[f"net_progress_atr_{window}"] = None if atr is None or abs(atr) <= FLOAT_TOLERANCE else net_progress / atr
            row[f"directional_efficiency_{window}"] = None if abs(denominator) <= FLOAT_TOLERANCE else abs(net_progress) / denominator

        levels = record.get("levels") if isinstance(record.get("levels"), dict) else {}
        row.update(
            {
                "nearest_level": get_nested(levels, "nearest_level", "level"),
                "nearest_level_source": get_nested(levels, "nearest_level", "source"),
                "nearest_level_distance": get_nested(levels, "nearest_level", "distance"),
                "nearest_level_distance_atr": get_nested(levels, "nearest_level", "distance_atr"),
                "previous_day_high": get_nested(levels, "previous_day", "high"),
                "previous_day_low": get_nested(levels, "previous_day", "low"),
                "previous_session_high": get_nested(levels, "previous_session", "high"),
                "previous_session_low": get_nested(levels, "previous_session", "low"),
                "consolidation_high": blank_zero(get_nested(levels, "consolidation", "high")),
                "consolidation_low": blank_zero(get_nested(levels, "consolidation", "low")),
            }
        )

        structure = record.get("structure") if isinstance(record.get("structure"), dict) else {}
        for prefix in ("m15", "m30", "h1"):
            mtf = structure.get(prefix) if isinstance(structure.get(prefix), dict) else {}
            for field_name in ("time", "direction", "trend", "efficiency", "atr", "swing_high", "swing_low"):
                csv_name = f"{prefix}_{field_name}"
                value = mtf.get(field_name)
                record_optional_missing(validation, csv_name, value)
                row[csv_name] = value

        closes.append(close)
        ranges.append(calculated["range"])
        rows.append(row)

    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=CSV_COLUMNS, extrasaction="ignore", lineterminator="\n")
    writer.writeheader()
    for row in rows:
        writer.writerow({column: fmt_value(row.get(column)) for column in CSV_COLUMNS})
    csv_text = output.getvalue()

    summary = {
        "status": "ok",
        "input_record_count": len(records),
        "output_row_count": len(rows),
        "output_column_count": len(CSV_COLUMNS),
        "warnings": len(validation.warnings),
        "duplicate_bar_index_count": validation.duplicate_bar_index_count,
        "duplicate_bar_time_count": validation.duplicate_bar_time_count,
        "out_of_window_count": validation.out_of_window_count,
        "candle_recalculation_mismatch_count": len(validation.candle_mismatches),
        "earliest_timestamp": validation.earliest_timestamp,
        "latest_timestamp": validation.latest_timestamp,
    }
    return NormaliseResult(csv_text=csv_text, rows=rows, validation=validation, summary=summary)


def normalise_json_text(text: str) -> NormaliseResult:
    return normalise_payload(parse_json_payload(text))


def build_report(
    input_uri: str,
    output_uri: str,
    input_text: str,
    csv_text: str,
    result: NormaliseResult,
    test_command: str | None = None,
    test_result: str | None = None,
) -> str:
    input_bytes = len(input_text.encode("utf-8"))
    output_bytes = len(csv_text.encode("utf-8"))
    reduction = 0.0 if input_bytes == 0 else (1 - output_bytes / input_bytes) * 100
    rows = result.rows
    header = CSV_COLUMNS
    excluded_present = sorted(EXCLUDED_FIELDS.intersection(header))

    def checkpoint(bar_index: int) -> str:
        row = next((item for item in rows if item.get("bar_index") == bar_index), None)
        if not row:
            return f"- bar_index {bar_index}: missing"
        keys = ["bar_time_london", "open", "high", "low", "close", "body_atr", "range_atr", "body_ratio", "close_location"]
        return "\n".join([f"- bar_index {bar_index}:"] + [f"  - {key}: {fmt_value(row.get(key))}" for key in keys])

    h1_versions: dict[Any, set[Any]] = {}
    h1_rows: dict[tuple[Any, Any], list[Any]] = {}
    for row in rows:
        key = row.get("h1_time")
        swing_low = row.get("h1_swing_low")
        h1_versions.setdefault(key, set()).add(swing_low)
        h1_rows.setdefault((key, swing_low), []).append(row.get("bar_index"))
    target_versions = h1_versions.get(1785412800000, set())
    version_lines = []
    for swing_low in sorted(target_versions):
        indexes = h1_rows[(1785412800000, swing_low)]
        version_lines.append(f"- h1_time 1785412800000 swing_low {fmt_value(swing_low)}: bars {indexes[0]} to {indexes[-1]} ({len(indexes)} rows)")
    h1_result = "PASS" if {162.288, 163.209}.issubset(target_versions) else "FAIL"

    mismatch_lines = [
        f"- bar_index {m.bar_index}, timestamp {m.timestamp}, {m.field}: JSON {fmt_value(m.json_value)} vs recalculated {fmt_value(m.recalculated_value)} (diff {fmt_value(m.difference)})"
        for m in result.validation.candle_mismatches[:20]
    ]
    if len(result.validation.candle_mismatches) > 20:
        mismatch_lines.append(f"- ... {len(result.validation.candle_mismatches) - 20} more")

    earliest = format_dt_utc(result.validation.earliest_timestamp) if result.validation.earliest_timestamp else ""
    latest = format_dt_utc(result.validation.latest_timestamp) if result.validation.latest_timestamp else ""
    optional_missing = "\n".join(
        f"- {name}: {count}" for name, count in sorted(result.validation.optional_missing_counts.items()) if count
    ) or "- none"

    return "\n".join(
        [
            "# Normaliser Validation Report",
            "",
            f"- Input filename: `{Path(input_uri).name if not is_gs_uri(input_uri) else input_uri}`",
            f"- Output filename: `{Path(output_uri).name if not is_gs_uri(output_uri) else output_uri}`",
            f"- Input byte size: {input_bytes}",
            f"- Output byte size: {output_bytes}",
            f"- Size reduction percentage: {reduction:.2f}%",
            f"- Input record count: {result.summary['input_record_count']}",
            f"- Output row count: {result.summary['output_row_count']}",
            f"- Output column count: {result.summary['output_column_count']}",
            f"- Duplicate count: bar_index={result.validation.duplicate_bar_index_count}, bar_time={result.validation.duplicate_bar_time_count}",
            f"- Missing required field count: {result.validation.missing_required_field_count}",
            f"- Warning count: {len(result.validation.warnings)}",
            "- Optional missing field summary:",
            optional_missing,
            f"- Out-of-window bar count: {result.validation.out_of_window_count}",
            f"- Earliest timestamp: {earliest}",
            f"- Latest timestamp: {latest}",
            f"- Candle recalculation mismatch count: {len(result.validation.candle_mismatches)}",
            "",
            "## Candle Recalculation Mismatches",
            "",
            "\n".join(mismatch_lines) if mismatch_lines else "- PASS: no material mismatches above tolerance",
            "",
            "## 13:30 London Checkpoint",
            "",
            checkpoint(21209),
            "",
            "## 13:35 London Checkpoint",
            "",
            checkpoint(21210),
            "",
            "## H1 Multiple-Version Preservation",
            "",
            f"- Result: {h1_result}",
            *(version_lines or ["- No rows found for h1_time 1785412800000"]),
            "",
            "## Excluded-Field Verification",
            "",
            f"- Result: {'PASS' if not excluded_present else 'FAIL'}",
            f"- Excluded fields present in CSV header: {', '.join(excluded_present) if excluded_present else 'none'}",
            "",
            "## Test Result",
            "",
            f"- Test command: `{test_command or ''}`",
            f"- Test result: {test_result or ''}",
            "",
        ]
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Normalise TradingView daily JSON to analysis CSV")
    parser.add_argument("--input", dest="input_uri", default=None, help="Local path or gs:// URI")
    parser.add_argument("--output", dest="output_uri", default=None, help="Local path or gs:// URI")
    parser.add_argument("--report", dest="report_uri", default=None, help="Optional local path or gs:// URI for validation report")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    input_uri = args.input_uri or os.environ.get("INPUT_URI")
    output_uri = args.output_uri or os.environ.get("OUTPUT_URI")
    if not input_uri or not output_uri:
        print("ERROR: --input/INPUT_URI and --output/OUTPUT_URI are required", file=sys.stderr)
        return 2
    try:
        input_text = read_text(input_uri)
        result = normalise_json_text(input_text)
        write_text(output_uri, result.csv_text, content_type="text/csv")
        if args.report_uri:
            report = build_report(input_uri, output_uri, input_text, result.csv_text, result)
            write_text(args.report_uri, report, content_type="text/markdown")
        print(json.dumps(result.summary, sort_keys=True))
        if result.validation.warnings:
            print(json.dumps({"warnings": result.validation.warnings}, sort_keys=True))
        return 0
    except NormaliserError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
