#!/usr/bin/env python3
"""Experimental Alpha Vantage news inspection for USDJPY daily analysis.

This script only fetches and previews raw news data. It does not score sources,
generate the final daily report, modify the fixed YAML schema, or place trades.
"""

from __future__ import annotations

import csv
import json
import sys
import time
import urllib.parse
import urllib.request
from argparse import ArgumentParser, Namespace
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SECRETS_PATH = Path("/Users/avislai/Documents/.key/.env_DMA")
RAW_DIR = PROJECT_ROOT / "output" / "raw"
LOG_DIR = PROJECT_ROOT / "output" / "logs"

ALPHA_VANTAGE_URL = "https://www.alphavantage.co/query"
RELEVANCE_KEYWORDS = (
    "usd",
    "dollar",
    "dxy",
    "yen",
    "jpy",
    "boj",
    "bank of japan",
    "fed",
    "federal reserve",
    "fomc",
    "treasury",
    "treasuries",
    "yield",
    "yields",
    "rates",
    "inflation",
    "cpi",
    "payrolls",
    "jobs",
    "unemployment",
    "claims",
    "risk-off",
    "risk-on",
)

ALLOWED_QUERIES = (
    "economy_monetary",
    "economy_macro",
    "financial_markets",
)
API_FAILURE_FIELDS = ("Information", "Note", "Error Message")


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
        description="Run one Alpha Vantage NEWS_SENTIMENT inspection query.",
    )
    parser.add_argument(
        "--query",
        choices=ALLOWED_QUERIES,
        default="economy_monetary",
        help="Single Alpha Vantage news topic to test.",
    )
    return parser.parse_args()


def build_query_params(topic: str) -> dict[str, str]:
    return {
        "function": "NEWS_SENTIMENT",
        "topics": topic,
        "limit": "50",
    }


def fetch_news(api_key: str, params: dict[str, str]) -> dict[str, Any]:
    params = {
        **params,
        "apikey": api_key,
    }
    url = f"{ALPHA_VANTAGE_URL}?{urllib.parse.urlencode(params)}"

    request = urllib.request.Request(
        url,
        headers={"User-Agent": "Daily-Market-Analysis-AlphaVantage-Test/0.1"},
    )

    with urllib.request.urlopen(request, timeout=30) as response:
        payload = response.read().decode("utf-8")

    return json.loads(payload)


def api_failure_message(data: dict[str, Any]) -> Optional[str]:
    messages: list[str] = []
    for field in API_FAILURE_FIELDS:
        value = data.get(field)
        if value:
            messages.append(f"{field}: {value}")

    if messages:
        return "\n".join(messages)

    return None


def flatten_topics(item: dict[str, Any]) -> str:
    topics = item.get("topics") or []
    if not isinstance(topics, list):
        return ""

    names: list[str] = []
    for topic in topics:
        if isinstance(topic, dict):
            name = str(topic.get("topic", "")).strip()
            if name:
                names.append(name)

    return "; ".join(names)


def keyword_hits(item: dict[str, Any]) -> int:
    text = " ".join(str(item.get(field, "")) for field in ("title", "summary")).lower()
    return sum(text.count(keyword) for keyword in RELEVANCE_KEYWORDS)


def relevance_bucket(hit_count: int) -> str:
    if hit_count >= 3:
        return "high"
    if hit_count >= 1:
        return "medium"
    return "low"


def relevance_summary(items: list[dict[str, Any]]) -> dict[str, Any]:
    counts = {"high": 0, "medium": 0, "low": 0}
    ranked_items: list[tuple[int, str, str]] = []

    for item in items:
        hits = keyword_hits(item)
        bucket = relevance_bucket(hits)
        counts[bucket] += 1
        title = str(item.get("title", "")).strip()
        if title and bucket in {"high", "medium"}:
            ranked_items.append((hits, bucket, title))

    ranked_items.sort(key=lambda row: (-row[0], row[2].lower()))

    return {
        "counts": counts,
        "top_titles": [title for _, _, title in ranked_items[:5]],
    }


def write_preview_csv(
    items: list[dict[str, Any]],
    fetched_at_utc: str,
    query_name: str,
    output_path: Path,
) -> None:
    columns = [
        "fetched_at_utc",
        "query_name",
        "title",
        "url",
        "time_published",
        "source",
        "summary",
        "topics",
        "overall_sentiment_score",
        "overall_sentiment_label",
        "keyword_hits",
        "relevance_bucket",
        "is_usdjpy_relevant",
    ]

    with output_path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=columns)
        writer.writeheader()

        for item in items:
            hits = keyword_hits(item)
            bucket = relevance_bucket(hits)
            writer.writerow(
                {
                    "fetched_at_utc": fetched_at_utc,
                    "query_name": query_name,
                    "title": item.get("title", ""),
                    "url": item.get("url", ""),
                    "time_published": item.get("time_published", ""),
                    "source": item.get("source", ""),
                    "summary": item.get("summary", ""),
                    "topics": flatten_topics(item),
                    "overall_sentiment_score": item.get("overall_sentiment_score", ""),
                    "overall_sentiment_label": item.get("overall_sentiment_label", ""),
                    "keyword_hits": hits,
                    "relevance_bucket": bucket,
                    "is_usdjpy_relevant": str(bucket in {"high", "medium"}).lower(),
                }
            )


def write_error_summary(
    output_path: Path,
    *,
    fetched_at_utc: str,
    query_name: str,
    params: dict[str, str],
    message: str,
    raw_output: Optional[Path] = None,
) -> None:
    lines = [
        "Alpha Vantage API failure summary",
        f"fetched_at_utc: {fetched_at_utc}",
        f"query_name: {query_name}",
        f"query_params: {urllib.parse.urlencode(params)}",
        f"message: {message}",
    ]
    if raw_output:
        lines.append(f"raw_output: {raw_output}")

    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    queries = [args.query]

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

    print("Alpha Vantage News & Sentiment inspection complete.")

    for index, query_name in enumerate(queries):
        if index > 0:
            time.sleep(1)

        params = build_query_params(query_name)
        raw_output = RAW_DIR / f"alpha_vantage_{query_name}_{timestamp}.json"
        preview_output = LOG_DIR / f"alpha_vantage_preview_{query_name}_{timestamp}.csv"
        error_output = LOG_DIR / f"alpha_vantage_error_{query_name}_{timestamp}.txt"

        print(f"Query: {query_name}")
        print(f"Query parameters: {urllib.parse.urlencode(params)}")

        try:
            data = fetch_news(api_key, params)
        except Exception as exc:
            message = f"Request failed: {exc}"
            write_error_summary(
                error_output,
                fetched_at_utc=fetched_at_utc,
                query_name=query_name,
                params=params,
                message=message,
            )
            print(f"API failure: {message}")
            print(f"Error summary: {error_output}")
            return 1

        raw_output.write_text(
            json.dumps(data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

        failure_message = api_failure_message(data)
        if failure_message:
            write_error_summary(
                error_output,
                fetched_at_utc=fetched_at_utc,
                query_name=query_name,
                params=params,
                message=failure_message,
                raw_output=raw_output,
            )
            print("API failure returned by Alpha Vantage.")
            print(f"Raw output: {raw_output}")
            print(f"Error summary: {error_output}")
            return 1

        feed = data.get("feed", [])
        if not isinstance(feed, list):
            feed = []

        items = [item for item in feed if isinstance(item, dict)]
        write_preview_csv(items, fetched_at_utc, query_name, preview_output)

        summary = relevance_summary(items)
        relevance_counts = summary["counts"]

        print(f"Total items: {len(items)}")
        print(f"High relevance count: {relevance_counts['high']}")
        print(f"Medium relevance count: {relevance_counts['medium']}")
        print(f"Low relevance count: {relevance_counts['low']}")
        print("Top 5 relevant titles:")
        for title in summary["top_titles"]:
            print(f"- {title}")
        if not summary["top_titles"]:
            print("- None")
        print(f"Raw output: {raw_output}")
        print(f"Preview CSV: {preview_output}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
