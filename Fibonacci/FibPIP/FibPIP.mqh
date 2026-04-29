//+------------------------------------------------------------------+
//|  FibPIP.mqh                                                      |
//|  MQL5 Indicator Toolbox                                          |
//|  純邏輯庫 — Perceptually Important Points (PIP) 算法             |
//|  v1.10：加入 S/R cross-reference + Fib-SR overlap score          |
//|          S/R 整合用獨立 bool 控制，唔影響純幾何模式               |
//|  #include <Toolbox/FibPIP.mqh>                                   |
//+------------------------------------------------------------------+
#ifndef __FIBPIP_MQH__
#define __FIBPIP_MQH__

#include <Toolbox/FibTypes.mqh>
#include <Toolbox/SupportResistance.mqh>   // CalcSRZones, IsPriceNearSR
// SupportResistance.mqh → ATR.mqh → GetPipSize() 已由此路徑提供
// 唔需要本地版本，避免同 ATR.mqh 重複定義

//--- 距離計算模式
enum ENUM_PIP_DIST
{
    PIP_EUC_DIS,   // 歐幾里得距離 Euclidean
    PIP_PER_DIS,   // 垂直距離 Perpendicular
    PIP_VER_DIS    // 縱向距離 Vertical（推薦）
};

//--- 單個 PIP 點
struct PIPPoint
{
    int    bar;
    double price;
    double distance;
};

//--- PIP 計算結果
struct PIPResult
{
    PIPPoint points[];
    int      count;
    bool     valid;
};

//--- PIP 錨點結果（含 S/R 評分）
struct PIPAnchorResult
{
    double high;
    double low;
    int    high_bar;
    int    low_bar;
    double range_pips;
    bool   range_ok;
    bool   valid;

    // PIP 專有
    int           pip_order;
    int           window_size;
    double        geom_score;    // 純幾何距離分：high.dist + low.dist（pips）
    ENUM_PIP_DIST dist_mode;

    // S/R 評分（僅當 use_sr=true 時有效）
    double fib_sr_score;     // Fib-SR overlap score（同 PivotSR 一致）
    int    sr_overlap_count; // 重疊 Fib level 數目
    bool   sr_used;          // 是否用咗 S/R 評分
};

//+------------------------------------------------------------------+
//|  CalcPIPDistance                                                 |
//+------------------------------------------------------------------+
double CalcPIPDistance(ENUM_PIP_DIST dist_mode,
                       int    i,       double price_i,
                       int    left_i,  double left_p,
                       int    right_i, double right_p)
{
    double time_diff = (double)(right_i - left_i);
    if(time_diff <= 0) return 0;

    double prz_diff  = right_p - left_p;
    double slope     = prz_diff / time_diff;
    double intercept = left_p - (double)left_i * slope;
    double ii        = (double)i;

    switch(dist_mode)
    {
        case PIP_EUC_DIS:
            return MathSqrt(MathPow((double)(left_i  - i), 2) + MathPow(left_p  - price_i, 2)) +
                   MathSqrt(MathPow((double)(right_i - i), 2) + MathPow(right_p - price_i, 2));
        case PIP_PER_DIS:
            return MathAbs((slope * ii + intercept) - price_i) / MathSqrt(slope * slope + 1.0);
        case PIP_VER_DIS:
        default:
            return MathAbs((slope * ii + intercept) - price_i);
    }
}

//+------------------------------------------------------------------+
//|  CalcPIPPoints                                                   |
//|  喺 close price 序列上搵 order 個 PIP 轉角點                     |
//|  prices[] — AsSeries=true（bar 0 = 最新）                        |
//|  start_bar — 窗口舊端（較大 bar index）                          |
//|  end_bar   — 窗口新端（較小 bar index，通常 = shift）            |
//+------------------------------------------------------------------+
bool CalcPIPPoints(const double &prices[],
                   int    start_bar,
                   int    end_bar,
                   int    order,
                   ENUM_PIP_DIST dist_mode,
                   PIPResult &result)
{
    result.count = 0;
    result.valid = false;

    int window_size = start_bar - end_bar + 1;
    if(window_size < order + 2) return false;

    // 本地 index 陣列（local 0 = start_bar = 舊端）
    int    idx_list[];
    double prz_list[];
    ArrayResize(idx_list, window_size);
    ArrayResize(prz_list, window_size);
    for(int k = 0; k < window_size; k++)
    {
        idx_list[k] = start_bar - k;
        prz_list[k] = prices[idx_list[k]];
    }

    // 初始錨點：首尾
    int    sel_idx[];
    double sel_prz[];
    int    sel_count = 2;
    ArrayResize(sel_idx, order + 2);
    ArrayResize(sel_prz, order + 2);
    sel_idx[0] = 0;
    sel_idx[1] = window_size - 1;
    sel_prz[0] = prz_list[0];
    sel_prz[1] = prz_list[window_size - 1];

    // 迭代搵最大距離點
    for(int iter = 0; iter < order; iter++)
    {
        double max_dis   = -1.0;
        int    max_local = -1;
        int    insert_at = -1;

        for(int seg = 0; seg < sel_count - 1; seg++)
        {
            int    l_local = sel_idx[seg];
            int    r_local = sel_idx[seg + 1];
            double l_prz   = sel_prz[seg];
            double r_prz   = sel_prz[seg + 1];
            if(r_local - l_local < 2) continue;

            for(int ii = l_local + 1; ii < r_local; ii++)
            {
                double dis = CalcPIPDistance(dist_mode,
                                             ii,       prz_list[ii],
                                             l_local,  l_prz,
                                             r_local,  r_prz);
                if(dis > max_dis)
                {
                    max_dis   = dis;
                    max_local = ii;
                    insert_at = seg + 1;
                }
            }
        }

        if(max_local < 0) break;

        // 插入新點
        sel_count++;
        ArrayResize(sel_idx, sel_count);
        ArrayResize(sel_prz, sel_count);
        for(int mv = sel_count - 1; mv > insert_at; mv--)
        {
            sel_idx[mv] = sel_idx[mv - 1];
            sel_prz[mv] = sel_prz[mv - 1];
        }
        sel_idx[insert_at] = max_local;
        sel_prz[insert_at] = prz_list[max_local];
    }

    // 輸出（去除首尾端點）
    int out_count = sel_count - 2;
    if(out_count <= 0) return false;

    ArrayResize(result.points, out_count);
    result.count = 0;
    for(int i = 1; i < sel_count - 1; i++)
    {
        int local_i = sel_idx[i];
        result.points[result.count].bar      = idx_list[local_i];
        result.points[result.count].price    = sel_prz[i];
        result.points[result.count].distance = 0;
        result.count++;
    }

    result.valid = (result.count > 0);
    return result.valid;
}

//+------------------------------------------------------------------+
//|  FindPIPAnchors                                                  |
//|  喺 PIP 結果中搵 High/Low 錨點，加方向性驗證                     |
//+------------------------------------------------------------------+
bool FindPIPAnchors(const PIPResult &pip,
                    bool   is_buy,
                    double min_range_pips,
                    double pip_size,
                    int   &out_high_bar,
                    double &out_high,
                    int   &out_low_bar,
                    double &out_low,
                    bool  &out_range_ok,
                    double &out_geom_score)
{
    if(!pip.valid || pip.count < 2) return false;

    int    best_high_bar = -1, best_low_bar = -1;
    double best_high = -DBL_MAX, best_low = DBL_MAX;

    for(int i = 0; i < pip.count; i++)
    {
        if(pip.points[i].price > best_high)
        {
            best_high     = pip.points[i].price;
            best_high_bar = pip.points[i].bar;
        }
        if(pip.points[i].price < best_low)
        {
            best_low     = pip.points[i].price;
            best_low_bar = pip.points[i].bar;
        }
    }

    if(best_high_bar < 0 || best_low_bar < 0) return false;
    if(best_high <= best_low) return false;

    // 方向性驗證（AsSeries：bar index 細 = 新，bar index 大 = 舊）
    // BUY：price 由低升高 → low 係舊端（low_bar > high_bar）
    // SELL：price 由高跌低 → high 係舊端（high_bar > low_bar）
    if(is_buy)
    {
        if(best_low_bar <= best_high_bar) return false;  // low 必須比 high 更舊
    }
    else
    {
        if(best_high_bar <= best_low_bar) return false;  // high 必須比 low 更舊
    }

    double range  = best_high - best_low;
    out_range_ok  = (min_range_pips <= 0 || range >= min_range_pips * pip_size);
    out_high_bar  = best_high_bar;
    out_high      = best_high;
    out_low_bar   = best_low_bar;
    out_low       = best_low;
    out_geom_score = range / pip_size;  // range pips 做幾何分

    return true;
}

//+------------------------------------------------------------------+
//|  GetFibWeightPIP                                                 |
//|  Fib level 權重（同 PivotSR 一致）                               |
//+------------------------------------------------------------------+
double GetFibWeightPIP(int level_index)
{
    // 0=236 1=382 2=500 3=618 4=786 5=1000 6=1618 7=2618 8=3618
    double weights[9] = {1.0, 2.0, 1.0, 3.0, 2.0, 1.0, 2.0, 1.0, 1.0};
    if(level_index < 0 || level_index > 8) return 0.0;
    return weights[level_index];
}

//+------------------------------------------------------------------+
//|  CalcFibSRScore_PIP                                              |
//|  計算 Fib level 同 S/R 密集區嘅重疊分數                          |
//|  邏輯同 PivotSR.mqh CalcFibSRScore 完全一致                      |
//+------------------------------------------------------------------+
double CalcFibSRScore_PIP(const FibLevels &f,
                           const SRResult  &sr,
                           double           tolerance,
                           int             &overlap_count,
                           bool             range_ok = true)
{
    double levels[9];
    levels[0] = f.fib_236;  levels[1] = f.fib_382;
    levels[2] = f.fib_500;  levels[3] = f.fib_618;
    levels[4] = f.fib_786;  levels[5] = f.fib_1000;
    levels[6] = f.fib_1618; levels[7] = f.fib_2618;
    levels[8] = f.fib_3618;

    double score  = 0;
    overlap_count = 0;

    for(int i = 0; i < 9; i++)
    {
        SRZone zone;
        if(IsPriceNearSR(levels[i], sr, tolerance, zone))
        {
            overlap_count++;
            double sr_bonus = (zone.count >= 10) ? 1.0 : 0.0;
            score += GetFibWeightPIP(i) + sr_bonus;
        }
    }

    if(!range_ok) score -= 3.0;
    return score;
}

//+------------------------------------------------------------------+
//|  GetAnchorPoints_PIP                                             |
//|  主函數：用 PIP 算法搵最佳 Fibonacci 錨點                         |
//|                                                                  |
//|  use_sr = false → 純幾何模式，唔做 S/R 評分                      |
//|  use_sr = true  → 加 Fib-SR overlap score（同傳統版本相同邏輯）  |
//+------------------------------------------------------------------+
PIPAnchorResult GetAnchorPoints_PIP(string         symbol,
                                    ENUM_TIMEFRAMES tf,
                                    bool            is_buy,
                                    int             pip_order      = 5,
                                    int             window_size    = 50,
                                    ENUM_PIP_DIST   dist_mode      = PIP_VER_DIS,
                                    double          min_range_pips = 10.0,
                                    int             shift          = 1,
                                    bool            use_sr         = false,
                                    int             sr_lookback    = 100,
                                    double          sr_zone_pips   = 10.0,
                                    int             sr_min_count   = 4,
                                    double          sr_tol_pips    = 10.0)
{
    PIPAnchorResult anchor;
    anchor.high            = 0;
    anchor.low             = 0;
    anchor.high_bar        = 0;
    anchor.low_bar         = 0;
    anchor.range_pips      = 0;
    anchor.range_ok        = false;
    anchor.valid           = false;
    anchor.pip_order       = pip_order;
    anchor.window_size     = window_size;
    anchor.geom_score      = 0;
    anchor.dist_mode       = dist_mode;
    anchor.fib_sr_score    = 0;
    anchor.sr_overlap_count = 0;
    anchor.sr_used         = use_sr;

    double pip_size = GetPipSize(symbol);

    // 取 close price
    double prices[];
    ArraySetAsSeries(prices, true);
    int copied = CopyClose(symbol, tf, 0, shift + window_size + 1, prices);
    if(copied < shift + window_size) return anchor;

    int start_bar = shift + window_size - 1;
    int end_bar   = shift;

    // 計算 PIP 點
    PIPResult pip;
    if(!CalcPIPPoints(prices, start_bar, end_bar, pip_order, dist_mode, pip))
    {
        PrintFormat("[PIP DBG] CalcPIPPoints 失敗 | start=%d end=%d order=%d",
                    start_bar, end_bar, pip_order);
        return anchor;
    }

    // Debug：印出所有 PIP 點
    PrintFormat("[PIP DBG] 搵到 %d 個 PIP 點 | is_buy=%s min_range=%.1f pips",
                pip.count, is_buy ? "true" : "false", min_range_pips);
    double best_h = -DBL_MAX, best_l = DBL_MAX;
    int    best_h_bar = -1,   best_l_bar = -1;
    for(int _i = 0; _i < pip.count; _i++)
    {
        PrintFormat("[PIP DBG]   point[%d] bar=%d price=%.5f",
                    _i, pip.points[_i].bar, pip.points[_i].price);
        if(pip.points[_i].price > best_h) { best_h = pip.points[_i].price; best_h_bar = pip.points[_i].bar; }
        if(pip.points[_i].price < best_l) { best_l = pip.points[_i].price; best_l_bar = pip.points[_i].bar; }
    }
    PrintFormat("[PIP DBG] Best High=%.5f(bar %d)  Best Low=%.5f(bar %d) | BUY需要 low_bar(%d) > high_bar(%d): %s",
                best_h, best_h_bar, best_l, best_l_bar,
                best_l_bar, best_h_bar,
                (best_l_bar > best_h_bar) ? "✅ PASS" : "❌ FAIL 方向錯");

    // 搵錨點
    int    h_bar; double h_prz;
    int    l_bar; double l_prz;
    bool   r_ok;  double geom_score;

    if(!FindPIPAnchors(pip, is_buy, min_range_pips, pip_size,
                       h_bar, h_prz, l_bar, l_prz, r_ok, geom_score))
    {
        PrintFormat("[PIP DBG] FindPIPAnchors 失敗 | range=%.1f pips  range_ok=%s",
                    (best_h - best_l) / pip_size,
                    ((best_h - best_l) >= min_range_pips * pip_size) ? "true" : "false — range 太細");
        return anchor;
    }

    anchor.high        = h_prz;
    anchor.low         = l_prz;
    anchor.high_bar    = h_bar;
    anchor.low_bar     = l_bar;
    anchor.range_pips  = (h_prz - l_prz) / pip_size;
    anchor.range_ok    = r_ok;
    anchor.geom_score  = geom_score;
    anchor.valid       = true;

    // S/R 評分（獨立開關）
    if(use_sr)
    {
        SRResult sr = CalcSRZones(symbol, tf, sr_lookback, sr_zone_pips, sr_min_count, shift);
        double   tol = sr_tol_pips * pip_size;

        // 用搵到嘅錨點算 FibLevels
        FibLevels f;
        f.swing_high = h_prz;
        f.swing_low  = l_prz;
        f.range      = h_prz - l_prz;
        f.is_buy     = is_buy;
        if(is_buy)
        {
            f.fib_236  = l_prz + 0.236 * f.range;
            f.fib_382  = l_prz + 0.382 * f.range;
            f.fib_500  = l_prz + 0.500 * f.range;
            f.fib_618  = l_prz + 0.618 * f.range;
            f.fib_786  = l_prz + 0.786 * f.range;
            f.fib_1000 = h_prz;
            f.fib_1618 = h_prz + 0.618 * f.range;
            f.fib_2618 = h_prz + 1.618 * f.range;
            f.fib_3618 = h_prz + 2.618 * f.range;
        }
        else
        {
            f.fib_236  = h_prz - 0.236 * f.range;
            f.fib_382  = h_prz - 0.382 * f.range;
            f.fib_500  = h_prz - 0.500 * f.range;
            f.fib_618  = h_prz - 0.618 * f.range;
            f.fib_786  = h_prz - 0.786 * f.range;
            f.fib_1000 = l_prz;
            f.fib_1618 = l_prz - 0.618 * f.range;
            f.fib_2618 = l_prz - 1.618 * f.range;
            f.fib_3618 = l_prz - 2.618 * f.range;
        }

        int    ol_count = 0;
        double sr_score = CalcFibSRScore_PIP(f, sr, tol, ol_count, r_ok);
        anchor.fib_sr_score    = sr_score;
        anchor.sr_overlap_count = ol_count;
    }

    return anchor;
}

#endif // __FIBPIP_MQH__
