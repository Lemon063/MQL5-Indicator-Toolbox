#!/usr/bin/env python3
"""Light Finviz News headline inspection for Daily Market Analysis.

This script fetches only the Finviz News page and extracts headline-level data.
It does not follow article links, scrape article bodies, generate the final
daily report, modify the fixed YAML schema, or add trading logic.
"""

from __future__ import annotations

import csv
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

try:
    from bs4 import BeautifulSoup
except ImportError:  # pragma: no cover - runtime environment message
    BeautifulSoup = None  # type: ignore[assignment]


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = PROJECT_ROOT / "output" / "raw"
LOG_DIR = PROJECT_ROOT / "output" / "logs"

FINVIZ_NEWS_URL = "https://finviz.com/news"
USER_AGENT = (
    "Daily-Market-Analysis-Headline-Inspection/0.1 "
    "(personal market headline preview; contact: local-user)"
)

CSV_COLUMNS = (
    "fetched_at_utc",
    "source_name",
    "section",
    "published_time",
    "headline",
    "url",
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
    tags: str


def utc_stamp() -> tuple[str, str]:
    now = datetime.now(timezone.utc)
    return now.strftime("%Y-%m-%dT%H:%M:%SZ"), now.strftime("%Y%m%d_%H%M%S")


def normalize_spaces(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def normalize_key(headline: str, url: str) -> tuple[str, str]:
    normalized_headline = re.sub(r"\W+", " ", headline.casefold()).strip()
    return normalized_headline, url.strip()


def absolute_url(url: str) -> str:
    return urllib.parse.urljoin(FINVIZ_NEWS_URL, url)


def keyword_tags(headline: str) -> str:
    padded_text = f" {headline.casefold()} "
    tags = [
        tag
        for tag, keywords in TAG_KEYWORDS.items()
        if any(keyword in padded_text for keyword in keywords)
    ]
    return "; ".join(tags)


def fetch_page(url: str) -> tuple[int, str]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = response.read().decode("utf-8", errors="replace")
            return response.status, payload
    except urllib.error.HTTPError as exc:
        payload = exc.read().decode("utf-8", errors="replace")
        return exc.code, payload
    except urllib.error.URLError as exc:
        return 0, f"Request failed before an HTTP response was received: {exc}"


def nearby_text(node, selectors: tuple[str, ...]) -> str:
    for parent in [node.parent, node.parent.parent if node.parent else None]:
        if parent is None:
            continue
        for selector in selectors:
            match = parent.select_one(selector)
            if match:
                text = normalize_spaces(match.get_text(" ", strip=True))
                if text:
                    return text
    return ""


def infer_section(node) -> str:
    for parent in node.parents:
        if getattr(parent, "name", "") in {"section", "article"}:
            heading = parent.find(["h1", "h2", "h3"])
            if heading:
                return normalize_spaces(heading.get_text(" ", strip=True))

    previous_heading = node.find_previous(["h1", "h2", "h3"])
    if previous_heading:
        text = normalize_spaces(previous_heading.get_text(" ", strip=True))
        if text and len(text) <= 80:
            return text

    return "Finviz News"


def parse_headlines(html: str, fetched_at_utc: str) -> list[Headline]:
    if BeautifulSoup is None:
        raise RuntimeError("BeautifulSoup is not installed. Install beautifulsoup4 to parse HTML.")

    soup = BeautifulSoup(html, "html.parser")
    candidates = soup.select("a[href]")
    headlines: list[Headline] = []
    seen: set[tuple[str, str]] = set()

    for link in candidates:
        headline = normalize_spaces(link.get_text(" ", strip=True))
        href = str(link.get("href", "")).strip()
        if not headline or not href:
            continue
        if len(headline) < 20 or len(headline.split()) < 4:
            continue
        if href.startswith(("#", "javascript:", "mailto:")):
            continue

        url = absolute_url(href)
        key = normalize_key(headline, url)
        if key in seen:
            continue
        seen.add(key)

        published_time = nearby_text(link, ("time", ".time", ".news_time", "[datetime]"))
        source_name = nearby_text(link, (".source", ".news_source", ".provider"))

        headlines.append(
            Headline(
                fetched_at_utc=fetched_at_utc,
                source_name=source_name,
                section=infer_section(link),
                published_time=published_time,
                headline=headline,
                url=url,
                tags=keyword_tags(headline),
            )
        )

    return headlines


def write_raw(path: Path, payload: str) -> None:
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
                    "tags": item.tags,
                }
            )


def blocked_or_unhelpful(status: int, html: str) -> Optional[str]:
    lower = html.casefold()
    if status in {401, 403, 429, 503}:
        return f"HTTP status {status} suggests the inspection may be blocked or rate-limited."
    if any(term in lower for term in ("captcha", "access denied", "verify you are human")):
        return "The response appears to contain a bot check or access-denied page."
    return None


def print_summary(headlines: list[Headline], raw_path: Path, csv_path: Path) -> None:
    print(f"Headlines found: {len(headlines)}")
    print("First 10 headlines:")
    for index, item in enumerate(headlines[:10], start=1):
        print(f"{index}. {item.headline}")
    print(f"Raw output path: {raw_path}")
    print(f"Preview CSV path: {csv_path}")


def main() -> int:
    fetched_at_utc, file_stamp = utc_stamp()
    raw_path = RAW_DIR / f"fv_news_{file_stamp}.html"
    csv_path = LOG_DIR / f"fv_preview_news_{file_stamp}.csv"

    status, html = fetch_page(FINVIZ_NEWS_URL)
    write_raw(raw_path, html)

    block_message = blocked_or_unhelpful(status, html)
    if block_message:
        write_preview_csv(csv_path, [])
        print(f"Failed Finviz headline inspection: {block_message}")
        print_summary([], raw_path, csv_path)
        return 1

    try:
        headlines = parse_headlines(html, fetched_at_utc)
    except RuntimeError as exc:
        write_preview_csv(csv_path, [])
        print(f"Failed Finviz headline inspection: {exc}")
        print_summary([], raw_path, csv_path)
        return 1

    write_preview_csv(csv_path, headlines)
    if not headlines:
        print("Failed Finviz headline inspection: no headline candidates were parsed.")
        print_summary(headlines, raw_path, csv_path)
        return 1

    print_summary(headlines, raw_path, csv_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
