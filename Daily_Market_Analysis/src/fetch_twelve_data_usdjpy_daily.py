#!/usr/bin/env python3
"""Inspect Twelve Data USDJPY daily OHLC data only.

This script fetches and previews raw Twelve Data daily OHLC data for USDJPY.
It does not fetch weekly data, implement Alpha Vantage structured data,
generate the final daily report, modify the fixed YAML schema, or add trading
logic.
"""

from __future__ import annotations

import csv
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SECRETS_PATH = Path("/Users/avislai/Documents/.key/.env_DMA")
RAW_DIR = PROJECT_ROOT / "output" / "raw"
LOG_DIR = PROJECT_ROOT / "output" / "logs"

TWELVE_DATA_TIME_SERIES_URL = "https://api.twelvedata.com/time_series"
SYMBOL = "USD/JPY"
DISPLAY_SYMBOL = "USDJPY"
INTERVAL = "1day"
OUTPUT_SIZE = "100"
API_FAILURE_STATUSES = {"error"}
API_FAILURE_FIELDS = ("code", "message", "status")


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


def build_query_params() -> dict[str, str]:
    return {
        "symbol": SYMBOL,
        "interval": INTERVAL,
        "outputsize": OUTPUT_SIZE,
    }


def decode_json_response(payload: str, http_status: int) -> dict[str, Any]:
    try:
        data = json.loads(payload)
    except json.JSONDecodeError:
        return {
            "status": "error",
            "code": http_status,
            "message": "Twelve Data returned a non-JSON response.",
            "raw_text": payload,
        }

    if isinstance(data, dict):
        return data

    return {
        "status": "error",
        "code": http_status,
        "message": "Twelve Data returned an unexpected JSON shape.",
        "raw_response": data,
    }


def fetch_time_series(api_key: str, params: dict[str, str]) -> dict[str, Any]:
    request_params = {
        **params,
        "apikey": api_key,
    }
    url = f"{TWELVE_DATA_TIME_SERIES_URL}?{urllib.parse.urlencode(request_params)}"
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "Daily-Market-Analysis-TwelveData-Inspection/0.1"},
    )

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = response.read().decode("utf-8", errors="replace")
            return decode_json_response(payload, response.status)
    except urllib.error.HTTPError as exc:
        payload = exc.read().decode("utf-8", errors="replace")
        return decode_json_response(payload, exc.code)


def api_failure_message(data: dict[str, Any]) -> Optional[str]:
    status = str(data.get("status", "")).strip().lower()
    if status in API_FAILURE_STATUSES:
        parts = []
        for field in API_FAILURE_FIELDS:
            value = data.get(field)
            if value not in (None, ""):
                parts.append(f"{field}: {value}")
        return "; ".join(parts) or "Twelve Data returned an error status."

    values = data.get("values")
    if not isinstance(values, list):
        return "Twelve Data response did not include a values list."

    return None


def normalise_candles(data: dict[str, Any]) -> list[dict[str, Any]]:
    values = data.get("values")
    if not isinstance(values, list):
        return []

    candles: list[dict[str, Any]] = []
    for item in values:
        if isinstance(item, dict):
            candles.append(item)

    return candles


def write_preview_csv(
    candles: list[dict[str, Any]],
    fetched_at_utc: str,
    output_path: Path,
) -> None:
    columns = [
        "fetched_at_utc",
        "datetime",
        "open",
        "high",
        "low",
        "close",
        "volume",
    ]

    with output_path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=columns)
        writer.writeheader()

        for candle in candles:
            writer.writerow(
                {
                    "fetched_at_utc": fetched_at_utc,
                    "datetime": candle.get("datetime", ""),
                    "open": candle.get("open", ""),
                    "high": candle.get("high", ""),
                    "low": candle.get("low", ""),
                    "close": candle.get("close", ""),
                    "volume": candle.get("volume", ""),
                }
            )


def main() -> int:
    if not SECRETS_PATH.exists():
        print(f"Missing secrets file: {SECRETS_PATH}")
        return 1

    try:
        env = load_env(SECRETS_PATH)
    except PermissionError:
        print(f"Unable to read secrets file: {SECRETS_PATH}")
        return 1

    api_key = env.get("TWELVE_DATA_API_KEY", "").strip()
    if not api_key:
        print("Missing TWELVE_DATA_API_KEY in secrets file")
        return 1

    fetched_at = datetime.now(timezone.utc)
    fetched_at_utc = fetched_at.isoformat(timespec="seconds").replace("+00:00", "Z")
    timestamp = fetched_at.strftime("%Y%m%d_%H%M%S")

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    raw_output = RAW_DIR / f"td_usdjpy_daily_{timestamp}.json"
    preview_output = LOG_DIR / f"td_preview_usdjpy_daily_{timestamp}.csv"

    params = build_query_params()

    try:
        data = fetch_time_series(api_key, params)
    except Exception as exc:
        print(f"Twelve Data inspection failed before a response was returned: {exc}")
        return 1

    raw_output.write_text(
        json.dumps(data, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    failure_message = api_failure_message(data)
    if failure_message:
        print("Twelve Data inspection failed.")
        print(f"symbol: {DISPLAY_SYMBOL}")
        print(f"interval: {INTERVAL}")
        print(f"reason: {failure_message}")
        print(f"raw output path: {raw_output}")
        return 1

    candles = normalise_candles(data)
    write_preview_csv(candles, fetched_at_utc, preview_output)

    latest = candles[0] if candles else {}
    print("Twelve Data inspection complete.")
    print(f"symbol: {DISPLAY_SYMBOL}")
    print(f"interval: {INTERVAL}")
    print(f"number of candles returned: {len(candles)}")
    print(f"latest candle datetime: {latest.get('datetime', '')}")
    print(f"latest close: {latest.get('close', '')}")
    print(f"raw output path: {raw_output}")
    print(f"preview CSV path: {preview_output}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
