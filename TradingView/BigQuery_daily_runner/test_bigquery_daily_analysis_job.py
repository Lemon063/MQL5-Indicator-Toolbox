from __future__ import annotations

import csv
import io
import json
import sys
from dataclasses import dataclass
from datetime import UTC, date, datetime
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]
RUNNER_DIR = ROOT / "BigQuery_daily_runner"
RAW_BQ_ROWS = ROOT / "forex-discretionary-day-trading-price-action" / "work" / "2026-07-30_USDJPY_bq_rows.json"
if str(RUNNER_DIR) not in sys.path:
    sys.path.insert(0, str(RUNNER_DIR))

import bigquery_daily_analysis_job as job


def csv_text(rows: int = 1) -> str:
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=job.CSV_COLUMNS, lineterminator="\n")
    writer.writeheader()
    for index in range(rows):
        writer.writerow({column: "" for column in job.CSV_COLUMNS} | {"bar_index": index + 1, "symbol": "USDJPY"})
    return output.getvalue()


@dataclass
class Result:
    csv_text: str
    summary: dict


def normaliser_result(rows: int = 1) -> Result:
    return Result(csv_text=csv_text(rows), summary={"output_row_count": rows, "output_column_count": len(job.CSV_COLUMNS)})


def make_row(bar_time: int = 1785366000000, symbol: str = "USDJPY", bar_index: int = 1) -> dict:
    payload = {
        "bar_index": bar_index,
        "bar_time": bar_time,
        "timestamp": bar_time,
        "symbol": symbol,
        "timeframe": "5",
        "chart_timeframe": "5",
        "ohlcv": {"open": 100, "high": 101, "low": 99, "close": 100.5, "volume": 10},
    }
    return {
        "publish_time": "2026-07-30T00:00:01+00:00",
        "message_id": str(bar_index),
        "subscription_name": "sub",
        "data_json": json.dumps(payload),
        "attributes_json": json.dumps({"content_type": "application/json"}),
    }


class FakeQueryJob:
    def __init__(self, rows):
        self._rows = rows

    def result(self):
        return self._rows


class FakeBigQueryClient:
    def __init__(self, rows):
        self.rows = rows
        self.calls = []

    def query(self, query, job_config=None):
        self.calls.append((query, job_config))
        return FakeQueryJob(self.rows)


class FakeBlob:
    def __init__(self, recorder, name):
        self.recorder = recorder
        self.name = name

    def upload_from_string(self, text, content_type=None):
        self.recorder.append((self.name, text, content_type))


class FakeBucket:
    def __init__(self, recorder):
        self.recorder = recorder

    def blob(self, name):
        return FakeBlob(self.recorder, name)


class FakeStorageClient:
    def __init__(self):
        self.uploads = []

    def bucket(self, name):
        self.bucket_name = name
        return FakeBucket(self.uploads)


def config(**overrides):
    base = {
        "analysis_date": date(2026, 7, 30),
        "symbol": "USDJPY",
        "project_id": "alterf",
        "bq_dataset": "tradingview_data",
        "bq_table": "tradingview_alerts_raw",
        "gcs_bucket": "alterf-trading-analysis-data",
        "dry_run": False,
    }
    base.update(overrides)
    return job.Config(**base)


def test_bigquery_rows_build_existing_normaliser_payload():
    payload = job.build_payload_from_rows([make_row()], config())
    assert payload["export_schema"] == "alterf_bigquery_daily_export_v1"
    assert payload["trading_date"] == "2026-07-30"
    assert payload["timezone"] == "Europe/London"
    assert payload["utc_start_inclusive"] == "2026-07-29T23:00:00Z"
    assert payload["utc_end_exclusive"] == "2026-07-30T23:00:00Z"
    assert payload["symbol"] == "USDJPY"
    assert payload["record_count"] == 1
    assert payload["records"][0]["_bq_metadata"]["attributes"] == {"content_type": "application/json"}


def test_runner_only_calls_existing_normalise_payload():
    seen = {}

    def fake_normaliser(payload):
        seen["payload"] = payload
        return normaliser_result()

    result = job.run(config(dry_run=True), bigquery_client=FakeBigQueryClient([make_row()]), normaliser=fake_normaliser)
    assert seen["payload"]["records"][0]["symbol"] == "USDJPY"
    assert result["output_columns"] == len(job.CSV_COLUMNS)


def test_gcs_object_paths_are_correct():
    paths = job.object_paths(config())
    assert paths.historical_csv == "normalized/2026/07/30/2026-07-30_USDJPY_analysis.csv"
    assert paths.latest_csv == "latest/USDJPY_analysis.csv"
    assert paths.ready_manifest == "latest/USDJPY_READY.json"


def test_upload_order_historical_latest_ready():
    storage = FakeStorageClient()
    output = job.run(config(), bigquery_client=FakeBigQueryClient([make_row()]), storage_client=storage, normaliser=lambda payload: normaliser_result())
    assert [upload[0] for upload in storage.uploads] == [
        "normalized/2026/07/30/2026-07-30_USDJPY_analysis.csv",
        "latest/USDJPY_analysis.csv",
        "latest/USDJPY_READY.json",
    ]
    assert output["ready_manifest_uri"] == "gs://alterf-trading-analysis-data/latest/USDJPY_READY.json"


def test_zero_rows_writes_no_ready():
    storage = FakeStorageClient()
    with pytest.raises(job.DailyRunnerError, match="NO_DATA"):
        job.run(config(), bigquery_client=FakeBigQueryClient([]), storage_client=storage, normaliser=lambda payload: normaliser_result())
    assert storage.uploads == []


def test_normaliser_failure_does_not_update_latest_or_ready():
    storage = FakeStorageClient()

    def failing_normaliser(payload):
        raise RuntimeError("normaliser failed")

    with pytest.raises(RuntimeError):
        job.run(config(), bigquery_client=FakeBigQueryClient([make_row()]), storage_client=storage, normaliser=failing_normaliser)
    assert storage.uploads == []


def test_csv_upload_failure_does_not_write_ready():
    class FailingLatestBlob(FakeBlob):
        def upload_from_string(self, text, content_type=None):
            if self.name == "latest/USDJPY_analysis.csv":
                raise RuntimeError("upload failed")
            super().upload_from_string(text, content_type)

    class FailingBucket(FakeBucket):
        def blob(self, name):
            return FailingLatestBlob(self.recorder, name)

    class FailingStorage(FakeStorageClient):
        def bucket(self, name):
            return FailingBucket(self.uploads)

    storage = FailingStorage()
    with pytest.raises(RuntimeError):
        job.run(config(), bigquery_client=FakeBigQueryClient([make_row()]), storage_client=storage, normaliser=lambda payload: normaliser_result())
    assert [upload[0] for upload in storage.uploads] == ["normalized/2026/07/30/2026-07-30_USDJPY_analysis.csv"]


def test_manual_argument_parsing(monkeypatch):
    monkeypatch.delenv("ANALYSIS_DATE", raising=False)
    monkeypatch.delenv("SYMBOL", raising=False)
    parsed = job.parse_args(["--analysis-date", "2026-07-30", "--symbol", "USDJPY"])
    assert parsed.analysis_date == date(2026, 7, 30)
    assert parsed.symbol == "USDJPY"
    assert parsed.project_id == "alterf"


def test_default_date_uses_previous_complete_london_calendar_day():
    now = datetime(2026, 8, 3, 0, 30, tzinfo=UTC)
    assert job.previous_complete_london_day(now) == date(2026, 8, 2)


def test_bigquery_query_uses_parameters_not_interpolated_symbol_or_dates():
    query = job.build_query("alterf", "tradingview_data", "tradingview_alerts_raw")
    assert "@symbol" in query
    assert "@utc_start" in query
    assert "@utc_end" in query
    assert "publish_time >= @utc_start" in query
    assert "publish_time < @utc_end" in query
    assert "USDJPY" not in query
    assert "2026-07-30" not in query


def test_bigquery_query_job_config_has_expected_parameters(monkeypatch):
    created = []

    class FakeBQ:
        class ScalarQueryParameter:
            def __init__(self, name, type_, value):
                self.name = name
                self.type_ = type_
                self.value = value

        class QueryJobConfig:
            def __init__(self, query_parameters):
                self.query_parameters = query_parameters
                created.extend(query_parameters)

    start, end = job.london_day_window(date(2026, 7, 30))
    config_obj = job.build_query_job_config(FakeBQ, "USDJPY", start, end)
    assert [param.name for param in config_obj.query_parameters] == ["symbol", "utc_start", "utc_end"]
    assert created[0].value == "USDJPY"


def test_symbol_mismatch_fails():
    with pytest.raises(job.DailyRunnerError, match="Symbol mismatch"):
        job.build_payload_from_rows([make_row(symbol="EURUSD")], config())


def test_existing_july_30_raw_bq_fixture_roundtrips_to_288_rows_and_70_columns():
    raw_rows = json.loads(RAW_BQ_ROWS.read_text())
    payload = job.build_payload_from_rows(raw_rows, config())
    result = job.normalise_payload(payload)
    row_count, column_count = job.validate_normalised_output(result)
    assert payload["record_count"] == 288
    assert payload["utc_start_inclusive"] == "2026-07-29T23:00:00Z"
    assert payload["utc_end_exclusive"] == "2026-07-30T23:00:00Z"
    assert row_count == 288
    assert column_count == 70
    assert result.summary["output_row_count"] == 288
    assert result.summary["output_column_count"] == 70


def test_safe_error_message_redacts_secret_like_values_and_caps_length():
    message = job.safe_error_message(RuntimeError("token=abc123 password:supersecret\n" + ("x" * 800)))
    assert "abc123" not in message
    assert "supersecret" not in message
    assert "[REDACTED]" in message
    assert "\n" not in message
    assert len(message) <= 500
