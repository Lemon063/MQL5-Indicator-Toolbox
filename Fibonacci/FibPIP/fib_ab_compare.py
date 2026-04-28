"""
fib_ab_compare.py
=================
真正 A/B 比較：
  A = Fibonacci_M5.mq5   (傳統 PivotSR 方法)   bar CSV + anchor CSV
  B = Fibonacci_PIP.mq5  (PIP 幾何距離方法)     bar CSV + anchor CSV

兩個 indicator 各自獨立跑，用 datetime 對齊後並排比較。

用法：
    # 最簡單：自動搵當前目錄所有 CSV
    python fib_ab_compare.py

    # 手動指定
    python fib_ab_compare.py \
        --m5_bar    FibM5_Logs/USDJPY_M5_BUY_N5_L96_PSR_bar.csv \
        --m5_anchor FibM5_Logs/USDJPY_M5_BUY_N5_L96_PSR_anchor.csv \
        --pip_bar   FibPIP_Logs/USDJPY_M5_BUY_O5_W96_VER_SR1_bar.csv \
        --pip_anchor FibPIP_Logs/USDJPY_M5_BUY_O5_W96_VER_SR1_anchor.csv \
        --out       usdjpy_ab

輸出：
    <out>_levels.png     — Fib level 時間序列（618, 382, High, Low）
    <out>_diff.png       — 差值分佈 + 穩定性
    <out>_anchor.png     — 錨點更新頻率 + range 比較
    <out>_summary.txt    — 文字統計摘要
"""

import argparse
import os
import sys
import glob

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from matplotlib.gridspec import GridSpec

# ── 顏色
CA = "#FF8C00"   # M5/PSR — 橙色（同 MT5 indicator 一致）
CB = "#00FFFF"   # PIP    — 青色
CG = "#888888"   # Price  — 灰色
CR = "#FF4444"   # 差值警告線


# ─────────────────────────────────────────────
#  讀取 + 對齊
# ─────────────────────────────────────────────

def load_csv(path):
    if not path or not os.path.exists(path):
        return None
    df = pd.read_csv(path)
    df["datetime"] = pd.to_datetime(df["datetime"])
    df = df.sort_values("datetime").reset_index(drop=True)
    return df


def align_bar(df_m5: pd.DataFrame, df_pip: pd.DataFrame) -> pd.DataFrame:
    """
    用 datetime 做 inner join，對齊兩組 bar data。
    保留兩組共有嘅時間點，加 _m5 / _pip 後綴。
    """
    m5  = df_m5.set_index("datetime")
    pip = df_pip.set_index("datetime")

    # 只保留需要嘅 columns
    keep = ["current_price",
            "anchor_high", "anchor_low", "anchor_high_bar", "anchor_low_bar",
            "range_pips", "sr_score", "sr_overlap",
            "fib_236", "fib_382", "fib_500", "fib_618", "fib_786",
            "fib_1000", "fib_1618", "fib_2618", "fib_3618",
            "atr"]

    m5_keep  = [c for c in keep if c in m5.columns]
    pip_keep = [c for c in keep if c in pip.columns]

    merged = m5[m5_keep].join(pip[pip_keep], how="inner",
                               lsuffix="_m5", rsuffix="_pip")
    merged = merged.reset_index()

    # 計差值（PIP − M5）
    for level in ["fib_236", "fib_382", "fib_500", "fib_618", "fib_786",
                  "fib_1000", "anchor_high", "anchor_low"]:
        ca = level + "_pip"
        cb = level + "_m5"
        if ca in merged.columns and cb in merged.columns:
            # 用 pip_size 估算（假設非 JPY，需要時手動改）
            pip_size = 0.01 if merged[ca].mean() > 50 else 0.0001
            merged["diff_" + level] = (merged[ca] - merged[cb]) / pip_size

    return merged


# ─────────────────────────────────────────────
#  統計摘要
# ─────────────────────────────────────────────

def print_and_save_summary(merged: pd.DataFrame,
                            df_m5_anc, df_pip_anc,
                            out_prefix: str):
    lines = []

    def p(s=""):
        print(s)
        lines.append(s)

    symbol    = merged.get("symbol_m5", merged.get("symbol", ["?"])).iloc[0] if "symbol_m5" in merged.columns else "?"
    direction = "BUY" if "BUY" in out_prefix.upper() else "?"
    p(f"{'='*65}")
    p(f"  Fibonacci A/B Comparison — {symbol}")
    p(f"  A: Fibonacci_M5 (PivotSR)    B: Fibonacci_PIP (PIP/VER)")
    p(f"  Period: {merged['datetime'].min()} → {merged['datetime'].max()}")
    p(f"  Aligned rows: {len(merged)}")
    p(f"{'='*65}")

    levels = [
        ("High anchor", "diff_anchor_high"),
        ("Low anchor",  "diff_anchor_low"),
        ("0.236",       "diff_fib_236"),
        ("0.382",       "diff_fib_382"),
        ("0.500",       "diff_fib_500"),
        ("0.618",       "diff_fib_618"),
        ("0.786",       "diff_fib_786"),
    ]

    p(f"\n  {'Level':<14} {'Mean':>8} {'Std':>8} {'Min':>8} {'Max':>8}  {'<5pip%':>7}")
    p(f"  {'-'*60}")
    for name, col in levels:
        if col not in merged.columns:
            continue
        s = merged[col].dropna()
        pct = (s.abs() < 5.0).mean() * 100
        p(f"  {name:<14} {s.mean():>+8.2f} {s.std():>8.2f} {s.min():>+8.2f} {s.max():>+8.2f}  {pct:>6.1f}%")

    # MAD
    diff_cols = [c for _, c in levels if c in merged.columns]
    if diff_cols:
        mad = merged[diff_cols].abs().mean(axis=1).mean()
        p(f"\n  MAD (mean absolute diff, all levels): {mad:.2f} pips")

    # Key level agreement
    key618 = merged["diff_fib_618"].abs() if "diff_fib_618" in merged.columns else pd.Series([])
    key382 = merged["diff_fib_382"].abs() if "diff_fib_382" in merged.columns else pd.Series([])
    if len(key618):
        p(f"\n  0.618 agreement (<5pip): {(key618 < 5).mean()*100:.1f}%  "
          f"median diff: {key618.median():.2f} pips")
    if len(key382):
        p(f"  0.382 agreement (<5pip): {(key382 < 5).mean()*100:.1f}%  "
          f"median diff: {key382.median():.2f} pips")

    # SR scores
    if "sr_score_m5" in merged.columns and "sr_score_pip" in merged.columns:
        p(f"\n  SR Score")
        p(f"    A (M5/PSR) mean: {merged['sr_score_m5'].mean():.2f}  "
          f"median: {merged['sr_score_m5'].median():.2f}")
        p(f"    B (PIP)    mean: {merged['sr_score_pip'].mean():.2f}  "
          f"median: {merged['sr_score_pip'].median():.2f}")

    # Anchor change frequency
    if df_m5_anc is not None and df_pip_anc is not None:
        p(f"\n  Anchor Change Frequency")
        p(f"    A (M5/PSR): {len(df_m5_anc)} changes")
        p(f"    B (PIP):    {len(df_pip_anc)} changes")
        if len(df_m5_anc) > 0 and len(df_pip_anc) > 0:
            ratio = len(df_pip_anc) / len(df_m5_anc)
            p(f"    PIP/PSR ratio: {ratio:.2f}x  "
              f"({'PIP 更穩定' if ratio < 1 else 'PSR 更穩定' if ratio > 1 else '一樣'})")

    p(f"\n{'='*65}")

    # 儲存 txt
    txt_path = out_prefix + "_summary.txt"
    with open(txt_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"\n  Summary saved: {txt_path}")

    return lines


# ─────────────────────────────────────────────
#  圖 1：Fib Level 時間序列
# ─────────────────────────────────────────────

def plot_levels(merged: pd.DataFrame, out_prefix: str):
    fig = plt.figure(figsize=(18, 12))
    fig.patch.set_facecolor("#0d0d1a")
    gs = GridSpec(2, 2, figure=fig, hspace=0.4, wspace=0.3)

    axes = [fig.add_subplot(gs[r, c]) for r in range(2) for c in range(2)]
    panels = [
        ("fib_618",    "0.618 Level"),
        ("fib_382",    "0.382 Level"),
        ("anchor_high","Anchor High (1.000)"),
        ("anchor_low", "Anchor Low (0.000)"),
    ]

    dt = merged["datetime"]
    price_col = "current_price_m5" if "current_price_m5" in merged.columns else None

    for ax, (col, title) in zip(axes, panels):
        ax.set_facecolor("#111122")
        ax.tick_params(colors="white", labelsize=8)
        for spine in ax.spines.values(): spine.set_edgecolor("#333355")
        ax.title.set_color("white")
        ax.set_title(title, fontsize=10)

        col_m5  = col + "_m5"
        col_pip = col + "_pip"

        if col_m5 in merged.columns:
            ax.plot(dt, merged[col_m5], color=CA, lw=1.3,
                    label="A: M5/PSR", alpha=0.9)
        if col_pip in merged.columns:
            ax.plot(dt, merged[col_pip], color=CB, lw=1.3,
                    label="B: PIP", alpha=0.9)
        if price_col and col in ("fib_618", "anchor_high"):
            ax.plot(dt, merged[price_col], color=CG, lw=0.5,
                    label="Price", alpha=0.4)

        ax.legend(fontsize=7, facecolor="#1a1a2e", labelcolor="white",
                  loc="best", framealpha=0.7)
        ax.xaxis.set_major_formatter(mdates.DateFormatter("%m/%d %H:%M"))
        ax.xaxis.set_major_locator(mdates.AutoDateLocator())
        plt.setp(ax.xaxis.get_majorticklabels(), rotation=30, ha="right",
                 fontsize=7)

    symbol = merged.columns  # just to get something
    fig.suptitle("Fib Levels — M5/PSR (orange) vs PIP (cyan)",
                 color="white", fontsize=13)

    path = out_prefix + "_levels.png"
    plt.savefig(path, dpi=150, bbox_inches="tight", facecolor="#0d0d1a")
    print(f"  Saved: {path}")
    plt.close(fig)


# ─────────────────────────────────────────────
#  圖 2：差值分佈 + 穩定性
# ─────────────────────────────────────────────

def plot_diff(merged: pd.DataFrame, out_prefix: str):
    fig, axes = plt.subplots(2, 2, figsize=(14, 9))
    fig.patch.set_facecolor("#0d0d1a")

    diff_pairs = [
        ("diff_fib_618", "0.618 Diff (pip)"),
        ("diff_fib_382", "0.382 Diff (pip)"),
        ("diff_anchor_high", "High Anchor Diff (pip)"),
        ("diff_anchor_low",  "Low Anchor Diff (pip)"),
    ]

    for ax, (col, title) in zip(axes.flat, diff_pairs):
        ax.set_facecolor("#111122")
        ax.tick_params(colors="white", labelsize=8)
        for spine in ax.spines.values(): spine.set_edgecolor("#333355")
        ax.title.set_color("white")
        ax.yaxis.label.set_color("white")
        ax.xaxis.label.set_color("white")

        if col not in merged.columns:
            ax.text(0.5, 0.5, "N/A", color="white", ha="center",
                    va="center", transform=ax.transAxes)
            ax.set_title(title, fontsize=10)
            continue

        data = merged[col].dropna()
        pct  = (data.abs() < 5.0).mean() * 100

        ax.hist(data, bins=40, color=CB, alpha=0.7, edgecolor="none")
        ax.axvline(0,  color="white",  lw=1,   ls="--", alpha=0.6)
        ax.axvline(5,  color=CR,       lw=0.8, ls=":",  alpha=0.7)
        ax.axvline(-5, color=CR,       lw=0.8, ls=":",  alpha=0.7)
        ax.set_title(f"{title}  |  <5pip: {pct:.1f}%", fontsize=9)
        ax.set_xlabel("PIP − PSR (pips)", fontsize=8)
        ax.set_ylabel("Count", fontsize=8)

    fig.suptitle("Diff Distribution: PIP minus PSR (pips)",
                 color="white", fontsize=12)
    plt.tight_layout(rect=[0, 0, 1, 0.95])

    path = out_prefix + "_diff.png"
    plt.savefig(path, dpi=150, bbox_inches="tight", facecolor="#0d0d1a")
    print(f"  Saved: {path}")
    plt.close(fig)


# ─────────────────────────────────────────────
#  圖 3：錨點穩定性
# ─────────────────────────────────────────────

def plot_anchor(df_m5_anc, df_pip_anc, out_prefix: str):
    fig, axes = plt.subplots(1, 3, figsize=(16, 5))
    fig.patch.set_facecolor("#0d0d1a")

    for ax in axes:
        ax.set_facecolor("#111122")
        ax.tick_params(colors="white", labelsize=8)
        for spine in ax.spines.values(): spine.set_edgecolor("#333355")
        ax.title.set_color("white")
        ax.xaxis.label.set_color("white")
        ax.yaxis.label.set_color("white")

    ax_freq, ax_range, ax_sr = axes

    # ── 更新頻率 bar chart
    labels = ["A: M5/PSR", "B: PIP"]
    counts = [
        len(df_m5_anc) if df_m5_anc is not None else 0,
        len(df_pip_anc) if df_pip_anc is not None else 0,
    ]
    colors = [CA, CB]
    bars = ax_freq.bar(labels, counts, color=colors, edgecolor="none", alpha=0.85)
    for bar, val in zip(bars, counts):
        ax_freq.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.3,
                     str(val), ha="center", color="white", fontsize=10)
    ax_freq.set_title("Anchor Change Count\n(fewer = more stable)", fontsize=10)
    ax_freq.set_ylabel("Count")

    # ── Range pips 分佈
    for df, color, label in [(df_m5_anc, CA, "A: M5/PSR"),
                              (df_pip_anc, CB, "B: PIP")]:
        if df is not None and "range_pips" in df.columns:
            ax_range.hist(df["range_pips"].dropna(), bins=20,
                         color=color, alpha=0.6, label=label, edgecolor="none")
    ax_range.set_title("Anchor Range (pips)", fontsize=10)
    ax_range.set_xlabel("Range (pips)")
    ax_range.legend(fontsize=8, facecolor="#222233", labelcolor="white")

    # ── SR score 比較
    for df, color, label in [(df_m5_anc, CA, "A: M5/PSR"),
                              (df_pip_anc, CB, "B: PIP")]:
        if df is not None and "sr_score" in df.columns:
            ax_sr.hist(df["sr_score"].dropna(), bins=20,
                      color=color, alpha=0.6, label=label, edgecolor="none")
    ax_sr.set_title("SR Score at Anchor Change", fontsize=10)
    ax_sr.set_xlabel("SR Score")
    ax_sr.legend(fontsize=8, facecolor="#222233", labelcolor="white")

    fig.suptitle("Anchor Stability Comparison", color="white", fontsize=12)
    plt.tight_layout(rect=[0, 0, 1, 0.93])

    path = out_prefix + "_anchor.png"
    plt.savefig(path, dpi=150, bbox_inches="tight", facecolor="#0d0d1a")
    print(f"  Saved: {path}")
    plt.close(fig)


# ─────────────────────────────────────────────
#  自動搵 CSV
# ─────────────────────────────────────────────

def auto_find(folder="."):
    """掃目錄搵四個 CSV，回傳 dict"""
    found = {"m5_bar": None, "m5_anchor": None,
             "pip_bar": None, "pip_anchor": None}

    for root, _, files in os.walk(folder):
        for f in files:
            if not f.endswith(".csv"): continue
            full = os.path.join(root, f)
            fu = f.upper()
            if "PSR" in fu and "_BAR" in fu and found["m5_bar"] is None:
                found["m5_bar"] = full
            elif "PSR" in fu and "_ANCHOR" in fu and found["m5_anchor"] is None:
                found["m5_anchor"] = full
            elif ("PIP" in fu or "VER" in fu or "EUC" in fu) and "_BAR" in fu \
                    and found["pip_bar"] is None:
                found["pip_bar"] = full
            elif ("PIP" in fu or "VER" in fu or "EUC" in fu) and "_ANCHOR" in fu \
                    and found["pip_anchor"] is None:
                found["pip_anchor"] = full

    return found


# ─────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Fibonacci A/B Compare: M5/PSR vs PIP")
    parser.add_argument("--m5_bar",     default=None)
    parser.add_argument("--m5_anchor",  default=None)
    parser.add_argument("--pip_bar",    default=None)
    parser.add_argument("--pip_anchor", default=None)
    parser.add_argument("--out",        default="fib_ab")
    parser.add_argument("--search_dir", default=".",
                        help="自動搜尋 CSV 嘅根目錄")
    args = parser.parse_args()

    # 自動搵
    if not any([args.m5_bar, args.m5_anchor, args.pip_bar, args.pip_anchor]):
        print(f"Auto-searching CSVs in: {args.search_dir}")
        found = auto_find(args.search_dir)
        args.m5_bar     = found["m5_bar"]
        args.m5_anchor  = found["m5_anchor"]
        args.pip_bar    = found["pip_bar"]
        args.pip_anchor = found["pip_anchor"]
        for k, v in found.items():
            print(f"  {k:<12}: {v or 'NOT FOUND'}")

    df_m5_bar  = load_csv(args.m5_bar)
    df_pip_bar = load_csv(args.pip_bar)
    df_m5_anc  = load_csv(args.m5_anchor)
    df_pip_anc = load_csv(args.pip_anchor)

    if df_m5_bar is None or df_pip_bar is None:
        print("\nERROR: 需要兩個 bar CSV 先可以做比較。")
        print("  M5 bar CSV:  ", args.m5_bar  or "NOT FOUND")
        print("  PIP bar CSV: ", args.pip_bar or "NOT FOUND")
        print("\n請確認兩個 indicator 都已 attach 到同一個 chart 並跑咗足夠時間。")
        sys.exit(1)

    print(f"\nM5  bar rows: {len(df_m5_bar)}")
    print(f"PIP bar rows: {len(df_pip_bar)}")

    merged = align_bar(df_m5_bar, df_pip_bar)
    print(f"Aligned rows: {len(merged)}")

    if len(merged) == 0:
        print("\nERROR: 對齊後冇共同時間點。")
        print("請確認兩個 indicator 係同一個 symbol + timeframe + 同一時段跑。")
        sys.exit(1)

    print(f"\nGenerating plots...")
    print_and_save_summary(merged, df_m5_anc, df_pip_anc, args.out)
    plot_levels(merged, args.out)
    plot_diff(merged, args.out)
    plot_anchor(df_m5_anc, df_pip_anc, args.out)

    print(f"\nDone. Output files: {args.out}_*.png / {args.out}_summary.txt")


if __name__ == "__main__":
    main()
