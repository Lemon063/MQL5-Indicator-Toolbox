#!/usr/bin/env python3
"""Daily BigQuery -> normaliser -> GCS runner for TradingView analysis CSV."""

from __future__ import annotations

import argparse
import copy
import csv
import io
import json
import os
import re
import sys
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo


NORMALISER_DIR = Path(__file__).resolve().parents[1] / "python_normaliser"
if str(NORMALISER_DIR) not in sys.path:
    sys.path.insert(0, str(NORMALISER_DIR))

from tradingview_json_to_analysis_csv import CSV_COLUMNS, normalise_payload


DEFAULT_PROJECT_ID = "alterf"
DEFAULT_BQ_DATASET = "tradingview_data"
DEFAULT_BQ_TABLE = "tradingview_alerts_raw"
DEFAULT_GCS_BUCKET = "alterf-trading-analysis-data"
LONDON_TZ = ZoneInfo("Europe/London")
IDENTIFIER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_-]*$")
CSV_CONTENT_TYPE = "text/csv; charset=utf-8"
MANIFEST_CONTENT_TYPE = "application/json"
SECRET_VALUE_RE = re.compile(
    r"(?i)(secret|webhook_secret|token|api[_-]?key|authorization|password|credential)(['\"\s:=]+)([^,'\"\s}]+)"
)


class DailyRunnerError(Exception):
    """Raised for fatal runner failures."""


@dataclass(frozen=True)
class Config:
    analysis_date: date
    symbol: str
    project_id: str
    bq_dataset: str
    bq_table: str
    gcs_bucket: str
    dry_run: bool = False


@dataclass(frozen=True)
class ObjectPaths:
    historical_csv: str
    latest_csv: str
    ready_manifest: str


def parse_args(argv: list[str] | None = None) -> Config:
    parser = argparse.ArgumentParser(description="Build daily TradingView analysis CSV from BigQuery and publish to GCS.")
    parser.add_argument("--analysis-date", help="London trading date in YYYY-MM-DD format.")
    parser.add_argument("--symbol", help="TradingView symbol, for example USDJPY.")
    parser.add_argument("--gcp-project-id", default=os.environ.get("GCP_PROJECT_ID", DEFAULT_PROJECT_ID))
    parser.add_argument("--bq-dataset", default=os.environ.get("BQ_DATASET", DEFAULT_BQ_DATASET))
    parser.add_argument("--bq-table", default=os.environ.get("BQ_TABLE", DEFAULT_BQ_TABLE))
    parser.add_argument("--gcs-bucket", default=os.environ.get("GCS_BUCKET", DEFAULT_GCS_BUCKET))
    parser.add_argument("--dry-run", action="store_true", help="Query and normalise only; do not upload anything.")
    args = parser.parse_args(argv)

    analysis_date_text = args.analysis_date or os.environ.get("ANALYSIS_DATE")
    analysis_date = parse_analysis_date(analysis_date_text) if analysis_date_text else previous_complete_london_day()
    symbol = (args.symbol or os.environ.get("SYMBOL") or "").strip().upper()
    if not symbol:
        raise DailyRunnerError("SYMBOL or --symbol is required")

    return Config(
        analysis_date=analysis_date,
        symbol=symbol,
        project_id=args.gcp_project_id,
        bq_dataset=args.bq_dataset,
        bq_table=args.bq_table,
        gcs_bucket=args.gcs_bucket,
        dry_run=args.dry_run,
    )


def parse_analysis_date(value: str) -> date:
    try:
        return date.fromisoformat(value)
    except ValueError as exc:
        raise DailyRunnerError(f"Invalid analysis date {value!r}; expected YYYY-MM-DD") from exc


def previous_complete_london_day(now: datetime | None = None) -> date:
    london_now = (now or datetime.now(LONDON_TZ)).astimezone(LONDON_TZ)
    return london_now.date() - timedelta(days=1)


def london_day_window(analysis_date: date) -> tuple[datetime, datetime]:
    start_london = datetime.combine(analysis_date, time.min, tzinfo=LONDON_TZ)
    end_london = start_london + timedelta(days=1)
    return start_london.astimezone(UTC), end_london.astimezone(UTC)


def iso_utc(value: datetime) -> str:
    return value.astimezone(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def validate_identifier(value: str, label: str) -> None:
    if not IDENTIFIER_RE.fullmatch(value):
        raise DailyRunnerError(f"Invalid {label}: {value!r}")


def table_ref(project_id: str, dataset: str, table: str) -> str:
    for value, label in ((project_id, "project_id"), (dataset, "dataset"), (table, "table")):
        validate_identifier(value, label)
    return f"`{project_id}.{dataset}.{table}`"


def build_query(project_id: str, dataset: str, table: str) -> str:
    source = table_ref(project_id, dataset, table)
    return f"""
SELECT
  CAST(publish_time AS STRING) AS publish_time,
  CAST(message_id AS STRING) AS message_id,
  CAST(subscription_name AS STRING) AS subscription_name,
  TO_JSON_STRING(data) AS data_json,
  TO_JSON_STRING(attributes) AS attributes_json
FROM {source}
WHERE JSON_VALUE(data, '$.symbol') = @symbol
  AND publish_time >= @utc_start
  AND publish_time < @utc_end
ORDER BY
  CAST(COALESCE(JSON_VALUE(data, '$.timestamp'), JSON_VALUE(data, '$.bar_time')) AS INT64) ASC,
  publish_time ASC,
  message_id ASC
""".strip()


def build_query_job_config(bigquery_module: Any, symbol: str, utc_start: datetime, utc_end: datetime) -> Any:
    return bigquery_module.QueryJobConfig(
        query_parameters=[
            bigquery_module.ScalarQueryParameter("symbol", "STRING", symbol),
            bigquery_module.ScalarQueryParameter("utc_start", "TIMESTAMP", utc_start),
            bigquery_module.ScalarQueryParameter("utc_end", "TIMESTAMP", utc_end),
        ]
    )


def parse_json_cell(value: Any, label: str) -> Any:
    if value in (None, ""):
        return {}
    parsed = value
    if isinstance(value, str):
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError as exc:
            raise DailyRunnerError(f"BigQuery row has malformed {label}") from exc
    if isinstance(parsed, str):
        try:
            parsed = json.loads(parsed)
        except json.JSONDecodeError as exc:
            raise DailyRunnerError(f"BigQuery row has malformed nested {label}") from exc
    return parsed


def row_get(row: Any, key: str) -> Any:
    if isinstance(row, dict):
        return row.get(key)
    try:
        return row[key]
    except Exception:
        return getattr(row, key, None)


def parse_ms(value: Any) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def parse_publish_time(value: Any) -> datetime | None:
    if not value:
        return None
    text = str(value).replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def sort_key(record: dict[str, Any]) -> tuple[int, float, str]:
    payload_time = parse_ms(record.get("timestamp")) or parse_ms(record.get("bar_time")) or 0
    metadata = record.get("_bq_metadata") if isinstance(record.get("_bq_metadata"), dict) else {}
    publish_dt = parse_publish_time(metadata.get("publish_time"))
    publish_key = publish_dt.timestamp() if publish_dt else 0
    return (payload_time, publish_key, str(metadata.get("message_id") or ""))


def build_payload_from_rows(rows: list[Any], config: Config) -> dict[str, Any]:
    if not rows:
        raise DailyRunnerError(f"NO_DATA: BigQuery returned 0 rows for {config.symbol} on {config.analysis_date.isoformat()}")

    records: list[dict[str, Any]] = []
    for index, row in enumerate(rows):
        payload = parse_json_cell(row_get(row, "data_json"), "data_json")
        if not isinstance(payload, dict):
            raise DailyRunnerError(f"BigQuery row {index} data_json is not a JSON object")
        attributes = parse_json_cell(row_get(row, "attributes_json"), "attributes_json")
        if not isinstance(attributes, dict):
            attributes = {"raw": attributes}
        record = copy.deepcopy(payload)
        record["_bq_metadata"] = {
            "publish_time": row_get(row, "publish_time"),
            "message_id": row_get(row, "message_id"),
            "subscription_name": row_get(row, "subscription_name"),
            "attributes": attributes,
        }
        records.append(record)

    symbols = {record.get("symbol") for record in records}
    if symbols != {config.symbol}:
        raise DailyRunnerError(f"Symbol mismatch in BigQuery results: expected {config.symbol}, observed {sorted(map(str, symbols))}")

    utc_start, utc_end = london_day_window(config.analysis_date)
    records.sort(key=sort_key)
    return {
        "export_schema": "alterf_bigquery_daily_export_v1",
        "trading_date": config.analysis_date.isoformat(),
        "timezone": "Europe/London",
        "utc_start_inclusive": iso_utc(utc_start),
        "utc_end_exclusive": iso_utc(utc_end),
        "symbol": config.symbol,
        "source_table": f"{config.project_id}.{config.bq_dataset}.{config.bq_table}",
        "exported_at_utc": iso_utc(datetime.now(UTC)),
        "record_count": len(records),
        "records": records,
    }


def fetch_bigquery_rows(config: Config, bigquery_client: Any | None = None) -> list[Any]:
    if bigquery_client is None:
        from google.cloud import bigquery

        client = bigquery.Client(project=config.project_id)
        bigquery_module = bigquery
    else:
        client = bigquery_client
        try:
            from google.cloud import bigquery as bigquery_module
        except ImportError:
            bigquery_module = _MinimalBigQueryParameters

    utc_start, utc_end = london_day_window(config.analysis_date)
    query = build_query(config.project_id, config.bq_dataset, config.bq_table)
    job_config = build_query_job_config(bigquery_module, config.symbol, utc_start, utc_end)
    return list(client.query(query, job_config=job_config).result())


def object_paths(config: Config) -> ObjectPaths:
    yyyy = f"{config.analysis_date.year:04d}"
    mm = f"{config.analysis_date.month:02d}"
    dd = f"{config.analysis_date.day:02d}"
    dated_name = f"{config.analysis_date.isoformat()}_{config.symbol}_analysis.csv"
    return ObjectPaths(
        historical_csv=f"normalized/{yyyy}/{mm}/{dd}/{dated_name}",
        latest_csv=f"latest/{config.symbol}_analysis.csv",
        ready_manifest=f"latest/{config.symbol}_READY.json",
    )


def gs_uri(bucket: str, object_name: str) -> str:
    return f"gs://{bucket}/{object_name}"


def validate_normalised_output(result: Any) -> tuple[int, int]:
    csv_text = result.csv_text
    reader = csv.reader(io.StringIO(csv_text))
    try:
        header = next(reader)
    except StopIteration as exc:
        raise DailyRunnerError("Normaliser produced empty CSV") from exc
    if header != CSV_COLUMNS:
        raise DailyRunnerError("CSV header does not match existing CSV_COLUMNS")
    output_rows = list(reader)
    row_count = len(output_rows)
    column_count = len(header)
    if row_count == 0:
        raise DailyRunnerError("Normaliser output row count is 0")
    summary_rows = result.summary.get("output_row_count")
    summary_cols = result.summary.get("output_column_count")
    if summary_rows != row_count:
        raise DailyRunnerError(f"Output rows {row_count} do not match normaliser summary {summary_rows}")
    if summary_cols != column_count:
        raise DailyRunnerError(f"Output columns {column_count} do not match normaliser summary {summary_cols}")
    return row_count, column_count


def upload_text(storage_client: Any, bucket_name: str, object_name: str, text: str, content_type: str) -> None:
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(object_name)
    blob.upload_from_string(text, content_type=content_type)


def write_outputs(config: Config, csv_text: str, row_count: int, column_count: int, storage_client: Any | None = None) -> dict[str, Any]:
    if storage_client is None:
        from google.cloud import storage

        client = storage.Client(project=config.project_id)
    else:
        client = storage_client

    paths = object_paths(config)
    historical_uri = gs_uri(config.gcs_bucket, paths.historical_csv)
    latest_uri = gs_uri(config.gcs_bucket, paths.latest_csv)
    manifest_uri = gs_uri(config.gcs_bucket, paths.ready_manifest)

    upload_text(client, config.gcs_bucket, paths.historical_csv, csv_text, CSV_CONTENT_TYPE)
    upload_text(client, config.gcs_bucket, paths.latest_csv, csv_text, CSV_CONTENT_TYPE)

    manifest = {
        "status": "READY",
        "analysis_date": config.analysis_date.isoformat(),
        "symbol": config.symbol,
        "row_count": row_count,
        "column_count": column_count,
        "csv_uri": historical_uri,
        "latest_csv_uri": latest_uri,
        "generated_at_utc": iso_utc(datetime.now(UTC)),
    }
    upload_text(
        client,
        config.gcs_bucket,
        paths.ready_manifest,
        json.dumps(manifest, sort_keys=True) + "\n",
        MANIFEST_CONTENT_TYPE,
    )
    return {"manifest": manifest, "ready_manifest_uri": manifest_uri}


class _MinimalBigQueryParameters:
    class ScalarQueryParameter:
        def __init__(self, name: str, type_: str, value: Any):
            self.name = name
            self.type_ = type_
            self.value = value

    class QueryJobConfig:
        def __init__(self, query_parameters: list[Any]):
            self.query_parameters = query_parameters


def run(config: Config, bigquery_client: Any | None = None, storage_client: Any | None = None, normaliser: Any = normalise_payload) -> dict[str, Any]:
    rows = fetch_bigquery_rows(config, bigquery_client=bigquery_client)
    payload = build_payload_from_rows(rows, config)
    result = normaliser(payload)
    row_count, column_count = validate_normalised_output(result)
    paths = object_paths(config)
    output = {
        "status": "DRY_RUN" if config.dry_run else "READY",
        "analysis_date": config.analysis_date.isoformat(),
        "symbol": config.symbol,
        "input_rows": len(rows),
        "output_rows": row_count,
        "output_columns": column_count,
        "historical_csv_uri": gs_uri(config.gcs_bucket, paths.historical_csv),
        "latest_csv_uri": gs_uri(config.gcs_bucket, paths.latest_csv),
        "ready_manifest_uri": gs_uri(config.gcs_bucket, paths.ready_manifest),
        "normaliser_summary": result.summary,
    }
    if not config.dry_run:
        output.update(write_outputs(config, result.csv_text, row_count, column_count, storage_client=storage_client))
    return output


def safe_error_message(exc: Exception) -> str:
    text = str(exc)
    text = SECRET_VALUE_RE.sub(lambda match: f"{match.group(1)}{match.group(2)}[REDACTED]", text)
    text = text.replace("\n", " ")
    if len(text) > 500:
        text = text[:497] + "..."
    return text


def main(argv: list[str] | None = None) -> int:
    try:
        config = parse_args(argv)
        summary = run(config)
    except DailyRunnerError as exc:
        print(f"ERROR: {safe_error_message(exc)}", file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"ERROR: {type(exc).__name__}: {safe_error_message(exc)}", file=sys.stderr)
        return 1
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
