#!/usr/bin/env python3
"""Inspect Finviz Elite News CSV export data for Daily Market Analysis.

This script makes one configurable Finviz Elite export request and extracts
headline-level market context only. It does not follow article links, scrape
article bodies, generate the final daily report, modify the fixed YAML schema,
or add trading logic.
"""

from __future__ import annotations

import csv
import io
import json
import re
import sys
import urllib.parse
from argparse import ArgumentParser, Namespace
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

try:
    import requests
except ImportError:  # pragma: no cover - runtime environment message
    requests = None  # type: ignore[assignment]


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SECRETS_PATH = Path("/Users/avislai/Documents/.key/.env_DMA")
RAW_DIR = PROJECT_ROOT / "output" / "raw"
LOG_DIR = PROJECT_ROOT / "output" / "logs"

USER_AGENT = (
    "Daily-Market-Analysis-Finviz-News-Export-Inspection/0.1 "
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

LIST_KEYS = ("data", "news", "articles", "items", "results")
HEADLINE_FIELDS = ("headline", "title", "name")
URL_FIELDS = ("url", "link")
SOURCE_FIELDS = ("source", "source_name", "publisher")
TIME_FIELDS = ("published_at", "publishedAt", "date", "time", "datetime")
SECTION_FIELDS = ("category", "section", "type")
SUMMARY_FIELDS = ("summary", "description", "snippet")

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


@dataclass(frozen=True)
class CsvParseResult:
    rows: list[dict[str, str]]
    delimiter: str
    headers: list[str]
    has_header: bool
    warning: str


@dataclass(frozen=True)
class DecodedPayload:
    text: str
    encoding: str
    warning: str


def parse_args() -> Namespace:
    parser = ArgumentParser(description="Run one Finviz Elite News CSV export inspection.")
    auth_group = parser.add_mutually_exclusive_group()
    auth_group.add_argument(
        "--auth-param",
        choices=("auth", "token", "api_key"),
        default="auth",
        help="Query parameter name used for the Finviz API token.",
    )
    auth_group.add_argument(
        "--auth-header",
        choices=("X-API-Key",),
        help="Header name used for the Finviz API token.",
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


def sequence_stamp(file_stamp: str) -> tuple[str, str]:
    date_part = file_stamp.split("_", 1)[0]
    suffix = next_daily_sequence_suffix(date_part)
    return f"{file_stamp}_{suffix}", suffix


def normalize_spaces(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def normalize_header(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.casefold())


def normalize_key(headline: str, url: str) -> tuple[str, str]:
    normalized_headline = re.sub(r"\W+", " ", headline.casefold()).strip()
    return normalized_headline, url.strip()


def scalar_text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, dict):
        for key in ("name", "title", "source_name", "publisher"):
            text = scalar_text(value.get(key))
            if text:
                return text
        return ""
    if isinstance(value, list):
        return "; ".join(text for item in value if (text := scalar_text(item)))
    return normalize_spaces(str(value))


def first_json_field(item: dict[str, Any], field_names: tuple[str, ...]) -> str:
    for field_name in field_names:
        value = scalar_text(item.get(field_name))
        if value:
            return value
    return ""


def first_csv_field(row: dict[str, str], field_names: tuple[str, ...]) -> str:
    normalized_row = {normalize_header(key): value for key, value in row.items()}
    for field_name in field_names:
        value = normalize_spaces(normalized_row.get(normalize_header(field_name), ""))
        if value:
            return value
    return ""


def keyword_tags(*parts: str) -> str:
    padded_text = f" {' '.join(parts).casefold()} "
    tags = [
        tag
        for tag, keywords in TAG_KEYWORDS.items()
        if any(keyword in padded_text for keyword in keywords)
    ]
    return "; ".join(tags)


def endpoint_has_auth(endpoint: str) -> bool:
    query = urllib.parse.urlsplit(endpoint).query
    keys = {key.casefold() for key, _ in urllib.parse.parse_qsl(query, keep_blank_values=True)}
    return bool(keys.intersection({"auth", "token"}))


def suffix_to_number(suffix: str) -> int:
    value = 0
    for character in suffix:
        if not ("a" <= character <= "z"):
            return 0
        value = value * 26 + (ord(character) - ord("a") + 1)
    return value


def number_to_suffix(value: int) -> str:
    if value < 1:
        raise ValueError("Sequence value must be positive.")

    parts: list[str] = []
    while value:
        value -= 1
        parts.append(chr(ord("a") + (value % 26)))
        value //= 26
    return "".join(reversed(parts))


def extract_sequence_suffix(path: Path, date_part: str) -> str:
    pattern = rf"^fv_api(?:_preview)?_news_{re.escape(date_part)}_\d{{6}}_([a-z]+)\.(?:csv|txt)$"
    match = re.match(pattern, path.name)
    return match.group(1) if match else ""


def next_daily_sequence_suffix(date_part: str) -> str:
    suffix_values: list[int] = []
    for directory, patterns in (
        (RAW_DIR, (f"fv_api_news_{date_part}_*_*.csv", f"fv_api_news_{date_part}_*_*.txt")),
        (LOG_DIR, (f"fv_api_preview_news_{date_part}_*_*.csv",)),
    ):
        for pattern in patterns:
            for path in directory.glob(pattern):
                suffix = extract_sequence_suffix(path, date_part)
                value = suffix_to_number(suffix) if suffix else 0
                if value:
                    suffix_values.append(value)

    return number_to_suffix(max(suffix_values, default=0) + 1)


def redacted_url(url: str) -> str:
    parts = urllib.parse.urlsplit(url)
    safe_pairs = [
        (key, "REDACTED" if key.casefold() in {"auth", "token", "api_key"} else value)
        for key, value in urllib.parse.parse_qsl(parts.query, keep_blank_values=True)
    ]
    return urllib.parse.urlunsplit(
        (parts.scheme, parts.netloc, parts.path, urllib.parse.urlencode(safe_pairs), parts.fragment)
    )


def prepared_request_url(endpoint: str, params: dict[str, str]) -> str:
    if requests is None:
        return endpoint
    request = requests.Request("GET", endpoint, params=params).prepare()
    return request.url or endpoint


def fetch_export(
    endpoint: str,
    api_key: str,
    *,
    auth_param: Optional[str],
    auth_header: Optional[str],
) -> tuple[int, bytes, str, str, Optional[str]]:
    if requests is None:
        raise RuntimeError("The requests package is required for this Finviz export inspection.")

    headers = {"User-Agent": USER_AGENT}
    params: dict[str, str] = {}

    if auth_header:
        headers[auth_header] = api_key
    elif auth_param and not endpoint_has_auth(endpoint):
        params[auth_param] = api_key

    request_url = prepared_request_url(endpoint, params)
    response = requests.get(endpoint, params=params, headers=headers, timeout=30)
    return (
        response.status_code,
        response.content,
        response.headers.get("Content-Type", ""),
        redacted_url(request_url),
        response.apparent_encoding,
    )


def decode_response_content(payload: bytes, apparent_encoding: Optional[str]) -> DecodedPayload:
    for encoding in ("utf-8-sig", "utf-8", "cp1252"):
        try:
            return DecodedPayload(payload.decode(encoding), encoding, "")
        except UnicodeDecodeError:
            continue

    fallback_encoding = apparent_encoding or "latin-1"
    try:
        text = payload.decode(fallback_encoding)
        return DecodedPayload(
            text,
            fallback_encoding,
            f"Strict decoding failed; used fallback encoding {fallback_encoding}.",
        )
    except (LookupError, UnicodeDecodeError):
        return DecodedPayload(
            payload.decode("latin-1"),
            "latin-1",
            "Strict decoding and apparent encoding failed; used latin-1 fallback.",
        )


def detect_delimiter(sample: str) -> str:
    try:
        dialect = csv.Sniffer().sniff(sample[:4096], delimiters=",\t")
        if dialect.delimiter in {",", "\t"}:
            return dialect.delimiter
    except csv.Error:
        pass

    first_line = sample.splitlines()[0] if sample.splitlines() else ""
    return "\t" if first_line.count("\t") > first_line.count(",") else ","


def looks_like_csv(payload: str, delimiter: str) -> bool:
    lines = [line for line in payload.splitlines() if line.strip()]
    if not lines:
        return False
    if lines[0].lstrip().startswith(("{", "[")):
        return False

    try:
        parsed = list(csv.reader(io.StringIO("\n".join(lines[:5])), delimiter=delimiter))
    except csv.Error:
        return False

    return bool(parsed and len(parsed[0]) >= 2)


def has_header_row(payload: str, delimiter: str) -> bool:
    try:
        return csv.Sniffer().has_header(payload[:4096])
    except csv.Error:
        pass

    first_line = payload.splitlines()[0] if payload.splitlines() else ""
    cells = next(csv.reader([first_line], delimiter=delimiter), [])
    normalized_cells = {normalize_header(cell) for cell in cells}
    known_headers = {
        normalize_header(name)
        for name in (
            *HEADLINE_FIELDS,
            *URL_FIELDS,
            *SOURCE_FIELDS,
            *TIME_FIELDS,
            *SECTION_FIELDS,
            *SUMMARY_FIELDS,
        )
    }
    return bool(normalized_cells.intersection(known_headers))


def parse_csv_payload(payload: str) -> CsvParseResult:
    delimiter = detect_delimiter(payload)
    if not looks_like_csv(payload, delimiter):
        return CsvParseResult([], delimiter, [], False, "Response does not look like CSV.")

    has_header = has_header_row(payload, delimiter)
    if not has_header:
        return CsvParseResult(
            [],
            delimiter,
            [],
            False,
            "CSV-like response has no detectable header row; raw response was saved only.",
        )

    reader = csv.DictReader(io.StringIO(payload), delimiter=delimiter)
    headers = [header or "" for header in (reader.fieldnames or [])]
    rows = [
        {str(key or ""): str(value or "") for key, value in row.items()}
        for row in reader
        if any(str(value or "").strip() for value in row.values())
    ]
    return CsvParseResult(rows, delimiter, headers, True, "")


def extract_json_items(data: Any) -> list[dict[str, Any]]:
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)]
    if not isinstance(data, dict):
        return []

    for key in LIST_KEYS:
        value = data.get(key)
        if isinstance(value, list):
            return [item for item in value if isinstance(item, dict)]

    return []


def parse_csv_headlines(rows: list[dict[str, str]], fetched_at_utc: str) -> list[Headline]:
    headlines: list[Headline] = []
    seen: set[tuple[str, str]] = set()

    for row in rows:
        headline = first_csv_field(row, HEADLINE_FIELDS)
        url = first_csv_field(row, URL_FIELDS)
        if not headline:
            continue

        key = normalize_key(headline, url)
        if key in seen:
            continue
        seen.add(key)

        summary = first_csv_field(row, SUMMARY_FIELDS)
        headlines.append(
            Headline(
                fetched_at_utc=fetched_at_utc,
                source_name=first_csv_field(row, SOURCE_FIELDS),
                section=first_csv_field(row, SECTION_FIELDS),
                published_time=first_csv_field(row, TIME_FIELDS),
                headline=headline,
                url=url,
                description_or_summary=summary,
                tags=keyword_tags(headline, summary),
            )
        )

    return headlines


def parse_json_headlines(data: Any, fetched_at_utc: str) -> list[Headline]:
    headlines: list[Headline] = []
    seen: set[tuple[str, str]] = set()

    for item in extract_json_items(data):
        headline = first_json_field(item, HEADLINE_FIELDS)
        url = first_json_field(item, URL_FIELDS)
        if not headline:
            continue

        key = normalize_key(headline, url)
        if key in seen:
            continue
        seen.add(key)

        summary = first_json_field(item, SUMMARY_FIELDS)
        headlines.append(
            Headline(
                fetched_at_utc=fetched_at_utc,
                source_name=first_json_field(item, SOURCE_FIELDS),
                section=first_json_field(item, SECTION_FIELDS),
                published_time=first_json_field(item, TIME_FIELDS),
                headline=headline,
                url=url,
                description_or_summary=summary,
                tags=keyword_tags(headline, summary),
            )
        )

    return headlines


def write_raw_text(path: Path, payload: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(payload, encoding="utf-8")


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


def parse_json_fallback(payload: str, fetched_at_utc: str) -> tuple[list[Headline], str]:
    try:
        data = json.loads(payload)
    except json.JSONDecodeError as exc:
        return [], f"JSON fallback skipped: response was not valid JSON ({exc})."
    return parse_json_headlines(data, fetched_at_utc), ""


def printable_delimiter(delimiter: str) -> str:
    return "tab" if delimiter == "\t" else delimiter


def print_summary(
    *,
    request_url: str,
    http_status: int,
    content_type: str,
    encoding: str,
    delimiter: str,
    headers: list[str],
    sequence_suffix: str,
    headlines: list[Headline],
    raw_path: Path,
    csv_path: Path,
    warning: str = "",
) -> None:
    print(f"Request URL: {request_url}")
    print(f"HTTP status: {http_status}")
    print(f"Response content type: {content_type}")
    print(f"Encoding used: {encoding}")
    print(f"Detected CSV delimiter: {printable_delimiter(delimiter)}")
    print(f"Detected CSV headers: {', '.join(headers)}")
    print(f"Daily download sequence suffix: _{sequence_suffix}")
    if warning:
        print(f"Warning: {warning}")
    print(f"Headlines found: {len(headlines)}")
    print("First 10 headlines:")
    for index, item in enumerate(headlines[:10], start=1):
        print(f"{index}. {item.headline}")
    print(f"Raw output path: {raw_path}")
    print(f"Preview CSV path: {csv_path}")


def main() -> int:
    args = parse_args()
    fetched_at_utc, file_stamp = utc_stamp()
    file_stamp_with_sequence, sequence_suffix = sequence_stamp(file_stamp)
    preview_path = LOG_DIR / f"fv_api_preview_news_{file_stamp_with_sequence}.csv"

    env = load_env(SECRETS_PATH)
    api_key = env.get("FINVIZ_API_KEY", "")
    endpoint = env.get("FINVIZ_NEWS_API_URL", "")
    if not endpoint:
        print(f"Missing FINVIZ_NEWS_API_URL in {SECRETS_PATH}. No request made.")
        return 1
    if not endpoint_has_auth(endpoint) and not api_key:
        print(f"Missing FINVIZ_API_KEY in {SECRETS_PATH}. No request made.")
        return 1

    try:
        status, payload_bytes, content_type, safe_url, apparent_encoding = fetch_export(
            endpoint,
            api_key,
            auth_param=args.auth_param,
            auth_header=args.auth_header,
        )
    except RuntimeError as exc:
        print(f"Failed Finviz export inspection: {exc}")
        return 1

    decoded_payload = decode_response_content(payload_bytes, apparent_encoding)
    payload = decoded_payload.text
    csv_result = parse_csv_payload(payload)
    if csv_result.rows or csv_result.has_header:
        raw_path = RAW_DIR / f"fv_api_news_{file_stamp_with_sequence}.csv"
        headlines = parse_csv_headlines(csv_result.rows, fetched_at_utc)
        warning = "; ".join(
            item for item in (decoded_payload.warning, csv_result.warning) if item
        )
    else:
        raw_path = RAW_DIR / f"fv_api_news_{file_stamp_with_sequence}.txt"
        headlines, json_warning = parse_json_fallback(payload, fetched_at_utc)
        warning = "; ".join(
            item for item in (decoded_payload.warning, csv_result.warning, json_warning) if item
        )

    write_raw_text(raw_path, payload)
    write_preview_csv(preview_path, headlines)
    print_summary(
        request_url=safe_url,
        http_status=status,
        content_type=content_type,
        encoding=decoded_payload.encoding,
        delimiter=csv_result.delimiter,
        headers=csv_result.headers,
        sequence_suffix=sequence_suffix,
        headlines=headlines,
        raw_path=raw_path,
        csv_path=preview_path,
        warning=warning,
    )
    return 0 if headlines else 1


if __name__ == "__main__":
    sys.exit(main())
