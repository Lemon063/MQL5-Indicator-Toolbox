//+------------------------------------------------------------------+
//|  PivotSR.mqh                                                     |
//|  MQL5 Indicator Toolbox                                          |
//|  Pivot V字算法 + S/R 密集區錨點選擇 + Fib-SR 評分系統            |
//|  取代 SwingHighLow.mqh v1.x                                      |
//|  #include <Toolbox/PivotSR.mqh>                                  |
//+------------------------------------------------------------------+
#ifndef __PIVOTSR_MQH__
#define __PIVOTSR_MQH__

#include <Toolbox/SupportResistance.mqh>
#include <Toolbox/FibTypes.mqh>

//--- 錨點模式
enum ENUM_ANCHOR_MODE
{
    ANCHOR_H1,   // H1：S/R 強度優先（市場結構錨點）
    ANCHOR_M5    // M5：距離優先 + MinRange 扣分（入場參考錨點）
};

//--- Pivot 候選點
struct PivotPoint
{
    double price;    // Pivot 價格
    int    bar;      // Bar index（shift）
    int    sr_count; // 對應 S/R 密集區強度（0 = 冇對應）
    double dist;     // 距離現價嘅距離（price units）
    bool   valid;    // 係咪符合所有條件
};

//--- 錨點結果
struct AnchorResult
{
    double high;        // 選定嘅 Pivot High 錨點價格
    double low;         // 選定嘅 Pivot Low 錨點價格
    int    high_bar;    // Pivot High 發生嘅 bar index
    int    low_bar;     // Pivot Low 發生嘅 bar index
    int    high_sr;     // Pivot High 對應 S/R 強度
    int    low_sr;      // Pivot Low 對應 S/R 強度
    bool   range_ok;    // range 係咪符合 MinRange（M5 用）
    bool   valid;
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
    ArrayResize(results, 50);
    int start = shift + pivot_n;
    int end   = shift + lookback;

    for(int i = start; i < end && count < 50; i++)
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
    ArrayResize(results, 50);
    int start = shift + pivot_n;
    int end   = shift + lookback;

    for(int i = start; i < end && count < 50; i++)
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
//|  SelectBestAnchor                                                |
//|  H1 mode：S/R 強度優先，強度相同先比距離                          |
//|  M5 mode：距離優先（MinRange 扣分喺 CalcFibSRScore 處理）         |
//+------------------------------------------------------------------+
PivotPoint SelectBestAnchor(PivotPoint &candidates[], int count,
                             string symbol, ENUM_ANCHOR_MODE mode)
{
    PivotPoint best;
    best.price    = 0;
    best.bar      = 0;
    best.sr_count = 0;
    best.dist     = DBL_MAX;
    best.valid    = false;

    if(count == 0) return best;

    double pip_tol = GetPipSize(symbol) * 5.0;

    for(int i = 0; i < count; i++)
    {
        if(!candidates[i].valid) continue;

        if(mode == ANCHOR_H1)
        {
            //--- H1：強度優先，強度相同先比距離
            bool stronger = candidates[i].sr_count > best.sr_count;
            bool same_str = candidates[i].sr_count == best.sr_count;
            bool closer   = candidates[i].dist < best.dist;

            if(!best.valid || stronger || (same_str && closer))
                best = candidates[i];
        }
        else // ANCHOR_M5
        {
            //--- M5：距離優先，5 pips 容忍範圍內用 S/R 強度做 tiebreaker
            bool closer    = candidates[i].dist < best.dist - pip_tol;
            bool same_dist = MathAbs(candidates[i].dist - best.dist) <= pip_tol;
            bool stronger  = candidates[i].sr_count > best.sr_count;

            if(!best.valid || (closer && !same_dist) || (same_dist && stronger))
                best = candidates[i];
        }
    }

    return best;
}

//+------------------------------------------------------------------+
//|  GetFibWeight                                                    |
//|  返回各 Fib level 嘅評分權重                                      |
//|  index: 0=236, 1=382, 2=500, 3=618, 4=786                       |
//|          5=1000, 6=1618, 7=2618, 8=3618                          |
//+------------------------------------------------------------------+
double GetFibWeight(int level_index)
{
    double weights[9] = {1.0, 2.0, 1.0, 3.0, 2.0, 1.0, 2.0, 1.0, 1.0};
    if(level_index < 0 || level_index > 8) return 0.0;
    return weights[level_index];
}

//+------------------------------------------------------------------+
//|  CalcFibSRScore                                                  |
//|  計算 Fib levels 同 S/R 密集區嘅重疊分數                          |
//|  tolerance    : 接近閾值（price units）                           |
//|  overlap_count: 輸出參數，重疊數量                                 |
//|  min_range_ok : 如果 range 太細，扣 3 分                          |
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

    //--- range 太細扣 3 分（令分數唔夠 InpMinScore）
    if(!range_ok)
        score -= 3.0;

    return score;
}

//+------------------------------------------------------------------+
//|  GetAnchorPoints                                                 |
//|  主函數：結合 Pivot + S/R 搵最佳 Fibonacci 錨點                  |
//+------------------------------------------------------------------+
AnchorResult GetAnchorPoints(string symbol,
                             ENUM_TIMEFRAMES    tf,
                             ENUM_ANCHOR_MODE   mode,
                             int    pivot_n        = 3,
                             int    pivot_look     = 50,
                             int    sr_lookback    = 100,
                             double sr_pips        = 10.0,
                             int    sr_min         = 4,
                             double sr_tol_pips    = 10.0,
                             double min_range_pips = 0.0,
                             int    shift          = 1)
{
    AnchorResult anchor;
    anchor.high      = 0;
    anchor.low       = 0;
    anchor.high_bar  = 0;
    anchor.low_bar   = 0;
    anchor.high_sr   = 0;
    anchor.low_sr    = 0;
    anchor.range_ok  = true;
    anchor.valid     = false;

    double pip           = GetPipSize(symbol);
    double current_price = iClose(symbol, tf, shift);
    double sr_tolerance  = sr_tol_pips * pip;

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

    //--- Step 4：揀最佳錨點
    PivotPoint best_high = SelectBestAnchor(pivot_highs, high_count, symbol, mode);
    PivotPoint best_low  = SelectBestAnchor(pivot_lows,  low_count,  symbol, mode);

    if(!best_high.valid || !best_low.valid)
        return anchor;

    //--- Step 5：high > low 驗證
    if(best_high.price <= best_low.price)
    {
        PrintFormat("⚠️ PivotSR：Pivot High (%.5f) <= Pivot Low (%.5f)，錨點無效",
                    best_high.price, best_low.price);
        return anchor;
    }

    //--- Step 6：M5 MinRange check（記錄係咪 range_ok，扣分由 CalcFibSRScore 處理）
    if(mode == ANCHOR_M5 && min_range_pips > 0)
    {
        double min_range = min_range_pips * pip;
        anchor.range_ok  = (best_high.price - best_low.price >= min_range);
    }

    anchor.high     = best_high.price;
    anchor.low      = best_low.price;
    anchor.high_bar = best_high.bar;
    anchor.low_bar  = best_low.bar;
    anchor.high_sr  = best_high.sr_count;
    anchor.low_sr   = best_low.sr_count;
    anchor.valid    = true;

    return anchor;
}

#endif // __PIVOTSR_MQH__
