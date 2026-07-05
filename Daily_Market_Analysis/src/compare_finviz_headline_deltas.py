#!/usr/bin/env python3
"""Compare two Finviz Elite preview CSV files for headline deltas.

This script reads local preview CSV files only. It does not fetch Finviz,
follow article links, scrape article bodies, generate the final daily report,
modify the fixed YAML schema, or add trading logic.
"""

from __future__ import annotations

import csv
import re
import sys
from argparse import ArgumentParser, Namespace
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
LOG_DIR = PROJECT_ROOT / "output" / "logs"
REPORT_DIR = PROJECT_ROOT / "output" / "reports"

PRESERVED_FIELDS = (
    "source_name",
    "section",
    "published_time",
    "headline",
    "url",
    "tags",
)

DELTA_COLUMNS = (
    "delta_type",
    "importance_score",
    "important_tags",
    *PRESERVED_FIELDS,
)

IMPORTANT_TAGS = (
    "panic",
    "risk_off",
    "risk_on",
    "fed",
    "yields",
    "oil",
    "commodities",
    "dollar",
    "yen",
    "japan",
    "boj",
    "intervention",
    "tech",
    "ai",
    "semiconductors",
    "banks",
    "credit",
)

IMPORTANT_KEYWORDS = {
    "panic": ("panic", "crash", "selloff", "sell-off", "plunge", "turmoil"),
    "risk_off": ("risk-off", "risk off", "havens", "safe haven", "stocks fall", "stocks drop"),
    "risk_on": ("risk-on", "risk on", "rally", "stocks rise", "stocks gain", "surge"),
    "fed": ("fed", "federal reserve", "fomc", "powell"),
    "yields": ("yield", "yields"),
    "oil": ("oil", "crude", "brent", "wti"),
    "commodities": ("commodity", "commodities", "gold", "copper", "silver"),
    "dollar": ("dollar", "usd", "dxy"),
    "yen": ("yen", "jpy"),
    "japan": ("japan", "japanese", "tokyo"),
    "boj": ("boj", "bank of japan", "ueda"),
    "intervention": ("intervention", "intervene", "intervened"),
    "tech": ("tech", "technology", "software"),
    "ai": (" ai ", "artificial intelligence", "openai", "chatgpt"),
    "semiconductors": ("chip", "chips", "semiconductor", "nvidia", "amd", "tsmc"),
    "banks": ("bank", "banks", "lender", "lenders"),
    "credit": ("credit", "debt", "default", "loan", "loans", "spread"),
}


@dataclass(frozen=True)
class HeadlineRow:
    source_name: str
    section: str
    published_time: str
    headline: str
    url: str
    tags: str

    @property
    def key(self) -> tuple[str, str]:
        normalized_headline = re.sub(r"\W+", " ", self.headline.casefold()).strip()
        return normalized_headline, self.url.strip()


@dataclass(frozen=True)
class ScoredHeadline:
    row: HeadlineRow
    important_tags: tuple[str, ...]

    @property
    def importance_score(self) -> int:
        return len(self.important_tags)


def parse_args() -> Namespace:
    parser = ArgumentParser(description="Compare two Finviz preview CSV files for headline deltas.")
    parser.add_argument("--old", required=True, type=Path, help="Older Finviz preview CSV path.")
    parser.add_argument("--new", required=True, type=Path, help="Newer Finviz preview CSV path.")
    return parser.parse_args()


def normalize_spaces(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def normalize_header(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.casefold())


def read_preview_csv(path: Path) -> list[HeadlineRow]:
    if not path.exists():
        raise FileNotFoundError(f"Missing preview CSV: {path}")

    rows: list[HeadlineRow] = []
    with path.open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file)
        for raw_row in reader:
            normalized_row = {
                normalize_header(str(key or "")): normalize_spaces(str(value or ""))
                for key, value in raw_row.items()
            }
            headline = normalized_row.get("headline", "")
            if not headline:
                continue

            rows.append(
                HeadlineRow(
                    source_name=normalized_row.get("sourcename", ""),
                    section=normalized_row.get("section", ""),
                    published_time=normalized_row.get("publishedtime", ""),
                    headline=headline,
                    url=normalized_row.get("url", ""),
                    tags=normalized_row.get("tags", ""),
                )
            )

    return rows


def unique_by_key(rows: list[HeadlineRow]) -> dict[tuple[str, str], HeadlineRow]:
    unique_rows: dict[tuple[str, str], HeadlineRow] = {}
    for row in rows:
        unique_rows.setdefault(row.key, row)
    return unique_rows


def split_tags(tags: str) -> set[str]:
    return {
        normalize_header(tag)
        for tag in re.split(r"[;,|]", tags)
        if normalize_header(tag)
    }


def important_tags_for(row: HeadlineRow) -> tuple[str, ...]:
    existing_tags = split_tags(row.tags)
    padded_text = f" {row.headline} {row.section} {row.source_name} ".casefold()
    matches: list[str] = []

    for tag in IMPORTANT_TAGS:
        if normalize_header(tag) in existing_tags:
            matches.append(tag)
            continue

        keywords = IMPORTANT_KEYWORDS.get(tag, ())
        if any(keyword in padded_text for keyword in keywords):
            matches.append(tag)

    return tuple(matches)


def score_rows(rows: list[HeadlineRow]) -> list[ScoredHeadline]:
    scored = [ScoredHeadline(row=row, important_tags=important_tags_for(row)) for row in rows]
    return sorted(
        scored,
        key=lambda item: (-item.importance_score, item.row.published_time, item.row.headline.casefold()),
    )


def utc_file_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")


def write_delta_csv(
    path: Path,
    *,
    new_headlines: list[HeadlineRow],
    removed_headlines: list[HeadlineRow],
    unchanged_headlines: list[HeadlineRow],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=DELTA_COLUMNS)
        writer.writeheader()
        for delta_type, rows in (
            ("new_headlines", new_headlines),
            ("removed_headlines", removed_headlines),
            ("unchanged_headlines", unchanged_headlines),
        ):
            for scored in score_rows(rows):
                writer.writerow(
                    {
                        "delta_type": delta_type,
                        "importance_score": scored.importance_score,
                        "important_tags": "; ".join(scored.important_tags),
                        "source_name": scored.row.source_name,
                        "section": scored.row.section,
                        "published_time": scored.row.published_time,
                        "headline": scored.row.headline,
                        "url": scored.row.url,
                        "tags": scored.row.tags,
                    }
                )


def markdown_escape(value: str) -> str:
    return value.replace("[", "\\[").replace("]", "\\]")


def headline_markdown(item: ScoredHeadline) -> str:
    row = item.row
    parts = [markdown_escape(row.headline)]
    details = []
    if row.source_name:
        details.append(row.source_name)
    if row.published_time:
        details.append(row.published_time)
    if item.important_tags:
        details.append(f"tags: {', '.join(item.important_tags)}")
    if details:
        parts.append(f" ({'; '.join(details)})")
    if row.url:
        parts.append(f" - {row.url}")
    return "".join(parts)


def group_new_headlines(scored_rows: list[ScoredHeadline]) -> dict[str, list[ScoredHeadline]]:
    groups: dict[str, list[ScoredHeadline]] = {}
    for item in scored_rows:
        labels = item.important_tags or (item.row.section or "uncategorized",)
        for label in labels:
            groups.setdefault(label, []).append(item)
    return dict(sorted(groups.items(), key=lambda pair: pair[0].casefold()))


def write_markdown_report(
    path: Path,
    *,
    old_path: Path,
    new_path: Path,
    new_headlines: list[HeadlineRow],
    removed_headlines: list[HeadlineRow],
    unchanged_headlines: list[HeadlineRow],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    scored_new = score_rows(new_headlines)
    important_new = [item for item in scored_new if item.importance_score]
    grouped_new = group_new_headlines(scored_new)

    lines = [
        "# Finviz Headline Delta",
        "",
        f"- Old file: `{old_path}`",
        f"- New file: `{new_path}`",
        f"- New headlines: {len(new_headlines)}",
        f"- Removed headlines: {len(removed_headlines)}",
        f"- Unchanged headlines: {len(unchanged_headlines)}",
        "",
        "## Top Important New Headlines",
        "",
    ]

    if important_new:
        for item in important_new[:15]:
            lines.append(f"- {headline_markdown(item)}")
    else:
        lines.append("- None detected.")

    lines.extend(["", "## All New Headlines By Tag Or Category", ""])
    if grouped_new:
        for group, items in grouped_new.items():
            lines.extend([f"### {group}", ""])
            for item in items:
                lines.append(f"- {headline_markdown(item)}")
            lines.append("")
    else:
        lines.append("- None.")

    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def print_summary(
    *,
    old_path: Path,
    new_path: Path,
    new_headlines: list[HeadlineRow],
    removed_headlines: list[HeadlineRow],
    unchanged_headlines: list[HeadlineRow],
    delta_csv_path: Path,
    delta_markdown_path: Path,
) -> None:
    print(f"Old file: {old_path}")
    print(f"New file: {new_path}")
    print(f"New headline count: {len(new_headlines)}")
    print(f"Removed headline count: {len(removed_headlines)}")
    print(f"Unchanged headline count: {len(unchanged_headlines)}")
    print("First 10 new headlines:")
    for index, item in enumerate(new_headlines[:10], start=1):
        print(f"{index}. {item.headline}")
    print(f"Delta CSV path: {delta_csv_path}")
    print(f"Delta Markdown path: {delta_markdown_path}")


def main() -> int:
    args = parse_args()
    old_rows = unique_by_key(read_preview_csv(args.old))
    new_rows = unique_by_key(read_preview_csv(args.new))

    old_keys = set(old_rows)
    new_keys = set(new_rows)

    new_headlines = [new_rows[key] for key in sorted(new_keys - old_keys)]
    removed_headlines = [old_rows[key] for key in sorted(old_keys - new_keys)]
    unchanged_headlines = [new_rows[key] for key in sorted(old_keys & new_keys)]

    file_stamp = utc_file_stamp()
    delta_csv_path = LOG_DIR / f"fv_delta_news_{file_stamp}.csv"
    delta_markdown_path = REPORT_DIR / f"fv_delta_news_{file_stamp}.md"

    write_delta_csv(
        delta_csv_path,
        new_headlines=new_headlines,
        removed_headlines=removed_headlines,
        unchanged_headlines=unchanged_headlines,
    )
    write_markdown_report(
        delta_markdown_path,
        old_path=args.old,
        new_path=args.new,
        new_headlines=new_headlines,
        removed_headlines=removed_headlines,
        unchanged_headlines=unchanged_headlines,
    )
    print_summary(
        old_path=args.old,
        new_path=args.new,
        new_headlines=new_headlines,
        removed_headlines=removed_headlines,
        unchanged_headlines=unchanged_headlines,
        delta_csv_path=delta_csv_path,
        delta_markdown_path=delta_markdown_path,
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (FileNotFoundError, csv.Error) as exc:
        print(f"Failed Finviz headline delta comparison: {exc}")
        sys.exit(1)
