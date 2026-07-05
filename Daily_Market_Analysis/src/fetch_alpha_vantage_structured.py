#!/usr/bin/env python3
"""Inspect Alpha Vantage structured data for USDJPY daily analysis.

This script is for structured data only. It does not revisit rejected
NEWS_SENTIMENT economy tests, fetch Twelve Data endpoints, generate the final
daily report, modify the fixed YAML schema, or add trading logic.
"""

from __future__ import annotations

import csv
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from argparse import ArgumentParser, Namespace
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SECRETS_PATH = Path("/Users/avislai/Documents/.key/.env_DMA")
RAW_DIR = PROJECT_ROOT / "output" / "raw"
LOG_DIR = PROJECT_ROOT / "output" / "logs"

ALPHA_VANTAGE_URL = "https://www.alphavantage.co/query"
API_FAILURE_FIELDS = ("Information", "Note", "Error Message")
FX_SERIES_KEYS = {
    "fx_daily": "Time Series FX (Daily)",
    "fx_weekly": "Time Series FX (Weekly)",
}


@dataclass(frozen=True)
class QueryConfig:
    query_name: str
    params: dict[str, str]
    raw_prefix: str
    preview_prefix: str
    preview_columns: tuple[str, ...]
    category: str


QUERY_CONFIGS: dict[str, QueryConfig] = {
    "fx_daily": QueryConfig(
        query_name="fx_daily",
        params={
            "function": "FX_DAILY",
            "from_symbol": "USD",
            "to_symbol": "JPY",
            "outputsize": "compact",
        },
        raw_prefix="av_fx_daily",
        preview_prefix="av_preview_fx_daily",
        preview_columns=("fetched_at_utc", "date", "open", "high", "low", "close"),
        category="fx",
    ),
    "fx_weekly": QueryConfig(
        query_name="fx_weekly",
        params={
            "function": "FX_WEEKLY",
            "from_symbol": "USD",
            "to_symbol": "JPY",
        },
        raw_prefix="av_fx_weekly",
        preview_prefix="av_preview_fx_weekly",
        preview_columns=("fetched_at_utc", "date", "open", "high", "low", "close"),
        category="fx",
    ),
    "treasury_yield_10y": QueryConfig(
        query_name="treasury_yield_10y",
        params={
            "function": "TREASURY_YIELD",
            "interval": "daily",
            "maturity": "10year",
        },
        raw_prefix="av_ty10_daily",
        preview_prefix="av_preview_ty10_daily",
        preview_columns=(
            "fetched_at_utc",
            "date",
            "value",
            "interval",
            "maturity",
        ),
        category="economic",
    ),
    "treasury_yield_2y": QueryConfig(
        query_name="treasury_yield_2y",
        params={
            "function": "TREASURY_YIELD",
            "interval": "daily",
            "maturity": "2year",
        },
        raw_prefix="av_ty2_daily",
        preview_prefix="av_preview_ty2_daily",
        preview_columns=(
            "fetched_at_utc",
            "date",
            "value",
            "interval",
            "maturity",
        ),
        category="economic",
    ),
    "fed_funds": QueryConfig(
        query_name="fed_funds",
        params={
            "function": "FEDERAL_FUNDS_RATE",
            "interval": "daily",
        },
        raw_prefix="av_fedfunds_daily",
        preview_prefix="av_preview_fedfunds_daily",
        preview_columns=("fetched_at_utc", "date", "value", "interval"),
        category="economic",
    ),
    "cpi": QueryConfig(
        query_name="cpi",
        params={
            "function": "CPI",
            "interval": "monthly",
        },
        raw_prefix="av_cpi_monthly",
        preview_prefix="av_preview_cpi_monthly",
        preview_columns=("fetched_at_utc", "date", "value", "interval"),
        category="economic",
    ),
    "inflation": QueryConfig(
        query_name="inflation",
        params={"function": "INFLATION"},
        raw_prefix="av_inflation",
        preview_prefix="av_preview_inflation",
        preview_columns=("fetched_at_utc", "date", "value"),
        category="economic",
    ),
    "unemployment": QueryConfig(
        query_name="unemployment",
        params={"function": "UNEMPLOYMENT"},
        raw_prefix="av_unemployment",
        preview_prefix="av_preview_unemployment",
        preview_columns=("fetched_at_utc", "date", "value"),
        category="economic",
    ),
    "nonfarm_payroll": QueryConfig(
        query_name="nonfarm_payroll",
        params={"function": "NONFARM_PAYROLL"},
        raw_prefix="av_nfp",
        preview_prefix="av_preview_nfp",
        preview_columns=("fetched_at_utc", "date", "value"),
        category="economic",
    ),
}


def load_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key:
            values[key] = value

    return values


def parse_args() -> Namespace:
    parser = ArgumentParser(
        description="Run one Alpha Vantage structured-data inspection query.",
    )
    parser.add_argument(
        "--query",
        choices=tuple(QUERY_CONFIGS.keys()),
        help="Single Alpha Vantage structured-data query to run.",
    )
    return parser.parse_args()


def print_available_queries() -> None:
    print("Available Alpha Vantage structured-data queries:")
    for query_name in QUERY_CONFIGS:
        print(f"- {query_name}")
    print("Run one query at a time with: --query <query_name>")


def decode_json_response(payload: str, http_status: int) -> dict[str, Any]:
    try:
        data = json.loads(payload)
    except json.JSONDecodeError:
        return {
            "Error Message": "Alpha Vantage returned a non-JSON response.",
            "http_status": http_status,
            "raw_text": payload,
        }

    if isinstance(data, dict):
        return data

    return {
        "Error Message": "Alpha Vantage returned an unexpected JSON shape.",
        "http_status": http_status,
        "raw_response": data,
    }


def fetch_structured_data(api_key: str, params: dict[str, str]) -> dict[str, Any]:
    request_params = {
        **params,
        "apikey": api_key,
    }
    url = f"{ALPHA_VANTAGE_URL}?{urllib.parse.urlencode(request_params)}"
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Daily-Market-Analysis-AlphaVantage-Structured-Test/0.1",
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = response.read().decode("utf-8", errors="replace")
            return decode_json_response(payload, response.status)
    except urllib.error.HTTPError as exc:
        payload = exc.read().decode("utf-8", errors="replace")
        return decode_json_response(payload, exc.code)


def api_failure_message(data: dict[str, Any]) -> Optional[str]:
    messages: list[str] = []
    for field in API_FAILURE_FIELDS:
        value = data.get(field)
        if value:
            messages.append(f"{field}: {value}")

    if messages:
        return "\n".join(messages)

    return None


def extract_fx_rows(
    data: dict[str, Any],
    query_name: str,
    fetched_at_utc: str,
) -> list[dict[str, str]]:
    series_key = FX_SERIES_KEYS[query_name]
    series = data.get(series_key)
    if not isinstance(series, dict):
        return []

    rows: list[dict[str, str]] = []
    for date in sorted(series.keys(), reverse=True):
        values = series.get(date)
        if not isinstance(values, dict):
            continue

        rows.append(
            {
                "fetched_at_utc": fetched_at_utc,
                "date": date,
                "open": str(values.get("1. open", "")),
                "high": str(values.get("2. high", "")),
                "low": str(values.get("3. low", "")),
                "close": str(values.get("4. close", "")),
            }
        )

    return rows


def extract_indicator_rows(
    data: dict[str, Any],
    config: QueryConfig,
    fetched_at_utc: str,
) -> list[dict[str, str]]:
    values = data.get("data")
    if not isinstance(values, list):
        return []

    rows: list[dict[str, str]] = []
    for item in values:
        if not isinstance(item, dict):
            continue

        row = {
            "fetched_at_utc": fetched_at_utc,
            "date": str(item.get("date", "")),
            "value": str(item.get("value", "")),
        }
        if "interval" in config.preview_columns:
            row["interval"] = config.params.get("interval", "")
        if "maturity" in config.preview_columns:
            row["maturity"] = config.params.get("maturity", "")
        rows.append(row)

    return rows


def extract_preview_rows(
    data: dict[str, Any],
    config: QueryConfig,
    fetched_at_utc: str,
) -> list[dict[str, str]]:
    if config.category == "fx":
        return extract_fx_rows(data, config.query_name, fetched_at_utc)

    return extract_indicator_rows(data, config, fetched_at_utc)


def write_preview_csv(
    rows: list[dict[str, str]],
    columns: tuple[str, ...],
    output_path: Path,
) -> None:
    with output_path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=columns)
        writer.writeheader()
        writer.writerows(rows)


def latest_value(rows: list[dict[str, str]], field: str) -> str:
    if not rows:
        return ""
    return rows[0].get(field, "")


def print_success_summary(
    config: QueryConfig,
    rows: list[dict[str, str]],
    raw_output: Path,
    preview_output: Path,
) -> None:
    print("Alpha Vantage structured-data inspection complete.")
    print(f"query name: {config.query_name}")
    print(f"number of rows returned: {len(rows)}")
    print(f"latest date: {latest_value(rows, 'date')}")
    if config.category == "fx":
        print(f"latest close: {latest_value(rows, 'close')}")
    else:
        print(f"latest value: {latest_value(rows, 'value')}")
    print(f"raw output path: {raw_output}")
    print(f"preview CSV path: {preview_output}")


def main() -> int:
    args = parse_args()
    if not args.query:
        print_available_queries()
        return 0

    config = QUERY_CONFIGS[args.query]

    if not SECRETS_PATH.exists():
        print(f"Missing secrets file: {SECRETS_PATH}")
        return 1

    try:
        env = load_env(SECRETS_PATH)
    except PermissionError:
        print(f"Unable to read secrets file: {SECRETS_PATH}")
        return 1

    api_key = env.get("ALPHA_VANTAGE_API_KEY", "").strip()
    if not api_key:
        print("Missing ALPHA_VANTAGE_API_KEY in secrets file")
        return 1

    fetched_at = datetime.now(timezone.utc)
    fetched_at_utc = fetched_at.isoformat(timespec="seconds").replace("+00:00", "Z")
    timestamp = fetched_at.strftime("%Y%m%d_%H%M%S")

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    raw_output = RAW_DIR / f"{config.raw_prefix}_{timestamp}.json"
    preview_output = LOG_DIR / f"{config.preview_prefix}_{timestamp}.csv"

    try:
        data = fetch_structured_data(api_key, config.params)
    except Exception as exc:
        print(f"Alpha Vantage structured-data inspection failed: {exc}")
        return 1

    raw_output.write_text(
        json.dumps(data, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    failure_message = api_failure_message(data)
    if failure_message:
        print("Alpha Vantage structured-data inspection failed or was rate-limited.")
        print(f"query name: {config.query_name}")
        print(f"reason: {failure_message}")
        print(f"raw output path: {raw_output}")
        return 1

    rows = extract_preview_rows(data, config, fetched_at_utc)
    if not rows:
        print("Alpha Vantage structured-data inspection failed.")
        print(f"query name: {config.query_name}")
        print("reason: response did not include expected structured rows")
        print(f"raw output path: {raw_output}")
        return 1

    write_preview_csv(rows, config.preview_columns, preview_output)
    print_success_summary(config, rows, raw_output, preview_output)

    return 0


if __name__ == "__main__":
    sys.exit(main())
