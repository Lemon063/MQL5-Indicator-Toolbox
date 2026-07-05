#!/usr/bin/env python3
"""Inspect NewsAPI.org market headlines for Daily Market Analysis.

This script makes one NewsAPI request and extracts headline-level market
context only. It does not follow article links, scrape article bodies, generate
the final daily report, modify the fixed YAML schema, or add trading logic.
"""

from __future__ import annotations

import csv
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from argparse import ArgumentParser, Namespace
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SECRETS_PATH = Path("/Users/avislai/Documents/.key/.env_DMA")
RAW_DIR = PROJECT_ROOT / "output" / "raw"
LOG_DIR = PROJECT_ROOT / "output" / "logs"

EVERYTHING_ENDPOINT = "https://newsapi.org/v2/everything"
TOP_HEADLINES_ENDPOINT = "https://newsapi.org/v2/top-headlines"
BROAD_MARKET_QUERY = (
    '"stock market" OR "Wall Street" OR "S&P 500" OR "Nasdaq" OR '
    '"Treasury yields" OR "Federal Reserve" OR "oil prices" OR "dollar" OR "yen"'
)
USER_AGENT = (
    "Daily-Market-Analysis-NewsAPI-Inspection/0.1 "
    "(personal market headline preview; contact: local-user)"
)

CSV_COLUMNS = (
    "fetched_at_utc",
    "source_name",
    "section",
    "published_time",
    "headline",
    "url",
    "description_or_summary",
    "tags",
)

TAG_KEYWORDS = {
    "panic": ("panic", "crash", "selloff", "sell-off", "plunge", "turmoil"),
    "risk_on": ("risk-on", "rally", "stocks rise", "stocks gain", "surge"),
    "risk_off": ("risk-off", "havens", "safe haven", "stocks fall", "stocks drop"),
    "equities": ("stocks", "equities", "s&p", "nasdaq", "dow"),
    "tech": ("tech", "technology", "software"),
    "ai": (" ai ", "artificial intelligence", "openai", "chatgpt"),
    "semiconductors": ("chip", "chips", "semiconductor", "nvidia", "amd", "tsmc"),
    "banks": ("bank", "banks", "lender", "lenders"),
    "credit": ("credit", "debt", "default", "loan", "loans", "spread"),
    "bonds": ("bond", "bonds", "treasury", "treasuries"),
    "yields": ("yield", "yields"),
    "oil": ("oil", "crude", "brent", "wti"),
    "commodities": ("commodity", "commodities", "gold", "copper", "silver"),
    "dollar": ("dollar", "usd", "dxy"),
    "yen": ("yen", "jpy"),
    "fed": ("fed", "federal reserve", "fomc", "powell"),
    "inflation": ("inflation", "cpi", "pce", "prices"),
}


@dataclass(frozen=True)
class Headline:
    fetched_at_utc: str
    source_name: str
    section: str
    published_time: str
    headline: str
    url: str
    description_or_summary: str
    tags: str


def parse_args() -> Namespace:
    parser = ArgumentParser(description="Run one NewsAPI.org market headline inspection.")
    parser.add_argument(
        "--mode",
        choices=("everything", "top_headlines_business"),
        default="everything",
        help="NewsAPI endpoint mode to inspect.",
    )
    return parser.parse_args()


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


def utc_stamp() -> tuple[str, str]:
    now = datetime.now(timezone.utc)
    return now.strftime("%Y-%m-%dT%H:%M:%SZ"), now.strftime("%Y%m%d_%H%M%S")


def normalize_spaces(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def normalize_key(headline: str, url: str) -> tuple[str, str]:
    normalized_headline = re.sub(r"\W+", " ", headline.casefold()).strip()
    return normalized_headline, url.strip()


def scalar_text(value: Any) -> str:
    if value is None:
        return ""
    return normalize_spaces(str(value))


def keyword_tags(*parts: str) -> str:
    padded_text = f" {' '.join(parts).casefold()} "
    tags = [
        tag
        for tag, keywords in TAG_KEYWORDS.items()
        if any(keyword in padded_text for keyword in keywords)
    ]
    return "; ".join(tags)


def request_config(mode: str) -> tuple[str, dict[str, str]]:
    if mode == "top_headlines_business":
        return TOP_HEADLINES_ENDPOINT, {
            "country": "us",
            "category": "business",
            "pageSize": "50",
            "page": "1",
        }

    return EVERYTHING_ENDPOINT, {
        "q": BROAD_MARKET_QUERY,
        "searchIn": "title,description",
        "language": "en",
        "sortBy": "publishedAt",
        "pageSize": "50",
        "page": "1",
    }


def build_request(endpoint: str, params: dict[str, str], api_key: str) -> urllib.request.Request:
    url = f"{endpoint}?{urllib.parse.urlencode(params)}"
    return urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "X-Api-Key": api_key,
        },
    )


def fetch(request: urllib.request.Request) -> tuple[int, str]:
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = response.read().decode("utf-8", errors="replace")
            return response.status, payload
    except urllib.error.HTTPError as exc:
        payload = exc.read().decode("utf-8", errors="replace")
        return exc.code, payload
    except urllib.error.URLError as exc:
        return 0, json.dumps(
            {
                "status": "error",
                "code": "request_failed",
                "message": f"Request failed before an HTTP response was received: {exc}",
            }
        )


def decode_json(payload: str) -> dict[str, Any]:
    try:
        data = json.loads(payload)
    except json.JSONDecodeError:
        return {
            "status": "error",
            "code": "non_json_response",
            "message": "NewsAPI returned a non-JSON response.",
            "raw_text": payload,
        }

    if isinstance(data, dict):
        return data

    return {
        "status": "error",
        "code": "unexpected_json_shape",
        "message": "NewsAPI returned an unexpected JSON shape.",
        "raw_response": data,
    }


def parse_headlines(data: dict[str, Any], fetched_at_utc: str) -> list[Headline]:
    articles = data.get("articles")
    if not isinstance(articles, list):
        return []

    headlines: list[Headline] = []
    seen: set[tuple[str, str]] = set()
    for article in articles:
        if not isinstance(article, dict):
            continue

        headline = scalar_text(article.get("title"))
        url = scalar_text(article.get("url"))
        if not headline:
            continue

        key = normalize_key(headline, url)
        if key in seen:
            continue
        seen.add(key)

        source = article.get("source")
        source_name = ""
        if isinstance(source, dict):
            source_name = scalar_text(source.get("name"))

        summary = scalar_text(article.get("description"))
        headlines.append(
            Headline(
                fetched_at_utc=fetched_at_utc,
                source_name=source_name,
                section="NewsAPI market headlines",
                published_time=scalar_text(article.get("publishedAt")),
                headline=headline,
                url=url,
                description_or_summary=summary,
                tags=keyword_tags(headline, summary),
            )
        )

    return headlines


def write_raw_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def write_preview_csv(path: Path, headlines: list[Headline]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=CSV_COLUMNS)
        writer.writeheader()
        for item in headlines:
            writer.writerow(
                {
                    "fetched_at_utc": item.fetched_at_utc,
                    "source_name": item.source_name,
                    "section": item.section,
                    "published_time": item.published_time,
                    "headline": item.headline,
                    "url": item.url,
                    "description_or_summary": item.description_or_summary,
                    "tags": item.tags,
                }
            )


def print_summary(
    *,
    mode: str,
    http_status: int,
    total_results: Any,
    headlines: list[Headline],
    raw_path: Path,
    csv_path: Path,
) -> None:
    print(f"Mode: {mode}")
    print(f"HTTP status: {http_status}")
    print(f"totalResults: {total_results if total_results is not None else ''}")
    print(f"Headlines found: {len(headlines)}")
    print("First 10 headlines:")
    for index, item in enumerate(headlines[:10], start=1):
        print(f"{index}. {item.headline}")
    print(f"Raw output path: {raw_path}")
    print(f"Preview CSV path: {csv_path}")


def main() -> int:
    args = parse_args()
    fetched_at_utc, file_stamp = utc_stamp()
    raw_path = RAW_DIR / f"newsapi_market_{file_stamp}.json"
    csv_path = LOG_DIR / f"newsapi_preview_market_{file_stamp}.csv"

    env = load_env(SECRETS_PATH)
    api_key = env.get("NEWSAPI_API_KEY", "")
    if not api_key:
        print(f"Missing NEWSAPI_API_KEY in {SECRETS_PATH}. No request made.")
        return 1

    endpoint, params = request_config(args.mode)
    request = build_request(endpoint, params, api_key)
    status, payload = fetch(request)
    data = decode_json(payload)
    write_raw_json(raw_path, data)

    if data.get("status") == "error":
        print(f"NewsAPI error code: {data.get('code', '')}")
        print(f"NewsAPI error message: {data.get('message', '')}")
        print_summary(
            mode=args.mode,
            http_status=status,
            total_results=data.get("totalResults"),
            headlines=[],
            raw_path=raw_path,
            csv_path=csv_path,
        )
        return 1

    headlines = parse_headlines(data, fetched_at_utc)
    write_preview_csv(csv_path, headlines)
    print_summary(
        mode=args.mode,
        http_status=status,
        total_results=data.get("totalResults"),
        headlines=headlines,
        raw_path=raw_path,
        csv_path=csv_path,
    )
    return 0 if headlines else 1


if __name__ == "__main__":
    sys.exit(main())
