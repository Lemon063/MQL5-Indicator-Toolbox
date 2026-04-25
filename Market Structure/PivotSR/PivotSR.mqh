//+------------------------------------------------------------------+
//|  PivotSR.mqh                                                     |
//|  MQL5 Indicator Toolbox                                          |
//|  Pivot V字算法 + S/R 密集區錨點選擇 + Fib-SR 評分系統            |
//|  取代 SwingHighLow.mqh v1.x                                      |
//|  v2.0：配對驗證架構，取代獨立揀 High/Low                          |
//|  #include <Toolbox/PivotSR.mqh>                                  |
//+------------------------------------------------------------------+
#ifndef __PIVOTSR_MQH__
#define __PIVOTSR_MQH__

#include <Toolbox/SupportResistance.mqh>
#include <Toolbox/FibTypes.mqh>

//--- 錨點模式
enum ENUM_ANCHOR_MODE
{
    ANCHOR_H1,   // H1：S/R 強度優先，方向+波段完整性驗證
    ANCHOR_M5    // M5：距離優先，8小時窗口，冇方向/波段限制
};

//--- Pivot 候選點
struct PivotPoint
{
    double price;
    int    bar;
    int    sr_count;
    double dist;
    bool   valid;
};

//--- 錨點結果
struct AnchorResult
{
    double high;
    double low;
    int    high_bar;
    int    low_bar;
    int    high_sr;
    int    low_sr;
    double score;
    double range_pips;
    int    span_bars;
    bool   range_ok;
    bool   valid;
};

//--- High/Low 配對
struct WavePair
{
    PivotPoint high;
    PivotPoint low;
    double     score;    // H1 = sr_count 總和，M5 = -(dist 總和)
    bool       range_ok; // range 係咪符合 MinRange
};

//+------------------------------------------------------------------+
//|  IsPivotHigh / IsPivotLow                                        |
//+------------------------------------------------------------------+
bool IsPivotHigh(string symbol, ENUM_TIMEFRAMES tf, int i, int n)
{
    double pivot_high = iHigh(symbol, tf, i);
    for(int j = 1; j <= n; j++)
    {
        if(iHigh(symbol, tf, i + j) >= pivot_high) return false;
        if(i - j < 0) return false;
        if(iHigh(symbol, tf, i - j) >= pivot_high) return false;
    }
    return true;
}

bool IsPivotLow(string symbol, ENUM_TIMEFRAMES tf, int i, int n)
{
    double pivot_low = iLow(symbol, tf, i);
    for(int j = 1; j <= n; j++)
    {
        if(iLow(symbol, tf, i + j) <= pivot_low) return false;
        if(i - j < 0) return false;
        if(iLow(symbol, tf, i - j) <= pivot_low) return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//|  FindPivotHighs / FindPivotLows                                  |
//+------------------------------------------------------------------+
int FindPivotHighs(string symbol, ENUM_TIMEFRAMES tf,
                   int pivot_n, int lookback, int shift,
                   PivotPoint &results[], double current_price)
{
    int count = 0;
    ArrayResize(results, MathMax(lookback, 1));
    int start = shift + pivot_n;
    int end   = shift + lookback;

    for(int i = start; i < end; i++)
    {
        if(IsPivotHigh(symbol, tf, i, pivot_n))
        {
            results[count].price    = iHigh(symbol, tf, i);
            results[count].bar      = i;
            results[count].sr_count = 0;
            results[count].dist     = MathAbs(current_price - iHigh(symbol, tf, i));
            results[count].valid    = true;
            count++;
        }
    }
    ArrayResize(results, count);
    return count;
}

int FindPivotLows(string symbol, ENUM_TIMEFRAMES tf,
                  int pivot_n, int lookback, int shift,
                  PivotPoint &results[], double current_price)
{
    int count = 0;
    ArrayResize(results, MathMax(lookback, 1));
    int start = shift + pivot_n;
    int end   = shift + lookback;

    for(int i = start; i < end; i++)
    {
        if(IsPivotLow(symbol, tf, i, pivot_n))
        {
            results[count].price    = iLow(symbol, tf, i);
            results[count].bar      = i;
            results[count].sr_count = 0;
            results[count].dist     = MathAbs(current_price - iLow(symbol, tf, i));
            results[count].valid    = true;
            count++;
        }
    }
    ArrayResize(results, count);
    return count;
}

//+------------------------------------------------------------------+
//|  IsWaveIntact                                                    |
//|  H1 only：驗證 High 到 Low 之間冇出現破壞波段嘅價格              |
//|  BUY：low_bar 到 high_bar 之間（中間 bars）冇更高嘅 High         |
//|  SELL：high_bar 到 low_bar 之間（中間 bars）冇更低嘅 Low         |
//|  注意：bar index 越大 = 越舊                                      |
//+------------------------------------------------------------------+
bool IsWaveIntact(string symbol, ENUM_TIMEFRAMES tf,
                  const PivotPoint &ph, const PivotPoint &pl,
                  bool is_buy)
{
    if(is_buy)
    {
        //--- BUY：ph 係較舊（大 bar index），pl 係較新（細 bar index）
        //    掃 ph.bar-1 到 pl.bar+1（中間 bars）
        for(int b = ph.bar - 1; b > pl.bar; b--)
            if(iHigh(symbol, tf, b) > ph.price)
                return false;
    }
    else
    {
        //--- SELL：pl 係較舊，ph 係較新
        for(int b = pl.bar - 1; b > ph.bar; b--)
            if(iLow(symbol, tf, b) < pl.price)
                return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//|  GetFibWeight                                                    |
//+------------------------------------------------------------------+
double GetFibWeight(int level_index)
{
    double weights[9] = {1.0, 2.0, 1.0, 3.0, 2.0, 1.0, 2.0, 1.0, 1.0};
    if(level_index < 0 || level_index > 8) return 0.0;
    return weights[level_index];
}

//+------------------------------------------------------------------+
//|  Clamp01                                                         |
//+------------------------------------------------------------------+
double Clamp01(double value)
{
    if(value < 0.0) return 0.0;
    if(value > 1.0) return 1.0;
    return value;
}

//+------------------------------------------------------------------+
//|  GetWindowExtremes                                               |
//+------------------------------------------------------------------+
void GetWindowExtremes(string symbol, ENUM_TIMEFRAMES tf,
                       int lookback, int shift,
                       double &window_high, double &window_low)
{
    window_high = -DBL_MAX;
    window_low  =  DBL_MAX;

    int start = MathMax(shift, 0);
    int end   = shift + lookback;

    for(int i = start; i < end; i++)
    {
        double h = iHigh(symbol, tf, i);
        double l = iLow(symbol, tf, i);

        if(h > window_high) window_high = h;
        if(l < window_low)  window_low  = l;
    }

    if(window_high == -DBL_MAX) window_high = 0.0;
    if(window_low  ==  DBL_MAX) window_low  = 0.0;
}

//+------------------------------------------------------------------+
//|  CalcH1PairScore                                                 |
//+------------------------------------------------------------------+
double CalcH1PairScore(const PivotPoint &high,
                       const PivotPoint &low,
                       int lookback,
                       double window_high,
                       double window_low,
                       bool range_ok)
{
    double window_range = MathMax(window_high - window_low, _Point);
    double wave_range   = high.price - low.price;
    double range_ratio  = Clamp01(wave_range / window_range);
    double span_ratio   = Clamp01((double)MathAbs(high.bar - low.bar) / MathMax(lookback, 1));

    double high_edge = Clamp01(1.0 - ((window_high - high.price) / window_range));
    double low_edge  = Clamp01(1.0 - ((low.price - window_low) / window_range));
    double edge_score = (high_edge + low_edge) * 0.5;

    int    recent_bar      = MathMin(high.bar, low.bar);
    double recency_ratio   = 1.0 - Clamp01((double)recent_bar / MathMax(lookback, 1));
    double sr_score        = (double)(high.sr_count + low.sr_count);
    double range_ok_bonus  = range_ok ? 0.0 : -20.0;

    return (sr_score   * 4.0) +
           (range_ratio * 8.0) +
           (span_ratio  * 5.0) +
           (edge_score  * 6.0) -
           (recency_ratio * 3.0) +
           range_ok_bonus;
}

//+------------------------------------------------------------------+
//|  CalcFibSRScore                                                  |
//+------------------------------------------------------------------+
double CalcFibSRScore(const FibLevels &f,
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
            score += GetFibWeight(i) + sr_bonus;
        }
    }

    if(!range_ok)
        score -= 3.0;

    return score;
}

//+------------------------------------------------------------------+
//|  BuildWavePairs                                                  |
//|  生成所有合格 (High, Low) 配對，按 mode 計分並排序               |
//|                                                                  |
//|  H1 mode：                                                       |
//|    ✓ 方向性驗證（BUY: low_bar < high_bar）                        |
//|    ✓ 波段完整性驗證（IsWaveIntact）                               |
//|    score = high.sr_count + low.sr_count                          |
//|                                                                  |
//|  M5 mode：                                                       |
//|    ✓ 8小時窗口：high_bar <= 96 AND low_bar <= 96                 |
//|    ✗ 冇方向性驗證                                                 |
//|    ✗ 冇波段完整性驗證                                             |
//|    score = -(high.dist + low.dist)                               |
//+------------------------------------------------------------------+
int BuildWavePairs(PivotPoint &highs[], int hcount,
                   PivotPoint &lows[],  int lcount,
                   string symbol, ENUM_TIMEFRAMES tf,
                   ENUM_ANCHOR_MODE mode, bool is_buy,
                   int lookback,
                   double min_range_pips,
                   double window_high,
                   double window_low,
                   WavePair &pairs[])
{
    int    pair_count = 0;
    double pip        = GetPipSize(symbol);
    double min_r      = min_range_pips * pip;
    int    max_pairs  = MathMax(hcount * lcount, 1);
    ArrayResize(pairs, max_pairs);

    for(int h = 0; h < hcount; h++)
    {
        if(!highs[h].valid) continue;

        for(int l = 0; l < lcount; l++)
        {
            if(!lows[l].valid) continue;
            if(pair_count >= max_pairs) break;

            //--- high > low 驗證（所有 mode）
            if(highs[h].price <= lows[l].price) continue;

            if(mode == ANCHOR_H1)
            {
                //--- 方向性驗證
                bool dir_ok = is_buy ? (lows[l].bar < highs[h].bar)
                                     : (highs[h].bar < lows[l].bar);
                if(!dir_ok) continue;

                //--- 波段完整性驗證
                if(!IsWaveIntact(symbol, tf, highs[h], lows[l], is_buy))
                    continue;
            }
            else // ANCHOR_M5
            {
                //--- 8小時窗口（96 bars × 5min = 8hr）
                if(highs[h].bar > 96 || lows[l].bar > 96) continue;
            }

            //--- MinRange 驗證
            double range    = highs[h].price - lows[l].price;
            bool   range_ok = (min_range_pips <= 0 || range >= min_r);

            //--- 排序分數
            double score;
            if(mode == ANCHOR_H1)
                score = CalcH1PairScore(
                    highs[h], lows[l], lookback,
                    window_high, window_low, range_ok);
            else
                score = -(highs[h].dist + lows[l].dist); // 負數令近嘅排前

            pairs[pair_count].high     = highs[h];
            pairs[pair_count].low      = lows[l];
            pairs[pair_count].score    = score;
            pairs[pair_count].range_ok = range_ok;
            pair_count++;
        }
    }

    ArrayResize(pairs, pair_count);

    //--- Bubble sort：score 高優先
    for(int i = 0; i < pair_count - 1; i++)
        for(int j = i + 1; j < pair_count; j++)
        {
            bool swap = false;

            if(pairs[j].score > pairs[i].score)
                swap = true;
            else if(MathAbs(pairs[j].score - pairs[i].score) <= 0.000001)
            {
                double range_j = pairs[j].high.price - pairs[j].low.price;
                double range_i = pairs[i].high.price - pairs[i].low.price;
                int    span_j  = MathAbs(pairs[j].high.bar - pairs[j].low.bar);
                int    span_i  = MathAbs(pairs[i].high.bar - pairs[i].low.bar);
                int    rec_j   = MathMin(pairs[j].high.bar, pairs[j].low.bar);
                int    rec_i   = MathMin(pairs[i].high.bar, pairs[i].low.bar);

                if(range_j > range_i + _Point)
                    swap = true;
                else if(MathAbs(range_j - range_i) <= _Point && span_j > span_i)
                    swap = true;
                else if(MathAbs(range_j - range_i) <= _Point &&
                        span_j == span_i &&
                        rec_j > rec_i)
                    swap = true;
            }

            if(swap)
            {
                WavePair tmp = pairs[i];
                pairs[i]     = pairs[j];
                pairs[j]     = tmp;
            }
        }

    return pair_count;
}

//+------------------------------------------------------------------+
//|  GetAnchorPoints                                                 |
//|  主函數：結合 Pivot + S/R + 配對驗證搵最佳 Fibonacci 錨點        |
//|  v2.0：配對架構取代 SelectBestAnchor                             |
//+------------------------------------------------------------------+
AnchorResult GetAnchorPoints(string symbol,
                             ENUM_TIMEFRAMES    tf,
                             ENUM_ANCHOR_MODE   mode,
                             bool   is_buy,
                             int    pivot_n        = 3,
                             int    pivot_look     = 50,
                             int    sr_lookback    = 100,
                             double sr_pips        = 10.0,
                             int    sr_min         = 4,
                             double sr_tol_pips    = 10.0,
                             double min_range_pips = 0.0,
                             int    shift          = 1,
                             bool   debug_log      = false)
{
    AnchorResult anchor;
    anchor.high      = 0;
    anchor.low       = 0;
    anchor.high_bar  = 0;
    anchor.low_bar   = 0;
    anchor.high_sr   = 0;
    anchor.low_sr    = 0;
    anchor.score     = 0;
    anchor.range_pips = 0;
    anchor.span_bars = 0;
    anchor.range_ok  = true;
    anchor.valid     = false;

    double pip           = GetPipSize(symbol);
    double current_price = iClose(symbol, tf, shift);
    double sr_tolerance  = sr_tol_pips * pip;
    double window_high   = 0.0;
    double window_low    = 0.0;

    GetWindowExtremes(symbol, tf, pivot_look, shift, window_high, window_low);

    //--- Step 1：計算 S/R 密集區
    SRResult sr = CalcSRZones(symbol, tf, sr_lookback, sr_pips, sr_min, shift);

    //--- Step 2：搵所有 Pivot 候選
    PivotPoint pivot_highs[];
    PivotPoint pivot_lows[];

    int high_count = FindPivotHighs(symbol, tf, pivot_n, pivot_look,
                                    shift, pivot_highs, current_price);
    int low_count  = FindPivotLows (symbol, tf, pivot_n, pivot_look,
                                    shift, pivot_lows,  current_price);

    //--- Step 3：Cross-reference Pivot 同 S/R
    for(int i = 0; i < high_count; i++)
    {
        SRZone zone;
        if(IsPriceNearSR(pivot_highs[i].price, sr, sr_tolerance, zone))
            pivot_highs[i].sr_count = zone.count;
    }
    for(int i = 0; i < low_count; i++)
    {
        SRZone zone;
        if(IsPriceNearSR(pivot_lows[i].price, sr, sr_tolerance, zone))
            pivot_lows[i].sr_count = zone.count;
    }

    //--- Step 4：生成配對 + 驗證 + 排序
    WavePair pairs[];
    int pair_count = BuildWavePairs(
        pivot_highs, high_count,
        pivot_lows,  low_count,
        symbol, tf, mode, is_buy,
        pivot_look,
        min_range_pips,
        window_high, window_low,
        pairs);

    if(pair_count == 0)
    {
        PrintFormat("⚠️ PivotSR：冇任何合格配對 | mode=%s is_buy=%s pivot_look=%d",
                    mode == ANCHOR_H1 ? "H1" : "M5",
                    is_buy ? "BUY" : "SELL",
                    pivot_look);
        return anchor;
    }

    //--- Step 5：揀 score 最高配對
    //    H1：S/R 強度最強嘅完整波段
    //    M5：距離最近嘅 8小時內配對
    WavePair best   = pairs[0];

    anchor.high     = best.high.price;
    anchor.low      = best.low.price;
    anchor.high_bar = best.high.bar;
    anchor.low_bar  = best.low.bar;
    anchor.high_sr  = best.high.sr_count;
    anchor.low_sr   = best.low.sr_count;
    anchor.score    = best.score;
    anchor.range_pips = (best.high.price - best.low.price) / pip;
    anchor.span_bars  = MathAbs(best.high.bar - best.low.bar);
    anchor.range_ok = best.range_ok;
    anchor.valid    = true;

    if(debug_log)
    {
        PrintFormat("PivotSR DBG | lookback=%d window_high=%.5f window_low=%.5f window_range=%.1f pips highs=%d lows=%d pairs=%d",
                    pivot_look,
                    window_high,
                    window_low,
                    (window_high - window_low) / pip,
                    high_count,
                    low_count,
                    pair_count);

        int top = MathMin(pair_count, 5);
        for(int i = 0; i < top; i++)
        {
            double pair_range_pips = (pairs[i].high.price - pairs[i].low.price) / pip;
            int    pair_span       = MathAbs(pairs[i].high.bar - pairs[i].low.bar);
            int    recent_bar      = MathMin(pairs[i].high.bar, pairs[i].low.bar);

            PrintFormat("PivotSR DBG | rank=%d score=%.2f range=%.1f pips span=%d recent=%d high=%.5f(bar %d sr=%d %s) low=%.5f(bar %d sr=%d %s)",
                        i + 1,
                        pairs[i].score,
                        pair_range_pips,
                        pair_span,
                        recent_bar,
                        pairs[i].high.price,
                        pairs[i].high.bar,
                        pairs[i].high.sr_count,
                        TimeToString(iTime(symbol, tf, pairs[i].high.bar), TIME_DATE|TIME_MINUTES),
                        pairs[i].low.price,
                        pairs[i].low.bar,
                        pairs[i].low.sr_count,
                        TimeToString(iTime(symbol, tf, pairs[i].low.bar), TIME_DATE|TIME_MINUTES));
        }

        PrintFormat("PivotSR DBG | chosen score=%.2f range=%.1f pips span=%d high_time=%s low_time=%s range_ok=%s",
                    anchor.score,
                    anchor.range_pips,
                    anchor.span_bars,
                    TimeToString(iTime(symbol, tf, anchor.high_bar), TIME_DATE|TIME_MINUTES),
                    TimeToString(iTime(symbol, tf, anchor.low_bar), TIME_DATE|TIME_MINUTES),
                    anchor.range_ok ? "true" : "false");
    }

    return anchor;
}

#endif // __PIVOTSR_MQH__
