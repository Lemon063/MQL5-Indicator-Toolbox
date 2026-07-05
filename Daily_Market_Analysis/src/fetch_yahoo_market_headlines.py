#!/usr/bin/env python3
"""Light Yahoo Finance market headline inspection for Daily Market Analysis.

This script fetches one Yahoo Finance market/news page and extracts only
headline-level data. It does not follow article links, scrape article bodies,
generate the final daily report, modify the fixed YAML schema, or add trading
logic.
"""

from __future__ import annotations

import csv
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from argparse import ArgumentParser, Namespace
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

DEFAULT_URL = (
    "https://finance.yahoo.com/markets/article/"
    "stock-analysts-may-be-setting-up-the-market-for-a-summer-failure-135125532.html"
)
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


def parse_args() -> Namespace:
    parser = ArgumentParser(
        description="Fetch one Yahoo Finance market/news page for headline inspection.",
    )
    parser.add_argument(
        "--url",
        default=DEFAULT_URL,
        help="Single Yahoo Finance page to inspect. Defaults to the supplied article URL.",
    )
    return parser.parse_args()


def utc_stamp() -> tuple[str, str]:
    now = datetime.now(timezone.utc)
    return now.strftime("%Y-%m-%dT%H:%M:%SZ"), now.strftime("%Y%m%d_%H%M%S")


def normalize_spaces(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def normalize_key(headline: str, url: str) -> tuple[str, str]:
    normalized_headline = re.sub(r"\W+", " ", headline.casefold()).strip()
    return normalized_headline, url.strip()


def absolute_url(base_url: str, url: str) -> str:
    return urllib.parse.urljoin(base_url, url)


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


def meta_content(soup, property_name: str) -> str:
    selectors = [
        f'meta[property="{property_name}"]',
        f'meta[name="{property_name}"]',
    ]
    for selector in selectors:
        match = soup.select_one(selector)
        if match:
            content = str(match.get("content", "")).strip()
            if content:
                return content
    return ""


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
        aria_label = normalize_spaces(str(parent.get("aria-label", "")))
        if aria_label and len(aria_label) <= 80:
            return aria_label

        heading = parent.find(["h1", "h2", "h3"])
        if heading and heading is not node:
            text = normalize_spaces(heading.get_text(" ", strip=True))
            if text and len(text) <= 80:
                return text

    return "Yahoo Finance"


def add_headline(
    headlines: list[Headline],
    seen: set[tuple[str, str]],
    *,
    fetched_at_utc: str,
    source_name: str,
    section: str,
    published_time: str,
    headline: str,
    url: str,
) -> None:
    headline = normalize_spaces(headline)
    url = url.strip()
    if not headline or len(headline) < 20 or len(headline.split()) < 4:
        return

    key = normalize_key(headline, url)
    if key in seen:
        return
    seen.add(key)

    headlines.append(
        Headline(
            fetched_at_utc=fetched_at_utc,
            source_name=source_name,
            section=section,
            published_time=published_time,
            headline=headline,
            url=url,
            tags=keyword_tags(headline),
        )
    )


def parse_headlines(html: str, fetched_at_utc: str, page_url: str) -> list[Headline]:
    if BeautifulSoup is None:
        raise RuntimeError("BeautifulSoup is not installed. Install beautifulsoup4 to parse HTML.")

    soup = BeautifulSoup(html, "html.parser")
    headlines: list[Headline] = []
    seen: set[tuple[str, str]] = set()

    page_source = meta_content(soup, "og:site_name") or "Yahoo Finance"
    page_time = meta_content(soup, "article:published_time")
    page_title = meta_content(soup, "og:title")
    canonical = ""
    canonical_link = soup.select_one('link[rel="canonical"]')
    if canonical_link:
        canonical = str(canonical_link.get("href", "")).strip()

    if page_title:
        add_headline(
            headlines,
            seen,
            fetched_at_utc=fetched_at_utc,
            source_name=page_source,
            section="Yahoo Finance Article",
            published_time=page_time,
            headline=page_title,
            url=canonical or page_url,
        )

    for link in soup.select("a[href]"):
        href = str(link.get("href", "")).strip()
        if not href or href.startswith(("#", "javascript:", "mailto:")):
            continue

        headline = normalize_spaces(link.get_text(" ", strip=True))
        if not headline:
            heading = link.find(["h1", "h2", "h3", "h4"])
            if heading:
                headline = normalize_spaces(heading.get_text(" ", strip=True))

        add_headline(
            headlines,
            seen,
            fetched_at_utc=fetched_at_utc,
            source_name=nearby_text(link, ("[data-test-locator='publisher']", ".provider"))
            or page_source,
            section=infer_section(link),
            published_time=nearby_text(link, ("time", "[datetime]")) or page_time,
            headline=headline,
            url=absolute_url(page_url, href),
        )

    for heading in soup.select("h1, h2, h3, h4"):
        headline = normalize_spaces(heading.get_text(" ", strip=True))
        parent_link = heading.find_parent("a")
        url = absolute_url(page_url, str(parent_link.get("href", ""))) if parent_link else page_url
        add_headline(
            headlines,
            seen,
            fetched_at_utc=fetched_at_utc,
            source_name=page_source,
            section=infer_section(heading),
            published_time=nearby_text(heading, ("time", "[datetime]")) or page_time,
            headline=headline,
            url=url,
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
    args = parse_args()
    fetched_at_utc, file_stamp = utc_stamp()
    raw_path = RAW_DIR / f"yf_market_news_{file_stamp}.html"
    csv_path = LOG_DIR / f"yf_preview_market_news_{file_stamp}.csv"

    status, html = fetch_page(args.url)
    write_raw(raw_path, html)

    block_message = blocked_or_unhelpful(status, html)
    if block_message:
        write_preview_csv(csv_path, [])
        print(f"Failed Yahoo Finance headline inspection: {block_message}")
        print_summary([], raw_path, csv_path)
        return 1

    try:
        headlines = parse_headlines(html, fetched_at_utc, args.url)
    except RuntimeError as exc:
        write_preview_csv(csv_path, [])
        print(f"Failed Yahoo Finance headline inspection: {exc}")
        print_summary([], raw_path, csv_path)
        return 1

    write_preview_csv(csv_path, headlines)
    if not headlines:
        print("Failed Yahoo Finance headline inspection: no headline candidates were parsed.")
        print_summary(headlines, raw_path, csv_path)
        return 1

    print_summary(headlines, raw_path, csv_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
