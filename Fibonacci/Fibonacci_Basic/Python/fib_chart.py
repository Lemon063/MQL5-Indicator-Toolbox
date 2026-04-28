"""
fib_chart.py
讀取 Fibonacci.mq5 輸出嘅 CSV，結合 MT5 OHLC 數據，
用 Plotly 畫 interactive chart 驗證 Fib 錨點同線嘅準確性。

依賴：
    pip install MetaTrader5 pandas plotly

CSV 路徑（MT5 Files 資料夾）：
    macOS + Wine:
    ~/Library/Application Support/net.metaquotes.wine.metatrader5/
    drive_c/Program Files/MetaTrader 5/MQL5/Files/FibAnchors.csv
"""

import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from datetime import datetime, timedelta
import MetaTrader5 as mt5
import os

# ── 設定 ──────────────────────────────────────────────────────────────
SYMBOL      = "USDJPY"
MT5_TF      = mt5.TIMEFRAME_H1   # 改做 mt5.TIMEFRAME_M5 睇 M5
BARS_BEFORE = 20   # 錨點之前顯示幾多 bars
BARS_AFTER  = 50   # 錨點之後顯示幾多 bars

CSV_PATH = os.path.expanduser(
    "~/Library/Application Support/net.metaquotes.wine.metatrader5/"
    "drive_c/Program Files/MetaTrader 5/MQL5/Files/FibAnchors.csv"
)

FIB_COLORS = {
    "fib_236":  "#FFD700",   # 金
    "fib_382":  "#FFA500",   # 橙
    "fib_500":  "#FF8C00",   # 深橙
    "fib_618":  "#FF4500",   # 橙紅（最重要）
    "fib_786":  "#FF0000",   # 紅
    "fib_1000": "#FFFFFF",   # 白（swing high）
    "fib_1618": "#9370DB",   # 紫
    "fib_2618": "#800080",   # 深紫
    "fib_3618": "#4B0082",   # 暗紫
}

FIB_LABELS = {
    "fib_236": "0.236", "fib_382": "0.382", "fib_500": "0.500",
    "fib_618": "0.618", "fib_786": "0.786", "fib_1000": "1.000",
    "fib_1618": "1.618", "fib_2618": "2.618", "fib_3618": "3.618",
}

FIB_WIDTHS = {
    "fib_618": 2, "fib_1000": 2, "fib_3618": 2,
}

# ── 讀 CSV ────────────────────────────────────────────────────────────
def load_csv(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    df["bar_time"]      = pd.to_datetime(df["bar_time"])
    df["high_bar_time"] = pd.to_datetime(df["high_bar_time"])
    df["low_bar_time"]  = pd.to_datetime(df["low_bar_time"])
    print(f"✅ 讀取 {len(df)} 行 | mode: {df['mode'].unique()} | {df['bar_time'].min()} → {df['bar_time'].max()}")
    return df

# ── 連接 MT5 + 拎 OHLC ───────────────────────────────────────────────
def get_ohlc(symbol: str, tf, date_from: datetime, date_to: datetime) -> pd.DataFrame:
    if not mt5.initialize():
        raise RuntimeError(f"MT5 初始化失敗: {mt5.last_error()}")

    rates = mt5.copy_rates_range(symbol, tf, date_from, date_to)
    mt5.shutdown()

    if rates is None or len(rates) == 0:
        raise RuntimeError(f"冇數據: {mt5.last_error()}")

    df = pd.DataFrame(rates)
    df["time"] = pd.to_datetime(df["time"], unit="s")
    return df

# ── 畫單個 Fib snapshot ───────────────────────────────────────────────
def plot_fib_snapshot(ohlc: pd.DataFrame, row: pd.Series, idx: int, total: int):
    """
    每個 CSV row = 一個錨點 snapshot
    畫嗰段時間嘅 candlestick + 所有 Fib levels
    """
    t_center = row["bar_time"]
    tf_delta = ohlc["time"].diff().median()

    t_start = t_center - tf_delta * BARS_BEFORE
    t_end   = t_center + tf_delta * BARS_AFTER

    mask = (ohlc["time"] >= t_start) & (ohlc["time"] <= t_end)
    chunk = ohlc[mask]

    if chunk.empty:
        print(f"  ⚠️ [{idx+1}/{total}] {t_center} — 冇 OHLC 數據，跳過")
        return None

    fig = go.Figure()

    # Candlestick
    fig.add_trace(go.Candlestick(
        x=chunk["time"],
        open=chunk["open"], high=chunk["high"],
        low=chunk["low"],   close=chunk["close"],
        name="OHLC",
        increasing_line_color="#26a69a",
        decreasing_line_color="#ef5350",
    ))

    # Fib lines
    for col, color in FIB_COLORS.items():
        if col not in row.index or pd.isna(row[col]):
            continue
        price  = float(row[col])
        label  = FIB_LABELS[col]
        width  = FIB_WIDTHS.get(col, 1)
        dash   = "dot" if col in ("fib_236", "fib_382", "fib_1618", "fib_2618") else "solid"

        fig.add_hline(
            y=price,
            line_color=color,
            line_width=width,
            line_dash=dash,
            annotation_text=f"{label}  {price:.5f}",
            annotation_position="right",
            annotation_font_color=color,
            annotation_font_size=10,
        )

    # 錨點 marker（High + Low bar 位置）
    high_t = row["high_bar_time"]
    low_t  = row["low_bar_time"]

    fig.add_trace(go.Scatter(
        x=[high_t], y=[float(row["high_price"])],
        mode="markers+text",
        marker=dict(symbol="triangle-down", size=12, color="white"),
        text=["High anchor"], textposition="top center",
        name="Pivot High",
    ))
    fig.add_trace(go.Scatter(
        x=[low_t], y=[float(row["low_price"])],
        mode="markers+text",
        marker=dict(symbol="triangle-up", size=12, color="skyblue"),
        text=["Low anchor"], textposition="bottom center",
        name="Pivot Low",
    ))

    # 垂直線標記「錨點計算時間」
    fig.add_vline(x=t_center, line_dash="dash", line_color="gray", line_width=1)

    direction = row["is_buy"]
    mode      = row["mode"]
    fig.update_layout(
        title=f"[{idx+1}/{total}] {SYMBOL} {mode} {direction} | "
              f"{t_center.strftime('%Y-%m-%d %H:%M')} | "
              f"High:{row['high_price']:.5f} (bar {row['high_bar']}) "
              f"Low:{row['low_price']:.5f} (bar {row['low_bar']}) | "
              f"Range:{row['range_pips']} pips | "
              f"Overlap:{row['overlap']} Score:{row['score']}",
        xaxis_rangeslider_visible=False,
        template="plotly_dark",
        height=700,
        paper_bgcolor="#1a1a2e",
        plot_bgcolor="#1a1a2e",
        font=dict(color="white"),
    )
    fig.update_xaxis(showgrid=True, gridcolor="#333")
    fig.update_yaxis(showgrid=True, gridcolor="#333")

    return fig

# ── 主程式 ────────────────────────────────────────────────────────────
def main():
    print("=" * 60)
    print("Fibonacci Anchor Visualizer")
    print("=" * 60)

    # 1. 讀 CSV
    df = load_csv(CSV_PATH)

    # 過濾 mode（可改 "M5" 或 "H1"）
    # df = df[df["mode"] == "H1"]

    if df.empty:
        print("CSV 冇數據")
        return

    # 2. 拎 OHLC（覆蓋整個 CSV 時間範圍 + buffer）
    t_from = df["bar_time"].min() - timedelta(hours=BARS_BEFORE * 2)
    t_to   = df["bar_time"].max() + timedelta(hours=BARS_AFTER * 2)

    print(f"\n📡 連接 MT5 拎 {SYMBOL} OHLC ({t_from} → {t_to})...")
    ohlc = get_ohlc(SYMBOL, MT5_TF, t_from, t_to)
    print(f"✅ 拎到 {len(ohlc)} 根 bars")

    # 3. 逐個 snapshot 畫圖
    print(f"\n📊 畫 {len(df)} 個 Fib snapshot...")

    # 全部存入 HTML（一個 file 多個圖）
    from plotly.io import to_html
    all_html = []

    for i, (_, row) in enumerate(df.iterrows()):
        fig = plot_fib_snapshot(ohlc, row, i, len(df))
        if fig is not None:
            all_html.append(to_html(fig, full_html=False, include_plotlyjs=(i == 0)))
            print(f"  ✅ [{i+1}/{len(df)}] {row['bar_time']} {row['mode']} drawn")

    # 輸出 HTML
    out_path = os.path.join(os.path.dirname(CSV_PATH), "fib_review.html")
    with open(out_path, "w") as f:
        f.write("<html><head><meta charset='utf-8'><title>Fib Review</title></head><body>")
        f.write("\n<hr>\n".join(all_html))
        f.write("</body></html>")

    print(f"\n✅ 輸出：{out_path}")
    print("用瀏覽器打開睇 interactive chart")

if __name__ == "__main__":
    main()
