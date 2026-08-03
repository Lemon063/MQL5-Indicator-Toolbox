import csv
import io
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import tradingview_json_to_analysis_csv as n


REAL_INPUT = (
    ROOT.parent
    / "forex-discretionary-day-trading-price-action"
    / "data"
    / "bigquery_daily"
    / "2026-07-30_USDJPY.json"
)


def make_record(bar_index, bar_time, open_, high, low, close, atr=0.1, h1_time=1, h1_swing_low=99.0):
    rng = high - low
    body = abs(close - open_)
    return {
        "bar_index": bar_index,
        "bar_time": bar_time,
        "chart_timeframe": "5",
        "timeframe": "5",
        "symbol": "USDJPY",
        "session": "TEST_SESSION",
        "session_context": {"phase": "TEST_PHASE"},
        "ohlcv": {"open": open_, "high": high, "low": low, "close": close, "volume": 100},
        "candle": {
            "atr": atr,
            "range": rng,
            "body_size": body,
            "upper_wick": high - max(open_, close),
            "lower_wick": min(open_, close) - low,
            "body_ratio": None if rng == 0 else body / rng,
            "upper_wick_ratio": None if rng == 0 else (high - max(open_, close)) / rng,
            "lower_wick_ratio": None if rng == 0 else (min(open_, close) - low) / rng,
            "close_location": None if rng == 0 else (close - low) / rng,
        },
        "levels": {
            "nearest_level": {"level": 101.0, "source": "TEST", "distance": 0.5, "distance_atr": 5.0},
            "previous_day": {"high": 102.0, "low": 98.0},
            "previous_session": {"high": 101.5, "low": 98.5},
            "consolidation": {"high": 100.8, "low": 99.2},
            "manual": {"support_1": 0},
            "value_area": {"poc": 0, "vah": 0, "val": 0},
        },
        "structure": {
            "m15": {"time": 1, "direction": "BULLISH", "trend": 1, "efficiency": 0.5, "atr": 0.2, "swing_high": 102, "swing_low": 99},
            "m30": {"time": 1, "direction": "NEUTRAL", "trend": 0, "efficiency": 0.4, "atr": 0.3, "swing_high": 103, "swing_low": 98},
            "h1": {"time": h1_time, "direction": "BEARISH", "trend": -1, "efficiency": 0.3, "atr": 0.4, "swing_high": 104, "swing_low": h1_swing_low},
        },
    }


def make_payload(records):
    return {
        "export_schema": "test",
        "symbol": "USDJPY",
        "record_count": len(records),
        "utc_start_inclusive": "2026-07-30T00:00:00Z",
        "utc_end_exclusive": "2026-07-30T01:00:00Z",
        "records": records,
    }


def read_rows(csv_text):
    return list(csv.DictReader(io.StringIO(csv_text)))


def test_json_input_validation_requires_object_and_records_list():
    with pytest.raises(n.NormaliserError, match="Top-level JSON must be an object"):
        n.normalise_json_text("[]")
    with pytest.raises(n.NormaliserError, match="records"):
        n.normalise_payload({"symbol": "USDJPY", "records": {}})


def test_ohlc_validation_rejects_invalid_high_low():
    record = make_record(1, 1785369600000, 100, 99, 98, 100)
    with pytest.raises(n.NormaliserError, match="OHLC high is invalid"):
        n.normalise_payload(make_payload([record]))


def test_utc_to_london_dst_conversion():
    record = make_record(1, 1785414600000, 162.895, 162.936, 162.777, 162.871, atr=0.0881)
    result = n.normalise_payload(make_payload([record]))
    row = read_rows(result.csv_text)[0]
    assert row["bar_time_utc"] == "2026-07-30T12:30:00Z"
    assert row["bar_time_london"] == "2026-07-30T13:30:00+01:00"


def test_range_body_wick_calculations():
    record = make_record(1, 1785369600000, 100, 105, 98, 103, atr=2)
    row = read_rows(n.normalise_payload(make_payload([record])).csv_text)[0]
    assert row["direction"] == "BULLISH"
    assert float(row["range"]) == 7
    assert float(row["body_size"]) == 3
    assert float(row["upper_wick"]) == 2
    assert float(row["lower_wick"]) == 2
    assert float(row["body_ratio"]) == pytest.approx(3 / 7)


def test_zero_range_handling():
    record = make_record(1, 1785369600000, 100, 100, 100, 100, atr=0.1)
    row = read_rows(n.normalise_payload(make_payload([record])).csv_text)[0]
    assert row["range"] == "0"
    assert row["body_ratio"] == ""
    assert row["close_location"] == ""


def test_zero_and_missing_atr_handling():
    zero = make_record(1, 1785369600000, 100, 101, 99, 100.5, atr=0)
    missing = make_record(2, 1785369900000, 100.5, 101, 100, 100.6, atr=None)
    missing["candle"]["atr"] = None
    rows = read_rows(n.normalise_payload(make_payload([zero, missing])).csv_text)
    assert rows[0]["body_atr"] == ""
    assert rows[0]["range_atr"] == ""
    assert rows[1]["body_atr"] == ""
    assert rows[1]["range_atr"] == ""


def test_body_atr_and_range_atr():
    record = make_record(1, 1785369600000, 100, 105, 99, 102, atr=2)
    row = read_rows(n.normalise_payload(make_payload([record])).csv_text)[0]
    assert float(row["body_atr"]) == pytest.approx(1)
    assert float(row["range_atr"]) == pytest.approx(3)


def test_overlap_calculations_are_clamped_to_one():
    records = [
        make_record(1, 1785369600000, 100, 105, 95, 101),
        make_record(2, 1785369900000, 100, 102, 98, 101),
    ]
    row = read_rows(n.normalise_payload(make_payload(records)).csv_text)[1]
    assert float(row["overlap_with_previous"]) == pytest.approx(4)
    assert 0 <= float(row["overlap_ratio_previous"]) <= 1
    assert float(row["overlap_ratio_previous"]) == pytest.approx(1)


def test_directional_efficiency_calculations():
    closes = [100, 101, 102, 103]
    records = [make_record(i + 1, 1785369600000 + i * 300000, c - 0.2, c + 0.5, c - 0.5, c) for i, c in enumerate(closes)]
    row = read_rows(n.normalise_payload(make_payload(records)).csv_text)[3]
    assert float(row["net_progress_3"]) == pytest.approx(3)
    assert float(row["directional_efficiency_3"]) == pytest.approx(1)


def test_insufficient_history_outputs_nulls_as_blanks():
    record = make_record(1, 1785369600000, 100, 101, 99, 100.5)
    row = read_rows(n.normalise_payload(make_payload([record])).csv_text)[0]
    assert row["net_progress_3"] == ""
    assert row["directional_efficiency_12"] == ""


def test_consecutive_higher_lower_closes():
    closes = [100, 101, 102, 101, 100, 100]
    records = [make_record(i + 1, 1785369600000 + i * 300000, c, c + 1, c - 1, c) for i, c in enumerate(closes)]
    rows = read_rows(n.normalise_payload(make_payload(records)).csv_text)
    assert rows[2]["consecutive_higher_closes"] == "2"
    assert rows[4]["consecutive_lower_closes"] == "2"
    assert rows[5]["consecutive_higher_closes"] == "0"
    assert rows[5]["consecutive_lower_closes"] == "0"


def test_duplicate_bar_detection():
    records = [
        make_record(1, 1785369600000, 100, 101, 99, 100.5),
        make_record(1, 1785369900000, 100, 101, 99, 100.5),
    ]
    result = n.normalise_payload(make_payload(records))
    assert result.validation.duplicate_bar_index_count == 1


def test_out_of_export_window_flag():
    records = [
        make_record(1, 1785369300000, 100, 101, 99, 100.5),
        make_record(2, 1785369600000, 100, 101, 99, 100.5),
    ]
    rows = read_rows(n.normalise_payload(make_payload(records)).csv_text)
    assert rows[0]["within_export_window"] == "false"
    assert rows[1]["within_export_window"] == "true"


def test_proposed_fields_not_in_csv_header():
    result = n.normalise_payload(make_payload([make_record(1, 1785369600000, 100, 101, 99, 100.5)]))
    header = read_rows(result.csv_text)[0].keys()
    assert not n.EXCLUDED_FIELDS.intersection(header)


def test_gcs_uri_parsing():
    assert n.parse_gs_uri("gs://bucket/raw/USDJPY/2026/07/30.json") == ("bucket", "raw/USDJPY/2026/07/30.json")
    with pytest.raises(ValueError):
        n.parse_gs_uri("gs://bucket")


def test_local_read_write(tmp_path):
    path = tmp_path / "out.csv"
    n.write_text(str(path), "a,b\n1,2\n")
    assert n.read_text(str(path)) == "a,b\n1,2\n"


def test_july_30_integration():
    result = n.normalise_json_text(REAL_INPUT.read_text())
    rows = read_rows(result.csv_text)
    assert result.summary["input_record_count"] == 288
    assert result.summary["output_row_count"] == 288
    assert len({row["bar_index"] for row in rows}) == 288
    assert result.validation.out_of_window_count == 1
    by_index = {int(row["bar_index"]): row for row in rows}
    r21209 = by_index[21209]
    assert r21209["bar_time_london"] == "2026-07-30T13:30:00+01:00"
    assert float(r21209["open"]) == pytest.approx(162.895)
    assert float(r21209["high"]) == pytest.approx(162.936)
    assert float(r21209["low"]) == pytest.approx(162.777)
    assert float(r21209["close"]) == pytest.approx(162.871)
    assert float(r21209["body_atr"]) == pytest.approx(0.2724, abs=0.0002)
    assert float(r21209["range_atr"]) == pytest.approx(1.8048, abs=0.001)
    assert float(r21209["body_ratio"]) == pytest.approx(0.1509, abs=0.0002)
    assert float(r21209["close_location"]) == pytest.approx(0.5912, abs=0.0002)
    r21210 = by_index[21210]
    assert r21210["bar_time_london"] == "2026-07-30T13:35:00+01:00"
    assert float(r21210["open"]) == pytest.approx(162.870)
    assert float(r21210["high"]) == pytest.approx(162.893)
    assert float(r21210["low"]) == pytest.approx(162.768)
    assert float(r21210["close"]) == pytest.approx(162.781)
    assert float(r21210["body_atr"]) == pytest.approx(0.9802, abs=0.0002)
    assert float(r21210["range_atr"]) == pytest.approx(1.3767, abs=0.001)
    assert float(r21210["body_ratio"]) == pytest.approx(0.7120, abs=0.0002)
    assert float(r21210["close_location"]) == pytest.approx(0.1040, abs=0.0002)


def test_h1_same_timestamp_multiple_version_preservation():
    result = n.normalise_json_text(REAL_INPUT.read_text())
    rows = read_rows(result.csv_text)
    versions = {}
    for row in rows:
        if row["h1_time"] == "1785412800000":
            versions.setdefault(row["h1_swing_low"], []).append(int(row["bar_index"]))
    assert "162.288" in versions
    assert "163.209" in versions
    assert min(versions["162.288"]) < min(versions["163.209"])
