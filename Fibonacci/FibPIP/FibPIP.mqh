//+------------------------------------------------------------------+
//|  FibPIP.mqh                                                      |
//|  MQL5 Indicator Toolbox                                          |
//|  純邏輯庫 — Perceptually Important Points (PIP) 算法             |
//|  v1.20：移除 FindPIPAnchors() 同方向性驗證，移除 debug log        |
//|          GetAnchorPoints_PIP() 直接取最高/最低 PIP 點做錨點      |
//|          忠實於原版 pip_algo_us.py — 冇方向限制                   |
//|  #include <Toolbox/FibPIP.mqh>                                   |
//+------------------------------------------------------------------+
#ifndef __FIBPIP_MQH__
#define __FIBPIP_MQH__

#include <Toolbox/FibTypes.mqh>
#include <Toolbox/SupportResistance.mqh>
// SupportResistance.mqh → ATR.mqh → GetPipSize() 已由此路徑提供

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

    int           pip_order;
    int           window_size;
    double        geom_score;
    ENUM_PIP_DIST dist_mode;

    double fib_sr_score;
    int    sr_overlap_count;
    bool   sr_used;
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
//|  喺 close price 序列上搵 order 個幾何距離最大嘅轉角點             |
//|  忠實於原版 pip_algo_us.py 嘅核心算法                            |
//|  prices[] — AsSeries=true（bar 0 = 最新）                        |
//|  start_bar — 窗口舊端（較大 bar index）                          |
//|  end_bar   — 窗口新端（較小 bar index）                          |
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

    int    idx_list[];
    double prz_list[];
    ArrayResize(idx_list, window_size);
    ArrayResize(prz_list, window_size);
    for(int k = 0; k < window_size; k++)
    {
        idx_list[k] = start_bar - k;
        prz_list[k] = prices[idx_list[k]];
    }

    int    sel_idx[];
    double sel_prz[];
    int    sel_count = 2;
    ArrayResize(sel_idx, order + 2);
    ArrayResize(sel_prz, order + 2);
    sel_idx[0] = 0;
    sel_idx[1] = window_size - 1;
    sel_prz[0] = prz_list[0];
    sel_prz[1] = prz_list[window_size - 1];

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
//|  GetFibWeightPIP                                                 |
//+------------------------------------------------------------------+
double GetFibWeightPIP(int level_index)
{
    double weights[9] = {1.0, 2.0, 1.0, 3.0, 2.0, 1.0, 2.0, 1.0, 1.0};
    if(level_index < 0 || level_index > 8) return 0.0;
    return weights[level_index];
}

//+------------------------------------------------------------------+
//|  CalcFibSRScore_PIP                                              |
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
//|  主函數：用 PIP 算法搵 Fibonacci 錨點                             |
//|  忠實於原版 pip_algo_us.py：                                      |
//|    搵幾何距離最大嘅轉角點，取最高同最低做錨點，冇方向性驗證        |
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
    anchor.high             = 0;
    anchor.low              = 0;
    anchor.high_bar         = 0;
    anchor.low_bar          = 0;
    anchor.range_pips       = 0;
    anchor.range_ok         = false;
    anchor.valid            = false;
    anchor.pip_order        = pip_order;
    anchor.window_size      = window_size;
    anchor.geom_score       = 0;
    anchor.dist_mode        = dist_mode;
    anchor.fib_sr_score     = 0;
    anchor.sr_overlap_count = 0;
    anchor.sr_used          = use_sr;

    double pip_size = GetPipSize(symbol);

    // 取 close price
    double prices[];
    ArraySetAsSeries(prices, true);
    int copied = CopyClose(symbol, tf, 0, shift + window_size + 1, prices);
    if(copied < shift + window_size) return anchor;

    int start_bar = shift + window_size - 1;
    int end_bar   = shift;

    // 計算 PIP 轉角點
    PIPResult pip;
    if(!CalcPIPPoints(prices, start_bar, end_bar, pip_order, dist_mode, pip))
        return anchor;

    // 直接取最高同最低 PIP 點做錨點（冇方向性驗證）
    double best_high = -DBL_MAX, best_low = DBL_MAX;
    int    best_high_bar = -1,   best_low_bar = -1;

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

    if(best_high_bar < 0 || best_low_bar < 0 || best_high <= best_low)
        return anchor;

    double range    = best_high - best_low;
    bool   range_ok = (min_range_pips <= 0 || range >= min_range_pips * pip_size);

    anchor.high        = best_high;
    anchor.low         = best_low;
    anchor.high_bar    = best_high_bar;
    anchor.low_bar     = best_low_bar;
    anchor.range_pips  = range / pip_size;
    anchor.range_ok    = range_ok;
    anchor.geom_score  = range / pip_size;
    anchor.valid       = true;

    // S/R 評分（獨立開關）
    if(use_sr)
    {
        SRResult sr  = CalcSRZones(symbol, tf, sr_lookback, sr_zone_pips, sr_min_count, shift);
        double   tol = sr_tol_pips * pip_size;

        FibLevels f;
        f.swing_high = best_high;
        f.swing_low  = best_low;
        f.range      = range;
        f.is_buy     = is_buy;
        if(is_buy)
        {
            f.fib_236  = best_low + 0.236 * range;
            f.fib_382  = best_low + 0.382 * range;
            f.fib_500  = best_low + 0.500 * range;
            f.fib_618  = best_low + 0.618 * range;
            f.fib_786  = best_low + 0.786 * range;
            f.fib_1000 = best_high;
            f.fib_1618 = best_high + 0.618 * range;
            f.fib_2618 = best_high + 1.618 * range;
            f.fib_3618 = best_high + 2.618 * range;
        }
        else
        {
            f.fib_236  = best_high - 0.236 * range;
            f.fib_382  = best_high - 0.382 * range;
            f.fib_500  = best_high - 0.500 * range;
            f.fib_618  = best_high - 0.618 * range;
            f.fib_786  = best_high - 0.786 * range;
            f.fib_1000 = best_low;
            f.fib_1618 = best_low  - 0.618 * range;
            f.fib_2618 = best_low  - 1.618 * range;
            f.fib_3618 = best_low  - 2.618 * range;
        }

        int    ol_count = 0;
        double sr_score = CalcFibSRScore_PIP(f, sr, tol, ol_count, range_ok);
        anchor.fib_sr_score     = sr_score;
        anchor.sr_overlap_count = ol_count;
    }

    return anchor;
}

#endif // __FIBPIP_MQH__
