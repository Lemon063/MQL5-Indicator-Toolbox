# Changelog

## 2026-07-05 - Documentation refreshed for working market-data prototype

### Changed
- Updated `doc/SPECIFICATION.md` and `README.md` to reflect Alpha Vantage structured-data tests, Finviz Elite News Export success, Finviz suffix naming, and the headline delta workflow.
- 更新 `doc/SPECIFICATION.md` 及 `README.md`，反映 Alpha Vantage structured-data 測試、Finviz Elite News Export 成功、Finviz suffix naming，以及 headline delta workflow。
- Documented current source roles, rejected Alpha Vantage news topics, environment-variable expectations, known macOS `NotOpenSSLWarning`, and current not-yet-implemented items.
- 記錄目前 source roles、已否決的 Alpha Vantage news topics、environment variable 預期、macOS `NotOpenSSLWarning`，以及目前尚未實作項目。
- Converted the latest documentation updates into Chinese-English paired wording.
- 將最新文件更新轉成中英對照格式。

---

## 2026-07-05 - Finviz headline delta comparison script added

### Added
- Added `src/compare_finviz_headline_deltas.py` to compare two local Finviz Elite preview CSV files by normalized headline plus URL.
- Saves delta CSV output to `output/logs/fv_delta_news_YYYYMMDD_HHMMSS.csv`.
- Saves Markdown delta reports to `output/reports/fv_delta_news_YYYYMMDD_HHMMSS.md`.
- Highlights important new headlines using market tags and keywords such as panic, risk-off, Fed, yields, dollar, yen, BoJ, tech, AI, semiconductors, banks, and credit.

---

## 2026-07-05 - Finviz Elite CSV encoding and daily suffix handling

### Changed
- Updated `src/fetch_finviz_news_api.py` to decode Finviz Elite News export bytes before saving or parsing CSV, trying `utf-8-sig`, `utf-8`, `cp1252`, then a warned fallback.
- Added console reporting for the encoding used and the daily download sequence suffix.
- Added date-wide Finviz API output suffixes (`_a`, `_b`, ... `_z`, `_aa`) across raw and preview files for the same date.

---

## 2026-07-05 - Finviz Elite CSV export handling fixed

### Changed
- Updated `src/fetch_finviz_news_api.py` to treat Finviz Elite News Export as CSV/text by default.
- Added comma/tab CSV parsing, detected-header reporting, redacted auth logging, and JSON fallback only when the response is not CSV.

---

## 2026-07-05 - API headline inspection scripts added

### Added
- Added Finviz News API inspection script.
- Added NewsAPI.org market headline inspection script.
- Added API key placeholders to `.env_DMA.example`.

---

## 2026-07-05 - Finviz and Yahoo headline inspection scripts added

### Added
- Added `src/fetch_finviz_headlines.py` for one-shot Finviz News page headline inspection.
- Added `src/fetch_yahoo_market_headlines.py` for one-shot Yahoo Finance market/news headline inspection.
- Both scripts save raw HTML/text responses and human-readable preview CSV files under `output/raw/` and `output/logs/`.
- Both scripts extract headline-level fields only: fetched time, source, section, published time, headline, URL, and simple keyword tags.
- Both scripts use a polite User-Agent, deduplicate by normalized headline plus URL, and avoid following article links.

### Confirmed
- No full article body scraping was added.
- No Finviz paid API or bypass behavior was added.
- No final Daily Market Analysis report generation was added.
- No YAML schema change was added.
- No trading logic was added.
- `SPECIFICATION.md` was not updated.

---

## 2026-07-04 - Alpha Vantage structured-data inspection script added

### Added
- Added `src/fetch_alpha_vantage_structured.py` for single-query Alpha Vantage structured-data inspections.
- Supported `fx_daily`, `fx_weekly`, `treasury_yield_10y`, `treasury_yield_2y`, `fed_funds`, `cpi`, `inflation`, `unemployment`, and `nonfarm_payroll`.
- Added raw JSON and preview CSV output naming for each structured-data query.
- Reads `ALPHA_VANTAGE_API_KEY` only from `/Users/avislai/Documents/.key/.env_DMA`.
- Prints available query names and exits when no `--query` is provided, avoiding accidental multi-query runs.
- Treats Alpha Vantage `Information`, `Note`, and `Error Message` responses as failed or rate-limited inspections after saving raw JSON.

### Confirmed
- Rejected Alpha Vantage `NEWS_SENTIMENT` economy topics were not revisited.
- No live API requests were run inside Codex.
- No Twelve Data economic or news endpoints were added.
- No final Daily Market Analysis report generation was added.
- No YAML schema change was added.
- No trading logic was added.

---

## 2026-07-04 - Twelve Data USDJPY daily inspection script added

### Added
- Added `src/fetch_twelve_data_usdjpy_daily.py` as the first Twelve Data inspection script.
- Fetches only Twelve Data USDJPY daily OHLC data via the official time series endpoint.
- Reads `TWELVE_DATA_API_KEY` only from `/Users/avislai/Documents/.key/.env_DMA`.
- Saves raw JSON to `output/raw/td_usdjpy_daily_YYYYMMDD_HHMMSS.json`.
- Saves preview CSV to `output/logs/td_preview_usdjpy_daily_YYYYMMDD_HHMMSS.csv`.
- Treats Twelve Data API errors, rate limits, entitlement issues, or malformed data as failed inspections after saving the raw response.

### Confirmed
- No Twelve Data weekly implementation was added.
- No Alpha Vantage structured-data implementation was added.
- No final Daily Market Analysis report generation was added.
- No YAML schema change was added.
- No trading logic was added.

---

## 2026-07-04 - Documentation path and Twelve Data env var cleanup

### Changed
- Updated changelog specification-path wording to `SPECIFICATION.md`.
- Standardised the Twelve Data environment variable name to `TWELVE_DATA_API_KEY`.
- Documented that `.env_DMA.example` and the external `.env_DMA` secrets file should include `TWELVE_DATA_API_KEY=`.

### Confirmed
- No new API scripts were added.
- No live API requests were run.
- No final Daily Market Analysis report generation was added.
- No YAML schema change was added.
- No trading logic was added.

---

## 2026-07-04 - Alpha Vantage news topics rejected and next experiments defined

### Changed
- Updated `SPECIFICATION.md` to record that Alpha Vantage `NEWS_SENTIMENT + topics=economy_macro` was manually reviewed and rejected.
- Updated `SPECIFICATION.md` to record that Alpha Vantage `NEWS_SENTIMENT + topics=economy_monetary` was manually reviewed and rejected.
- Documented the rejection reason: returned data was not suitable for the user's intended Daily Market Analysis workflow.
- Documented that no further work should be spent on these two Alpha Vantage news topics unless the user explicitly reopens them.
- Kept the observed Alpha Vantage free API limit notes:
  - 25 requests per day
  - 1 request per second burst limit
  - spread requests out
  - avoid unnecessary repeated calls
  - use single-query test mode where possible
  - treat `Information`, `Note`, or `Error Message` responses as warning/failure, not valid data
- Added `Next Data Source Experiments` to define:
  - Track A: Twelve Data
  - Track B: Alpha Vantage non-news structured data
- Added proposed short output filename conventions for Twelve Data and Alpha Vantage structured-data previews.
- Added data-use notes for `FX_DAILY`, `FX_WEEKLY`, `TREASURY_YIELD`, `FEDERAL_FUNDS_RATE`, `CPI`, `INFLATION`, `UNEMPLOYMENT`, `NONFARM_PAYROLL`, `REAL_GDP`, and `REAL_GDP_PER_CAPITA`.

### Confirmed
- No new API scripts were added.
- No live API requests were run.
- No final Daily Market Analysis report generation was added.
- No YAML schema change was added.
- No trading logic was added.

---

## 2026-07-03 - Alpha Vantage specification expanded

### Changed
- Added a dedicated `Alpha Vantage` section to `SPECIFICATION.md`.
- Documented Alpha Vantage as a broader market-context source, not only a direct USDJPY headline source.
- Documented intended Alpha Vantage use cases:
  - News & Sentiment API
  - `economy_macro`
  - `economy_monetary`
  - `financial_markets` if tested later
  - `TREASURY_YIELD` if tested later
  - `FEDERAL_FUNDS_RATE` if tested later
  - `FX_WEEKLY` if tested later
- Documented current tested query types:
  - `NEWS_SENTIMENT + topics=economy_macro`
  - `NEWS_SENTIMENT + topics=economy_monetary`
- Documented short Alpha Vantage output filename conventions using `av_econ_macro` and `av_econ_monetary`.
- Documented observed Alpha Vantage free API limits:
  - 25 requests per day
  - 1 request per second burst limit
- Added implementation rules to prefer single-query test mode, avoid wasting quota, delay at least 1 second if multiple requests are ever run, and treat `Information`, `Note`, or `Error Message` responses as API failures or warnings.

### Confirmed
- No new API calls were implemented.
- No final Daily Market Analysis report generation was added.
- No trading execution logic was added.
- The fixed v1 YAML output schema was not modified.

---

## 2026-07-03 - Alpha Vantage USDJPY relevance preview added

### Changed
- Updated `src/fetch_alpha_vantage_news.py` preview logic to calculate USDJPY relevance for Alpha Vantage news items.
- Kept raw JSON output unchanged in `output/raw/`.
- Kept preview CSV output in `output/logs/`.
- Added preview CSV columns:
  - `keyword_hits`
  - `relevance_bucket`
  - `is_usdjpy_relevant`
- Counts keyword hits in `title` plus `summary` using USD, dollar, DXY, yen, JPY, BoJ, Bank of Japan, Fed, Federal Reserve, FOMC, Treasury, yields, rates, inflation, CPI, payrolls, jobs, unemployment, claims, risk-off, and risk-on terms.
- Buckets relevance as `high` for 3 or more hits, `medium` for 1-2 hits, and `low` for 0 hits.
- Prints total item count, high/medium/low relevance counts, and the top 5 relevant titles in the console summary.

### Confirmed
- No final Daily Market Analysis report generation was added.
- No YAML generation was added.
- No trading execution logic was added.
- The fixed v1 YAML output schema was not modified.

---

## 2026-07-03 - Alpha Vantage single-query test fix

### Failed First Live Test
- The first live Alpha Vantage test produced empty preview CSV files because no `feed` items were returned.
- Query 1 returned an Alpha Vantage `Invalid inputs` response.
- Query 2 hit an Alpha Vantage free-tier request limit warning.

### Changed
- Updated `src/fetch_alpha_vantage_news.py` to run only one Alpha Vantage query per execution.
- Added single-query CLI mode:
  - `--query economy_monetary`
  - `--query economy_macro`
  - `--query financial_markets`
- Set the default test query to Alpha Vantage `NEWS_SENTIMENT` with:
  - `topics=economy_monetary`
  - `limit=50`
- Removed `tickers=FOREX:USD` from the default query.
- Prints the exact query parameters used without printing the API key.
- Treats Alpha Vantage `Information`, `Note`, and `Error Message` response fields as API failures.
- Writes an error summary to `output/logs/` instead of writing an empty preview CSV when Alpha Vantage returns an API failure.
- Keeps a one-second delay guard in the loop if multiple queries are enabled later.

### Confirmed
- No Marketaux, Finnhub, or Yahoo implementation was added.
- No final Daily Market Analysis report generation was added.
- No YAML generation was added.
- No trading execution logic was added.
- The fixed v1 YAML output schema was not modified.

---

## 2026-07-03 - Alpha Vantage external secrets test updated

### Changed
- Updated `src/fetch_alpha_vantage_news.py` to load secrets only from `/Users/avislai/Documents/.key/.env_DMA`.
- Uses `ALPHA_VANTAGE_API_KEY` as the required Alpha Vantage variable name.
- Stops with `Missing secrets file: /Users/avislai/Documents/.key/.env_DMA` if the external secrets file is absent.
- Stops with `Missing ALPHA_VANTAGE_API_KEY in secrets file` if the key is not present in the external secrets file.
- Runs two Alpha Vantage `NEWS_SENTIMENT` inspection queries:
  - `tickers=FOREX:USD`, `topics=economy_monetary,economy_macro`
  - `tickers=FOREX:USD`, `topics=financial_markets,economy_macro`
- Saves one raw response per query to `output/raw/`.
- Saves one preview CSV per query to `output/logs/`.
- Adds `query_name` to the preview CSV columns.
- Prints a short per-query summary with returned item count, keyword-related item count, and output paths.

### Confirmed
- No secrets are read from the project root.
- No API key is printed or logged.
- No Marketaux, Finnhub, or Yahoo implementation was added.
- No final Daily Market Analysis report generation was added.
- No trading execution logic was added.
- The fixed v1 YAML output schema was not modified.

---

## 2026-07-03 - Alpha Vantage inspection test added

### Added
- Added `src/fetch_alpha_vantage_news.py` for the first experimental Alpha Vantage News & Sentiment API inspection.
- Added `output/raw/README.md` to document raw API response storage.
- Added `output/logs/README.md` to document preview and log outputs.

### Behavior
- Loads `ALPHA_VANTAGE_API_KEY` from `.env`.
- Stops with a clear error if the key is missing.
- Queries Alpha Vantage for forex and macro-related news only.
- Saves raw JSON to `output/raw/alpha_vantage_YYYYMMDD_HHMMSS.json`.
- Saves a simple preview CSV to `output/logs/alpha_vantage_preview_YYYYMMDD_HHMMSS.csv`.
- Prints item count, keyword-match count, and output file paths.

### Confirmed
- No Marketaux, Finnhub, or Yahoo implementation was added.
- No API source scoring was added yet.
- No final Daily Market Analysis report generation was added.
- No trading execution logic was added.
- The fixed v1 YAML output schema was not modified.

---

## 2026-07-03 - Configuration placeholders added

### Added
- Added `.env.example` with placeholder API key names only.
- Added `config/sources.yaml` to document candidate source configuration.
- Kept API source setup advisory and non-executing.

### Confirmed
- No Python files were created.
- No skeleton fetchers were created.
- No API logic was implemented.
- The fixed v1 YAML output schema was not modified.

---

## 2026-07-01 - Initial specification phase

### Added
- Created `README.md`.
- Created `SPECIFICATION.md`.
- Defined project purpose: experimental USDJPY Daily Market Analysis Report using free/freemium news APIs.
- Defined fixed v1 YAML output schema.
- Defined API evaluation criteria.
- Added API score output requirements:
  - `output/logs/api_score_YYYYMMDD.csv`
  - `output/logs/api_score_YYYYMMDD.md`

### Decisions
- This module stays inside Toolbox first.
- No MT5 EA modification.
- No trade execution.
- No paid economic-calendar Actual feed in this phase.
- YAML schema is fixed for v1 and must not be renamed casually.
- YAML output is advisory only and must not trigger trades directly.

### Current Status
- Specification and API evaluation phase.
- No trading execution integration.
- No production data pipeline yet.

### Next
- Add `.env.example`.
- Add `config/sources.yaml`.
- Start with one API source only.
