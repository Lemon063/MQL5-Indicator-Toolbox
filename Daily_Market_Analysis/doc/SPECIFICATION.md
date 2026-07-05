# Daily Market Analysis Specification / 每日市場分析規格

Version / 版本: 0.2  
Status / 狀態: working market-data prototype / 可運作的市場數據原型  
Project root / 項目根目錄: `/Users/avislai/Documents/Codex/Toolbox/Daily_Market_Analysis`  
Symbol / 交易品種: USDJPY  
Report time target / 報告目標時間: 07:00 UK / 英國時間 07:00

## 1. Purpose / 用途

Daily_Market_Analysis is an experimental toolbox for generating Daily Market Analysis context for USDJPY.

Daily_Market_Analysis 是一個實驗性工具箱，用來產生 USDJPY 每日市場分析背景。

It is not part of the MT5 EA execution logic yet. The current purpose is to collect and inspect market data sources:

它目前未屬於 MT5 EA 執行邏輯。現階段用途是收集及檢查市場數據來源：

- USDJPY OHLC.
- USDJPY OHLC。
- US rates and macro indicators.
- 美國利率及宏觀指標。
- Finviz-style market headlines.
- Finviz 風格市場 headline。
- Headline deltas between repeated downloads.
- 多次下載之間的 headline 變化。

The project remains advisory only. It must not place trades, modify Expert Advisors, trigger entries, set stops or targets, size positions, or override any trading-system risk controls.

本項目只作建議用途。它不可落盤、修改 Expert Advisor、觸發入場、設定止損或目標、決定倉位大小，或覆蓋任何交易系統風控。

## 2. Current Scope / 目前範圍

In scope / 會做：

- Inspect data-source quality and usefulness.
- 檢查資料源質素及實用性。
- Save raw source responses before processing.
- 在處理前保存 source raw responses。
- Produce preview CSVs for manual review.
- 產生 preview CSV 供人工 review。
- Compare repeated Finviz headline downloads.
- 比較重複 Finviz headline 下載。
- Keep output artifacts traceable to local files.
- 保持 output artifacts 可追溯至本地檔案。

Out of scope / 不會做：

- No MT5 trade execution.
- 不做 MT5 trade execution。
- No EA modification.
- 不修改 EA。
- No automatic buy or sell entries.
- 不自動開 buy 或 sell 單。
- No live news-spike trading.
- 不做 live news-spike trading。
- No final Daily Market Analysis report generation yet.
- 尚未產生正式 Daily Market Analysis 報告。
- No fixed v1 YAML schema changes.
- 不改 fixed v1 YAML schema。
- No trading logic.
- 不加入 trading logic。

## 3. Data Source Roles / 資料源角色

### Primary Headline Source: Finviz Elite News Export / 主要 Headline 來源：Finviz Elite News Export

Finviz Elite News Export is now the primary market headline source.

Finviz Elite News Export 目前是主要 market headline 來源。

Confirmed details / 已確認細節：

- News page URL: `https://elite.finviz.com/news?v=1`
- News page URL：`https://elite.finviz.com/news?v=1`
- News export URL: `https://elite.finviz.com/export/news?v=1`
- News export URL：`https://elite.finviz.com/export/news?v=1`
- Real request uses the Finviz auth token in the URL.
- 真實 request 會在 URL 內使用 Finviz auth token。
- Response content type: `text/csv`.
- Response content type：`text/csv`。
- Detected CSV headers: `Title`, `Source`, `Date`, `Url`, `Category`.
- 已偵測 CSV headers：`Title`、`Source`、`Date`、`Url`、`Category`。
- Live result returned 180 headlines.
- live result 回傳 180 條 headline。
- Encoding fixed using `response.content` and `utf-8-sig`.
- encoding 已用 `response.content` 及 `utf-8-sig` 修正。
- Mojibake examples fixed included `Castlelake’s`, `£5 Billion`, and `‘Minions’`.
- 已修正亂碼例子包括 `Castlelake’s`、`£5 Billion`、`‘Minions’`。

Responsible script / 負責 script：

```text
src/fetch_finviz_news_api.py
```

This script performs one configurable Finviz Elite export request, saves the raw CSV, creates a preview CSV, and extracts headline-level market context only. It does not follow article links, scrape article bodies, generate final reports, modify YAML schema, or add trading logic.

此 script 執行一次可設定的 Finviz Elite export request，保存 raw CSV，產生 preview CSV，並只抽取 headline-level market context。它不跟隨 article link、不 scrape article body、不產生正式報告、不修改 YAML schema、不加入 trading logic。

### Secondary Finviz Source: Free News Page Scrape / 次要 Finviz 來源：免費新聞頁 Scrape

Responsible script / 負責 script：

```text
src/fetch_finviz_headlines.py
```

This was tested successfully and returned 175 headlines in a live test. It is useful as a Finviz-style headline tape, but the Elite CSV export is the current primary source.

此 script 已成功測試，live test 回傳 175 條 headline。它可作 Finviz-style headline tape，但目前主要來源是 Elite CSV export。

### Structured Context Source: Alpha Vantage / 結構化背景來源：Alpha Vantage

Alpha Vantage structured data has been tested successfully for:

Alpha Vantage structured data 已成功測試：

- `FX_DAILY` USDJPY.
- `FX_DAILY` USDJPY。
- `FX_WEEKLY` USDJPY.
- `FX_WEEKLY` USDJPY。
- `TREASURY_YIELD` 10Y daily.
- `TREASURY_YIELD` 10Y daily。
- `TREASURY_YIELD` 2Y daily.
- `TREASURY_YIELD` 2Y daily。
- `FEDERAL_FUNDS_RATE` daily.
- `FEDERAL_FUNDS_RATE` daily。
- `CPI` monthly.
- `CPI` monthly。

Alpha Vantage structured data is useful for:

Alpha Vantage structured data 適合用於：

- USDJPY daily OHLC reference.
- USDJPY daily OHLC 參考。
- USDJPY weekly OHLC reference.
- USDJPY weekly OHLC 參考。
- Previous day high-low-close calculations.
- 前一日 high-low-close 計算。
- Previous week high-low-close calculations.
- 前一週 high-low-close 計算。
- US 10Y yield context.
- 美國 10 年期債息背景。
- US 2Y yield context.
- 美國 2 年期債息背景。
- Fed funds policy regime.
- Fed funds 政策 regime。
- CPI inflation background.
- CPI 通脹背景。

Responsible script / 負責 script：

```text
src/fetch_alpha_vantage_structured.py
```

Supported query names / 支援 query names：

```text
fx_daily
fx_weekly
treasury_yield_10y
treasury_yield_2y
fed_funds
cpi
inflation
unemployment
nonfarm_payroll
```

Cautions / 注意：

- Treasury Yield and Federal Funds Rate may lag the current date, especially around weekends and holidays.
- Treasury Yield 及 Federal Funds Rate 可能滯後於當前日期，尤其週末及假期附近。
- CPI is monthly and naturally slow.
- CPI 是月度數據，本身自然較慢。
- These are macro context sources, not live intraday execution signals.
- 這些是 macro context sources，不是 live intraday execution signals。
- Alpha Vantage quota should be protected by running one query at a time.
- Alpha Vantage quota 應透過每次只跑一個 query 保護。

Rejected Alpha Vantage source / 已否決 Alpha Vantage 來源：

- `NEWS_SENTIMENT` with `economy_macro` was manually reviewed and rejected.
- `NEWS_SENTIMENT` 加 `economy_macro` 已人工 review 並否決。
- `NEWS_SENTIMENT` with `economy_monetary` was manually reviewed and rejected.
- `NEWS_SENTIMENT` 加 `economy_monetary` 已人工 review 並否決。
- Do not reopen these two topics unless explicitly requested.
- 除非明確要求，否則不要重新開啟這兩個 topics。

### Secondary OHLC Source: Twelve Data / 次要 OHLC 來源：Twelve Data

Responsible script / 負責 script：

```text
src/fetch_twelve_data_usdjpy_daily.py
```

Twelve Data has been tested successfully for USDJPY daily `time_series`. It currently provides usable USDJPY daily OHLC inspection.

Twelve Data 已成功測試 USDJPY daily `time_series`。它目前可提供可用的 USDJPY daily OHLC inspection。

Current role / 目前角色：

- Secondary or comparison OHLC source.
- secondary 或 comparison OHLC source。
- Not a primary headline source.
- 不是 primary headline source。
- Do not claim Twelve Data provides economic data or market news unless separately confirmed.
- 除非另行確認，否則不要聲稱 Twelve Data 提供 economic data 或 market news。

### Backup / Comparison Headline Source: NewsAPI.org / 後備及比較 Headline 來源：NewsAPI.org

Responsible script / 負責 script：

```text
src/fetch_newsapi_market_headlines.py
```

NewsAPI.org is implemented as a backup and comparison source for market headlines. It has not replaced Finviz. Finviz Elite News Export remains primary.

NewsAPI.org 已作為 market headline 的 backup / comparison source 實作。它尚未取代 Finviz。Finviz Elite News Export 仍然是 primary。

### Low-Priority Experiment: Yahoo Finance / 低優先級實驗：Yahoo Finance

Responsible script / 負責 script：

```text
src/fetch_yahoo_market_headlines.py
```

The Yahoo Finance headline scrape returned 31 headings in a live test, but many were personal finance or SEO content. The current Yahoo article-page scrape is noisy and not suitable as the primary market tape.

Yahoo Finance headline scrape 在 live test 回傳 31 條 heading，但很多是 personal finance 或 SEO content。目前 Yahoo article-page scrape 雜訊較多，不適合作 primary market tape。

Keep it as a low-priority experiment or possible future backup.

保留為 low-priority experiment 或日後可能的 backup。

## 4. Current Scripts and Responsibilities / 目前 Scripts 及職責

| Script | Responsibility / 職責 | Current role / 目前角色 |
|---|---|---|
| `src/fetch_finviz_news_api.py` | Fetch Finviz Elite News Export CSV, save raw and preview files / 下載 Finviz Elite News Export CSV，保存 raw 及 preview files | Primary headline fetch / 主要 headline fetch |
| `src/compare_finviz_headline_deltas.py` | Compare two local Finviz preview CSV files / 比較兩個本地 Finviz preview CSV files | Current headline review workflow / 目前 headline review workflow |
| `src/fetch_finviz_headlines.py` | Scrape Finviz free news page headings / scrape Finviz 免費新聞頁 headings | Secondary Finviz-style tape / 次要 Finviz-style tape |
| `src/fetch_alpha_vantage_structured.py` | Fetch one Alpha Vantage structured-data query / 下載一個 Alpha Vantage structured-data query | Structured FX/rates/macro context / 結構化 FX、rates、macro context |
| `src/fetch_twelve_data_usdjpy_daily.py` | Fetch Twelve Data USDJPY daily OHLC / 下載 Twelve Data USDJPY daily OHLC | Secondary OHLC comparison / 次要 OHLC comparison |
| `src/fetch_newsapi_market_headlines.py` | Fetch NewsAPI market headline sample / 下載 NewsAPI market headline sample | Backup/comparison headline source / 後備及比較 headline source |
| `src/fetch_yahoo_market_headlines.py` | Fetch Yahoo Finance market headings / 下載 Yahoo Finance market headings | Low-priority noisy experiment / 低優先級 noisy experiment |
| `src/fetch_alpha_vantage_news.py` | Historical Alpha Vantage news inspection / 歷史 Alpha Vantage news inspection | Rejected topics; do not reopen unless requested / 已否決 topics；除非要求否則不要重開 |

## 5. File Naming Conventions / 檔案命名規則

### Finviz Elite Raw CSV / Finviz Elite Raw CSV

```text
output/raw/fv_api_news_YYYYMMDD_HHMMSS_SUFFIX.csv
```

### Finviz Elite Preview CSV / Finviz Elite Preview CSV

```text
output/logs/fv_api_preview_news_YYYYMMDD_HHMMSS_SUFFIX.csv
```

Suffix rule / suffix 規則：

- First download of the date: `_a`
- 同一日期第一次下載：`_a`
- Second download of the date: `_b`
- 同一日期第二次下載：`_b`
- Third download: `_c`
- 第三次下載：`_c`
- Continue to `_z`, then `_aa`, `_ab`, and so on.
- 繼續至 `_z`，之後 `_aa`、`_ab` 如此類推。

Live confirmed examples / live 已確認例子：

```text
output/raw/fv_api_news_20260705_195441_a.csv
output/logs/fv_api_preview_news_20260705_195441_a.csv
output/raw/fv_api_news_20260705_220306_b.csv
output/logs/fv_api_preview_news_20260705_220306_b.csv
```

### Finviz Headline Delta Outputs / Finviz Headline Delta 輸出

```text
output/logs/fv_delta_news_YYYYMMDD_HHMMSS.csv
output/reports/fv_delta_news_YYYYMMDD_HHMMSS.md
```

### Alpha Vantage Structured Outputs / Alpha Vantage Structured 輸出

Examples / 例子：

```text
output/raw/av_fx_daily_YYYYMMDD_HHMMSS.json
output/logs/av_preview_fx_daily_YYYYMMDD_HHMMSS.csv
output/raw/av_fx_weekly_YYYYMMDD_HHMMSS.json
output/logs/av_preview_fx_weekly_YYYYMMDD_HHMMSS.csv
output/raw/av_ty10_daily_YYYYMMDD_HHMMSS.json
output/logs/av_preview_ty10_daily_YYYYMMDD_HHMMSS.csv
output/raw/av_ty2_daily_YYYYMMDD_HHMMSS.json
output/logs/av_preview_ty2_daily_YYYYMMDD_HHMMSS.csv
output/raw/av_fedfunds_daily_YYYYMMDD_HHMMSS.json
output/logs/av_preview_fedfunds_daily_YYYYMMDD_HHMMSS.csv
output/raw/av_cpi_monthly_YYYYMMDD_HHMMSS.json
output/logs/av_preview_cpi_monthly_YYYYMMDD_HHMMSS.csv
```

### Twelve Data Outputs / Twelve Data 輸出

```text
output/raw/td_usdjpy_daily_YYYYMMDD_HHMMSS.json
output/logs/td_preview_usdjpy_daily_YYYYMMDD_HHMMSS.csv
```

## 6. Finviz Headline Delta Workflow / Finviz Headline Delta 工作流程

Implemented script / 已實作 script：

```text
src/compare_finviz_headline_deltas.py
```

Purpose:

用途：

Compare two local Finviz preview CSV files and identify headline changes.

比較兩個本地 Finviz preview CSV files，找出 headline 變化。

CLI example / CLI 例子：

```bash
python3 src/compare_finviz_headline_deltas.py \
  --old output/logs/fv_api_preview_news_20260705_195441_a.csv \
  --new output/logs/fv_api_preview_news_20260705_220306_b.csv
```

Live test result / live test 結果：

- New headline count: 8
- 新增 headline 數量：8
- Removed headline count: 8
- 移除 headline 數量：8
- Unchanged headline count: 172
- 不變 headline 數量：172

The purpose is to avoid rereading all 180 headlines. The user only needs to review newly added or removed headlines between downloads.

目的係避免重讀全部 180 條 headline。用戶只需要 review 兩次下載之間新增或移除的 headline。

## 7. Environment Variables / 環境變數

Real secrets remain outside the project:

真實 secrets 保持在 project 外：

```text
/Users/avislai/Documents/.key/.env_DMA
```

Do not ask the user to store real keys in the project root.

不要要求用戶把真實 keys 存在 project root。

The project `.env_DMA.example` should document these placeholders:

project 內 `.env_DMA.example` 應記錄以下 placeholders：

```text
ALPHA_VANTAGE_API_KEY=your_alpha_vantage_api_key_here
TWELVE_DATA_API_KEY=your_twelve_data_api_key_here
FINVIZ_API_KEY=your_finviz_api_token_here
FINVIZ_NEWS_API_URL=https://elite.finviz.com/export/news?v=1
NEWSAPI_API_KEY=your_newsapi_api_key_here
```

## 8. Current Practical Workflow / 目前實際工作流程

Step 1: fetch Finviz Elite headlines.

步驟 1：下載 Finviz Elite headlines。

```bash
python3 src/fetch_finviz_news_api.py
```

Step 2: compare two Finviz downloads.

步驟 2：比較兩次 Finviz 下載。

```bash
python3 src/compare_finviz_headline_deltas.py \
  --old output/logs/fv_api_preview_news_YYYYMMDD_HHMMSS_a.csv \
  --new output/logs/fv_api_preview_news_YYYYMMDD_HHMMSS_b.csv
```

Step 3: review the delta Markdown or CSV manually, or send it to AI for market mood interpretation.

步驟 3：人工 review delta Markdown 或 CSV，或交給 AI 解讀市場氣氛。

## 9. Known Warnings and Limitations / 已知警告及限制

Known warning / 已知 warning：

- `NotOpenSSLWarning` may appear on macOS Python because urllib3 v2 expects OpenSSL 1.1.1+ but Apple Python may use LibreSSL 2.8.3.
- macOS Python 可能出現 `NotOpenSSLWarning`，因為 urllib3 v2 期望 OpenSSL 1.1.1+，但 Apple Python 可能使用 LibreSSL 2.8.3。
- It is currently only a warning because Finviz requests still returned HTTP 200.
- 目前它只是 warning，因為 Finviz requests 仍然回傳 HTTP 200。
- It can be cleaned later with Homebrew Python, a virtual environment, or dependency cleanup, but it is not blocking the current workflow.
- 日後可用 Homebrew Python、virtual environment 或 dependency cleanup 清理，但目前不阻塞 workflow。

Current limitations / 目前限制：

- Finviz headline collection does not yet produce a formal market mood classification.
- Finviz headline collection 尚未產生正式 market mood classification。
- Finviz and Alpha Vantage context are not yet merged into a Daily Market Analysis report.
- Finviz 與 Alpha Vantage context 尚未合併成 Daily Market Analysis report。
- The final Markdown Daily Market Analysis report is not implemented.
- 正式 Markdown Daily Market Analysis report 尚未實作。
- Advisory YAML export is not implemented in the current prototype.
- 目前 prototype 尚未實作 advisory YAML export。
- The fixed v1 YAML schema must remain unchanged.
- fixed v1 YAML schema 必須保持不變。
- No MT5 EA execution integration exists.
- 尚未有 MT5 EA execution integration。

## 10. Fixed v1 Advisory YAML Schema / 固定 v1 建議性 YAML Schema

The v1 YAML schema remains fixed for future use. Do not rename fields, remove fields, or invent alternatives.

v1 YAML schema 保持固定供日後使用。不要改名、刪欄位，或自創替代欄位。

Planned output path / 計劃輸出路徑：

```text
output/reports/daily_market_bias_YYYYMMDD.yaml
```

Fixed v1 schema / 固定 v1 schema：

```yaml
date: YYYY-MM-DD
generated_at_utc: ISO timestamp
report_time_local: "07:00 UK"
symbol: USDJPY
data_quality:
  source_count: integer
  headline_count: integer
  relevant_headline_count: integer
  best_source: string
  warnings: []
daily_bias:
  direction: buy_only | sell_only | both | no_trade
  confidence: integer 0-100
  trade_mode: normal | caution | no_trade
allowed_direction:
  buy: true/false
  sell: true/false
market_context:
  usd_bias: bullish | bearish | neutral | mixed
  jpy_bias: bullish | bearish | neutral | mixed
  risk_sentiment: risk_on | risk_off | neutral | mixed
  us_yields_bias: rising | falling | neutral | unknown
news_risk:
  high_impact_today: true/false
  avoid_before_minutes: integer
  avoid_after_minutes: integer
  major_events: []
reason_summary:
  - string
invalid_if:
  - string
api_evaluation:
  tested_sources: []
  selected_primary_source: string
  selected_backup_source: string
notes: []
```

This YAML is advisory only and must not trigger trades directly.

此 YAML 只作建議用途，絕不可直接觸發交易。

## 11. Short Future Work / 簡短未來工作

- Convert the Finviz headline tape into market mood classification.
- 將 Finviz headline tape 轉成 market mood classification。
- Merge Finviz headline context with Alpha Vantage FX/rates data.
- 合併 Finviz headline context 與 Alpha Vantage FX/rates data。
- Generate the Daily Market Analysis report.
- 產生 Daily Market Analysis report。
- Later export advisory YAML for EA bias filters.
- 日後 export advisory YAML 供 EA bias filters 參考。
- Do not connect to EA execution yet.
- 暫時不要連接 EA execution。

## 12. Safety Notes / 安全備註

- This module must remain separate from MT5 execution code.
- 本模組必須與 MT5 execution code 分開。
- Generated files are advisory research artifacts only.
- 產生檔案只屬 advisory research artifacts。
- No file from this module should place, modify, close, or manage trades.
- 本模組任何檔案都不應開倉、改倉、平倉或管理交易。
- Any future integration with `Full-Auto-MT5-Bot` requires a separate review and explicit approval.
- 日後如要整合入 `Full-Auto-MT5-Bot`，必須另行 review 並明確批准。
