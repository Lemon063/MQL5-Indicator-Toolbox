"""
fib_analysis.py
===============
FibComparison.mq5 CSV 數據分析腳本
比較 PIP 方法 vs 傳統 PivotSR 方法

用法：
    python fib_analysis.py --bar   path/to/CMP_bar.csv
    python fib_analysis.py --anchor path/to/CMP_anchor.csv
    python fib_analysis.py --bar   path/to/CMP_bar.csv --anchor path/to/CMP_anchor.csv

輸出：
    1. 統計摘要（console）
    2. 比較圖（PNG）
        - Fib level 時間序列對比
        - 差值分佈直方圖
        - 錨點穩定性比較
        - S/R 評分散點圖
"""

import argparse
import os
import sys

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from matplotlib.gridspec import GridSpec

# ── 顏色方案（對應 MT5 indicator）
COLOR_A = "#00FFFF"   # PIP — 青色
COLOR_B = "#FF8C00"   # PSR — 橙色
COLOR_DIFF = "#FF4444"

# ─────────────────────────────────────────────
#  讀取 CSV
# ─────────────────────────────────────────────

def load_bar_csv(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    df["datetime"] = pd.to_datetime(df["datetime"])
    df = df.sort_values("datetime").reset_index(drop=True)
    return df


def load_anchor_csv(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    df["datetime"] = pd.to_datetime(df["datetime"])
    df = df.sort_values("datetime").reset_index(drop=True)
    return df


# ─────────────────────────────────────────────
#  統計摘要
# ─────────────────────────────────────────────

def print_summary(df: pd.DataFrame, label: str = "Bar CSV"):
    print(f"\n{'='*60}")
    print(f"  {label}")
    print(f"  Rows: {len(df)}")
    if "datetime" in df.columns:
        print(f"  Period: {df['datetime'].min()} → {df['datetime'].max()}")
    print(f"{'='*60}")

    key_diffs = {
        "0.382": "diff_fib382_pips",
        "0.500": "diff_fib500_pips",
        "0.618": "diff_fib618_pips",
        "High":  "diff_high_pips",
        "Low":   "diff_low_pips",
    }

    print(f"\n{'Level':<8} {'Mean':>8} {'Std':>8} {'Min':>8} {'Max':>8} {'|diff|<5pip %':>14}")
    print("-" * 58)
    for name, col in key_diffs.items():
        if col not in df.columns:
            continue
        s = df[col].dropna()
        pct_agree = (s.abs() < 5.0).mean() * 100
        print(f"{name:<8} {s.mean():>+8.2f} {s.std():>8.2f} {s.min():>+8.2f} {s.max():>+8.2f} {pct_agree:>13.1f}%")

    # MAD（Mean Absolute Difference）
    diff_cols = [c for c in df.columns if c.startswith("diff_") and c.endswith("_pips")]
    if diff_cols:
        mad = df[diff_cols].abs().mean(axis=1).mean()
        print(f"\n  MAD（全部 level 平均絕對差）: {mad:.2f} pips")

    # S/R scores
    if "a_sr_score" in df.columns and "b_sr_score" in df.columns:
        print(f"\n  A(PIP) SR score 平均: {df['a_sr_score'].mean():.2f}  中位: {df['a_sr_score'].median():.2f}")
        print(f"  B(PSR) SR score 平均: {df['b_sr_score'].mean():.2f}  中位: {df['b_sr_score'].median():.2f}")


def print_anchor_summary(df: pd.DataFrame):
    print(f"\n{'='*60}")
    print(f"  Anchor Change Log Summary")
    print(f"  Total anchor changes: {len(df)}")
    if "changed_group" in df.columns:
        print(f"\n  Changes by group:")
        print(df["changed_group"].value_counts().to_string())
    if "a_range_pips" in df.columns:
        print(f"\n  A(PIP) range pips — mean: {df['a_range_pips'].mean():.1f}  std: {df['a_range_pips'].std():.1f}")
    if "b_range_pips" in df.columns:
        print(f"  B(PSR) range pips — mean: {df['b_range_pips'].mean():.1f}  std: {df['b_range_pips'].std():.1f}")
    print(f"{'='*60}")


# ─────────────────────────────────────────────
#  圖表：Bar CSV
# ─────────────────────────────────────────────

def plot_bar_analysis(df: pd.DataFrame, out_prefix: str = "fib_cmp"):

    df = df.copy()
    dt = df["datetime"]

    fig = plt.figure(figsize=(18, 14))
    fig.patch.set_facecolor("#111111")
    gs = GridSpec(3, 2, figure=fig, hspace=0.45, wspace=0.35)

    ax_618   = fig.add_subplot(gs[0, :])   # 0.618 時間序列（全寬）
    ax_382   = fig.add_subplot(gs[1, 0])   # 0.382 時間序列
    ax_high  = fig.add_subplot(gs[1, 1])   # High 錨點時間序列
    ax_hist  = fig.add_subplot(gs[2, 0])   # 差值直方圖
    ax_sr    = fig.add_subplot(gs[2, 1])   # S/R score 散點

    for ax in [ax_618, ax_382, ax_high, ax_hist, ax_sr]:
        ax.set_facecolor("#1a1a2e")
        ax.tick_params(colors="white")
        ax.xaxis.label.set_color("white")
        ax.yaxis.label.set_color("white")
        ax.title.set_color("white")
        for spine in ax.spines.values():
            spine.set_edgecolor("#444444")

    # ── 0.618 時間序列
    if "a_fib618" in df.columns and "b_fib618" in df.columns:
        ax_618.plot(dt, df["a_fib618"], color=COLOR_A, lw=1.2, label="A: PIP 0.618", alpha=0.9)
        ax_618.plot(dt, df["b_fib618"], color=COLOR_B, lw=1.2, label="B: PSR 0.618", alpha=0.9)
        if "current_price" in df.columns:
            ax_618.plot(dt, df["current_price"], color="#888888", lw=0.6, label="Price", alpha=0.5)
        ax_618.set_title("0.618 Fibonacci Level — PIP vs PSR (cyan) vs PSR (orange)", fontsize=12)
        ax_618.legend(fontsize=9, facecolor="#222222", labelcolor="white")
        ax_618.xaxis.set_major_formatter(mdates.DateFormatter("%m/%d %H:%M"))
        ax_618.xaxis.set_major_locator(mdates.AutoDateLocator())
        plt.setp(ax_618.xaxis.get_majorticklabels(), rotation=30, ha="right")

    # ── 0.382 時間序列
    if "a_fib382" in df.columns and "b_fib382" in df.columns:
        ax_382.plot(dt, df["a_fib382"], color=COLOR_A, lw=1.2, label="A: PIP 0.382")
        ax_382.plot(dt, df["b_fib382"], color=COLOR_B, lw=1.2, label="B: PSR 0.382")
        ax_382.set_title("0.382 Level", fontsize=11)
        ax_382.legend(fontsize=8, facecolor="#222222", labelcolor="white")
        ax_382.xaxis.set_major_formatter(mdates.DateFormatter("%m/%d"))
        plt.setp(ax_382.xaxis.get_majorticklabels(), rotation=30, ha="right")

    # ── High 錨點
    if "a_high" in df.columns and "b_high" in df.columns:
        ax_high.plot(dt, df["a_high"], color=COLOR_A, lw=1.2, label="A: PIP High")
        ax_high.plot(dt, df["b_high"], color=COLOR_B, lw=1.2, label="B: PSR High")
        ax_high.set_title("Anchor High — Stability Comparison", fontsize=11)
        ax_high.legend(fontsize=8, facecolor="#222222", labelcolor="white")
        ax_high.xaxis.set_major_formatter(mdates.DateFormatter("%m/%d"))
        plt.setp(ax_high.xaxis.get_majorticklabels(), rotation=30, ha="right")

    # ── 差值直方圖
    diff_data = {}
    for name, col in [("0.382", "diff_fib382_pips"),
                      ("0.500", "diff_fib500_pips"),
                      ("0.618", "diff_fib618_pips")]:
        if col in df.columns:
            diff_data[name] = df[col].dropna().values

    colors_hist = ["#FFFF00", "#00FF88", "#FF6666"]
    for i, (name, vals) in enumerate(diff_data.items()):
        ax_hist.hist(vals, bins=40, alpha=0.65,
                     color=colors_hist[i % len(colors_hist)],
                     label=f"diff {name}", edgecolor="none")
    ax_hist.axvline(0, color="white", lw=1, ls="--", alpha=0.5)
    ax_hist.axvline(5,  color="#FF4444", lw=0.8, ls=":", alpha=0.7)
    ax_hist.axvline(-5, color="#FF4444", lw=0.8, ls=":", alpha=0.7)
    ax_hist.set_title("Diff Distribution (PIP - PSR, pips)", fontsize=11)
    ax_hist.set_xlabel("Diff (pips)")
    ax_hist.legend(fontsize=8, facecolor="#222222", labelcolor="white")

    # ── S/R score 散點
    if "a_sr_score" in df.columns and "b_sr_score" in df.columns:
        a_sr = df["a_sr_score"].dropna()
        b_sr = df["b_sr_score"].dropna()
        min_len = min(len(a_sr), len(b_sr))
        ax_sr.scatter(a_sr.values[:min_len], b_sr.values[:min_len],
                      alpha=0.3, s=8, color="#AAAAFF")
        # 對角線（兩者相等）
        lo = min(a_sr.min(), b_sr.min())
        hi = max(a_sr.max(), b_sr.max())
        ax_sr.plot([lo, hi], [lo, hi], color="white", lw=0.8, ls="--", alpha=0.4)
        ax_sr.set_xlabel("A (PIP) SR Score")
        ax_sr.set_ylabel("B (PSR) SR Score")
        ax_sr.set_title("S/R Overlap Score Comparison", fontsize=11)
    else:
        ax_sr.text(0.5, 0.5, "S/R score N/A\n(InpUseSR=false?)",
                   ha="center", va="center", color="white", transform=ax_sr.transAxes)

    # 頁眉
    symbol = df["symbol"].iloc[0] if "symbol" in df.columns else "Unknown"
    tf     = df["timeframe"].iloc[0] if "timeframe" in df.columns else ""
    direction = df["direction"].iloc[0] if "direction" in df.columns else ""
    fig.suptitle(f"Fibonacci Comparison — {symbol} {tf} {direction}",
                 color="white", fontsize=14, y=0.98)

    out_path = out_prefix + "_bar_analysis.png"
    plt.savefig(out_path, dpi=150, bbox_inches="tight", facecolor="#111111")
    print(f"\n  ✅ 圖表已儲存：{out_path}")
    plt.close(fig)


# ─────────────────────────────────────────────
#  圖表：Anchor CSV
# ─────────────────────────────────────────────

def plot_anchor_analysis(df: pd.DataFrame, out_prefix: str = "fib_cmp"):

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.patch.set_facecolor("#111111")

    for ax in axes.flat:
        ax.set_facecolor("#1a1a2e")
        ax.tick_params(colors="white")
        ax.xaxis.label.set_color("white")
        ax.yaxis.label.set_color("white")
        ax.title.set_color("white")
        for spine in ax.spines.values():
            spine.set_edgecolor("#444444")

    ax_range, ax_freq, ax_sr618, ax_change = axes.flat

    # ── Range pips 比較
    if "a_range_pips" in df.columns and "b_range_pips" in df.columns:
        dt = df["datetime"]
        ax_range.plot(dt, df["a_range_pips"], color=COLOR_A, lw=1.2, label="A: PIP range")
        ax_range.plot(dt, df["b_range_pips"], color=COLOR_B, lw=1.2, label="B: PSR range")
        ax_range.set_title("Anchor Range (pips) — Per Update", fontsize=11)
        ax_range.legend(fontsize=8, facecolor="#222222", labelcolor="white")
        ax_range.xaxis.set_major_formatter(mdates.DateFormatter("%m/%d"))
        plt.setp(ax_range.xaxis.get_majorticklabels(), rotation=30, ha="right")

    # ── 更新頻率（changed_group pie / bar）
    if "changed_group" in df.columns:
        counts = df["changed_group"].value_counts()
        colors_pie = [COLOR_A, COLOR_B, "#AAAAAA", "#FF4444"]
        ax_freq.bar(counts.index, counts.values,
                    color=colors_pie[:len(counts)], edgecolor="none", alpha=0.8)
        ax_freq.set_title("Anchor Update Frequency", fontsize=11)
        ax_freq.set_ylabel("Count")
        for i, (label, val) in enumerate(counts.items()):
            ax_freq.text(i, val + 0.3, str(val), ha="center", color="white", fontsize=9)

    # ── 0.618 差值 at anchor change
    if "diff_fib618_pips" in df.columns:
        diff = df["diff_fib618_pips"].dropna()
        ax_sr618.hist(diff, bins=30, color="#FF6666", alpha=0.8, edgecolor="none")
        ax_sr618.axvline(0, color="white", lw=1, ls="--")
        ax_sr618.axvline(5,  color="#FFAA00", lw=0.8, ls=":")
        ax_sr618.axvline(-5, color="#FFAA00", lw=0.8, ls=":")
        pct = (diff.abs() < 5.0).mean() * 100
        ax_sr618.set_title(f"0.618 Diff at Anchor Change\nAgreement(<5pip): {pct:.1f}%", fontsize=10)
        ax_sr618.set_xlabel("Diff (pips)")

    # ── Geom score vs SR score（PIP 方法）
    if "a_geom_score" in df.columns and "a_sr_score" in df.columns:
        ax_change.scatter(df["a_geom_score"], df["a_sr_score"],
                          alpha=0.5, s=12, color=COLOR_A)
        ax_change.set_xlabel("A(PIP) Geom Score (range pips)")
        ax_change.set_ylabel("A(PIP) SR Score")
        ax_change.set_title("PIP: Geom Score vs SR Score", fontsize=11)
    else:
        ax_change.text(0.5, 0.5, "Insufficient data", ha="center", va="center",
                       color="white", transform=ax_change.transAxes)

    symbol = df["symbol"].iloc[0] if "symbol" in df.columns else "Unknown"
    fig.suptitle(f"Anchor Change Analysis — {symbol}", color="white", fontsize=13)

    out_path = out_prefix + "_anchor_analysis.png"
    plt.tight_layout()
    plt.savefig(out_path, dpi=150, bbox_inches="tight", facecolor="#111111")
    print(f"  ✅ 圖表已儲存：{out_path}")
    plt.close(fig)


# ─────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="FibComparison CSV 分析工具")
    parser.add_argument("--bar",    type=str, default=None, help="bar CSV 路徑")
    parser.add_argument("--anchor", type=str, default=None, help="anchor CSV 路徑")
    parser.add_argument("--out",    type=str, default="fib_cmp", help="輸出圖片前綴（default: fib_cmp）")
    args = parser.parse_args()

    if args.bar is None and args.anchor is None:
        # Demo mode：自動尋找 CSV
        print("未指定 CSV，自動搜索當前目錄...")
        for f in os.listdir("."):
            if f.endswith("_bar.csv") and "CMP" in f:
                args.bar = f
                print(f"  Found bar CSV: {f}")
            if f.endswith("_anchor.csv") and "CMP" in f:
                args.anchor = f
                print(f"  Found anchor CSV: {f}")

        if args.bar is None and args.anchor is None:
            print("  找唔到 CSV。請用 --bar 或 --anchor 指定路徑。")
            sys.exit(0)

    if args.bar:
        print(f"\n讀取 bar CSV: {args.bar}")
        df_bar = load_bar_csv(args.bar)
        print_summary(df_bar, label=os.path.basename(args.bar))
        plot_bar_analysis(df_bar, out_prefix=args.out)

    if args.anchor:
        print(f"\n讀取 anchor CSV: {args.anchor}")
        df_anc = load_anchor_csv(args.anchor)
        print_anchor_summary(df_anc)
        plot_anchor_analysis(df_anc, out_prefix=args.out)

    print("\n完成。")


if __name__ == "__main__":
    main()
