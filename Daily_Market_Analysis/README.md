# Daily Market Analysis / 每日市場分析

Status / 狀態: working market-data prototype / 可運作的市場數據原型  
Symbol / 交易品種: USDJPY  
Report time target / 報告目標時間: 07:00 UK / 英國時間 07:00  
Project path / 項目路徑: `/Users/avislai/Documents/Codex/Toolbox/Daily_Market_Analysis`

Daily_Market_Analysis is an experimental toolbox for building Daily Market Analysis context for USDJPY. It is currently used to collect and inspect market data sources, not to execute trades.

Daily_Market_Analysis 是一個實驗性工具箱，用來建立 USDJPY 每日市場分析背景。現階段用途是收集及檢查市場數據來源，不是用來執行交易。

The project is separate from MT5 EA execution logic. Outputs are advisory research artifacts only and must not place trades, modify an EA, trigger entries, change risk controls, or make live execution decisions.

本項目與 MT5 EA 執行邏輯分開。所有輸出只屬研究及建議用途，不可落盤、修改 EA、觸發入場、更改風控，或作即時交易執行決策。

## Current Purpose / 目前用途

The current prototype collects and inspects:

目前原型會收集及檢查：

- USDJPY OHLC data.
- USDJPY OHLC 數據。
- US rates and macro indicators.
- 美國利率及宏觀指標。
- Finviz-style market headlines.
- Finviz 風格市場 headline。
- Headline deltas between repeated Finviz downloads.
- 多次 Finviz 下載之間的 headline 變化。

The practical goal is to reduce the amount of manual headline reading before a later Daily Market Analysis report generator exists.

實際目標是在日後正式 Daily Market Analysis 報告產生器完成之前，先減少人工重讀 headline 的工作量。

## Working Data Sources / 目前可用資料源

### Finviz Elite News Export / Finviz Elite 新聞匯出

Finviz Elite News Export is the current primary market headline source.

Finviz Elite News Export 是目前主要市場 headline 來源。

Tested workflow / 已測試流程：

- News page / 新聞頁: `https://elite.finviz.com/news?v=1`
- News export / 新聞匯出: `https://elite.finviz.com/export/news?v=1`
- Real request uses the Finviz auth token in the URL.
- 真實 request 會在 URL 內使用 Finviz auth token。
- Response content type is `text/csv`.
- Response content type 是 `text/csv`。
- Detected CSV headers: `Title`, `Source`, `Date`, `Url`, `Category`.
- 已偵測 CSV headers: `Title`, `Source`, `Date`, `Url`, `Category`。
- Live test returned 180 headlines.
- live test 回傳 180 條 headline。
- Encoding was fixed by decoding `response.content` with `utf-8-sig`.
- encoding 已透過 `response.content` 加 `utf-8-sig` 修正。
- Mojibake examples fixed included `Castlelake’s`, `£5 Billion`, and `‘Minions’`.
- 已修正亂碼例子包括 `Castlelake’s`、`£5 Billion`、`‘Minions’`。

Run / 執行：

```bash
python3 src/fetch_finviz_news_api.py
```

Outputs / 輸出：

```text
output/raw/fv_api_news_YYYYMMDD_HHMMSS_SUFFIX.csv
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

### Finviz Free News Page Scrape / Finviz 免費新聞頁 scrape

`src/fetch_finviz_headlines.py` was tested successfully against the free Finviz news page and returned 175 headlines in a live test.

`src/fetch_finviz_headlines.py` 已成功測試 Finviz 免費新聞頁，live test 回傳 175 條 headline。

This is useful as a Finviz-style market headline tape, but Finviz Elite News Export is now the primary headline source.

它可作 Finviz 風格市場 headline tape，但目前主要 headline 來源是 Finviz Elite News Export。

### Alpha Vantage Structured Data / Alpha Vantage 結構化數據

Alpha Vantage structured data has been tested successfully for:

Alpha Vantage 結構化數據已成功測試：

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

Alpha Vantage is useful for:

Alpha Vantage 適合用於：

- USDJPY daily OHLC reference.
- USDJPY daily OHLC 參考。
- USDJPY weekly OHLC reference.
- USDJPY weekly OHLC 參考。
- Previous day and previous week high-low-close calculations.
- 前一日及前一週 high-low-close 計算。
- US 10Y yield context.
- 美國 10 年期債息背景。
- US 2Y yield context.
- 美國 2 年期債息背景。
- Fed funds policy regime.
- Fed funds 政策 regime 背景。
- CPI inflation background.
- CPI 通脹背景。

Run one structured query at a time / 每次只執行一個 structured query：

```bash
python3 src/fetch_alpha_vantage_structured.py --query fx_daily
python3 src/fetch_alpha_vantage_structured.py --query fx_weekly
python3 src/fetch_alpha_vantage_structured.py --query treasury_yield_10y
python3 src/fetch_alpha_vantage_structured.py --query treasury_yield_2y
python3 src/fetch_alpha_vantage_structured.py --query fed_funds
python3 src/fetch_alpha_vantage_structured.py --query cpi
```

Cautions / 注意：

- Treasury Yield and Federal Funds Rate may lag the current date, especially around weekends and holidays.
- Treasury Yield 及 Federal Funds Rate 可能滯後於當前日期，尤其週末及假期附近。
- CPI is monthly and naturally slow.
- CPI 是月度數據，本身自然較慢。
- These datasets are macro context, not live intraday execution signals.
- 這些數據只作宏觀背景，不是即時 intraday 執行信號。

Rejected Alpha Vantage source / 已否決 Alpha Vantage 來源：

- `NEWS_SENTIMENT` with `economy_macro` was manually reviewed and rejected.
- `NEWS_SENTIMENT` 加 `economy_macro` 已人工檢查並否決。
- `NEWS_SENTIMENT` with `economy_monetary` was manually reviewed and rejected.
- `NEWS_SENTIMENT` 加 `economy_monetary` 已人工檢查並否決。
- Do not reopen these two topics unless explicitly requested.
- 除非明確要求，否則不要重新開啟這兩個 topics。

### Twelve Data / Twelve Data

`src/fetch_twelve_data_usdjpy_daily.py` was tested successfully for USDJPY daily `time_series`.

`src/fetch_twelve_data_usdjpy_daily.py` 已成功測試 USDJPY daily `time_series`。

Twelve Data currently provides usable USDJPY daily OHLC inspection. It is a secondary or comparison source. Do not treat it as an economic-data or market-news source unless those endpoints are separately confirmed.

Twelve Data 目前可提供可用的 USDJPY daily OHLC 檢查。它是 secondary / comparison 來源。除非相關 endpoint 另行確認，否則不要把它當成 economic data 或 market news 來源。

### NewsAPI.org / NewsAPI.org

`src/fetch_newsapi_market_headlines.py` exists as a backup and comparison source for market headlines.

`src/fetch_newsapi_market_headlines.py` 是 market headline 的 backup / comparison 來源。

It has not replaced Finviz. Finviz Elite News Export remains the primary market headline source.

它尚未取代 Finviz。Finviz Elite News Export 仍然是主要市場 headline 來源。

### Yahoo Finance / Yahoo Finance

`src/fetch_yahoo_market_headlines.py` returned 31 headings in a live test, but many were personal finance or SEO-style items.

`src/fetch_yahoo_market_headlines.py` 在 live test 回傳 31 條 heading，但當中很多是 personal finance 或 SEO 內容。

The current Yahoo article-page scrape is noisy and is not suitable as the primary market tape. Keep it as a low-priority experiment or possible future backup.

目前 Yahoo article-page scrape 雜訊較多，不適合作主要 market tape。保留為低優先級實驗或日後 backup。

## Current Manual Workflow / 目前人工流程

Step 1: fetch Finviz Elite headlines.

步驟 1：下載 Finviz Elite headlines。

```bash
python3 src/fetch_finviz_news_api.py
```

Step 2: compare two Finviz preview downloads.

步驟 2：比較兩次 Finviz preview 下載。

```bash
python3 src/compare_finviz_headline_deltas.py \
  --old output/logs/fv_api_preview_news_YYYYMMDD_HHMMSS_a.csv \
  --new output/logs/fv_api_preview_news_YYYYMMDD_HHMMSS_b.csv
```

Step 3: review the delta Markdown or CSV manually, or send it to AI for market mood interpretation.

步驟 3：人工查看 delta Markdown / CSV，或交給 AI 解讀市場氣氛。

This lets the user avoid rereading the full headline tape. In the confirmed live comparison, the script found:

這樣可避免重讀整份 headline tape。已確認 live comparison 結果：

- New headline count: 8
- 新增 headline 數量：8
- Removed headline count: 8
- 移除 headline 數量：8
- Unchanged headline count: 172
- 不變 headline 數量：172

Delta outputs / delta 輸出：

```text
output/logs/fv_delta_news_YYYYMMDD_HHMMSS.csv
output/reports/fv_delta_news_YYYYMMDD_HHMMSS.md
```

## Environment Setup / 環境設定

The real secrets file remains outside the project:

真實 secrets file 保持在 project 外：

```text
/Users/avislai/Documents/.key/.env_DMA
```

Do not store real keys in the project root.

不要把真實 key 存在 project root。

The project-level `.env_DMA.example` should document these placeholders:

project 內的 `.env_DMA.example` 應記錄以下 placeholder：

```text
ALPHA_VANTAGE_API_KEY=your_alpha_vantage_api_key_here
TWELVE_DATA_API_KEY=your_twelve_data_api_key_here
FINVIZ_API_KEY=your_finviz_api_token_here
FINVIZ_NEWS_API_URL=https://elite.finviz.com/export/news?v=1
NEWSAPI_API_KEY=your_newsapi_api_key_here
```

## Output Locations / 輸出位置

Raw downloaded data / 原始下載數據：

```text
output/raw/
```

Human-readable preview CSVs and comparison CSVs / 人類可讀 preview CSV 及 comparison CSV：

```text
output/logs/
```

Markdown reports / Markdown 報告：

```text
output/reports/
```

## Known Warnings / 已知警告

On macOS Python, `NotOpenSSLWarning` may appear because urllib3 v2 expects OpenSSL 1.1.1+ while Apple Python may use LibreSSL 2.8.3.

在 macOS Python，可能會出現 `NotOpenSSLWarning`，因為 urllib3 v2 期望 OpenSSL 1.1.1+，但 Apple Python 可能使用 LibreSSL 2.8.3。

This is currently only a warning because Finviz requests still returned HTTP 200. It can be cleaned later with Homebrew Python, a virtual environment, or dependency cleanup, but it is not blocking the current workflow.

目前它只是一個 warning，因為 Finviz request 仍然回傳 HTTP 200。日後可用 Homebrew Python、virtual environment 或 dependency cleanup 處理，但目前不阻塞工作流程。

## Not Implemented Yet / 尚未實作

- No final Daily Market Analysis report generator.
- 尚未有正式 Daily Market Analysis report generator。
- No market mood classifier.
- 尚未有 market mood classifier。
- No merged Finviz plus Alpha Vantage context report.
- 尚未合併 Finviz 與 Alpha Vantage context report。
- No advisory YAML generation from this prototype.
- 目前 prototype 尚未產生 advisory YAML。
- No connection to MT5 EA execution.
- 尚未連接 MT5 EA execution。
- No trading logic.
- 沒有 trading logic。
- No live intraday execution signal.
- 沒有 live intraday execution signal。

## Safety Rule / 安全規則

This project is advisory market analysis only. It is not a trading execution system, and no output should be treated as an order, entry signal, stop-loss instruction, take-profit instruction, or risk-control override.

本項目只作建議性市場分析。它不是交易執行系統，任何輸出都不應被視為訂單、入場信號、止損指令、止盈指令，或風控覆蓋。
