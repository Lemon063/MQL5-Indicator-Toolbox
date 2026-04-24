//+------------------------------------------------------------------+
//|  PivotSR.mqh                                                     |
//|  MQL5 Indicator Toolbox                                          |
//|  純邏輯庫 Pure logic library                                      |
//|  Pivot V字算法 + S/R 密集區錨點選擇                               |
//|  取代 SwingHighLow.mqh（v1.x N-bar 最高/最低算法）                |
//|  #include <Toolbox/PivotSR.mqh>                                  |
//+------------------------------------------------------------------+
#ifndef __PIVOTSR_MQH__
#define __PIVOTSR_MQH__

#include <Toolbox/SupportResistance.mqh>

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
    bool   valid;
};

//+------------------------------------------------------------------+
//|  IsPivotHigh                                                     |
//+------------------------------------------------------------------+
bool IsPivotHigh(string symbol, ENUM_TIMEFRAMES tf, int i, int n)
{
    double pivot_high = iHigh(symbol, tf, i);
    for(int j = 1; j <= n; j++)
    {
        if(iHigh(symbol, tf, i + j) >= pivot_high) return false;
        if(i - j < 0)                               return false;
        if(iHigh(symbol, tf, i - j) >= pivot_high) return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//|  IsPivotLow                                                      |
//+------------------------------------------------------------------+
bool IsPivotLow(string symbol, ENUM_TIMEFRAMES tf, int i, int n)
{
    double pivot_low = iLow(symbol, tf, i);
    for(int j = 1; j <= n; j++)
    {
        if(iLow(symbol, tf, i + j) <= pivot_low) return false;
        if(i - j < 0)                             return false;
        if(iLow(symbol, tf, i - j) <= pivot_low) return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//|  FindPivotHighs                                                  |
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

//+------------------------------------------------------------------+
//|  FindPivotLows                                                   |
//+------------------------------------------------------------------+
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
//|  修正：same_dist 改用 pip-based 容忍度（5 pips）                 |
//+------------------------------------------------------------------+
PivotPoint SelectBestAnchor(PivotPoint &candidates[], int count,
                             string symbol)
{
    PivotPoint best;
    best.price    = 0;
    best.bar      = 0;
    best.sr_count = 0;
    best.dist     = DBL_MAX;
    best.valid    = false;

    if(count == 0) return best;

    //--- 修正：用 pip-based 容忍度，唔係 0.000001
    double pip_tol = GetPipSize(symbol) * 5;  // 5 pips 容忍

    for(int i = 0; i < count; i++)
    {
        if(!candidates[i].valid) continue;

        bool closer    = candidates[i].dist < best.dist;
        bool same_dist = MathAbs(candidates[i].dist - best.dist) < pip_tol;
        bool stronger  = candidates[i].sr_count > best.sr_count;

        if(closer || (same_dist && stronger))
            best = candidates[i];
    }

    return best;
}

//+------------------------------------------------------------------+
//|  GetAnchorPoints                                                 |
//|  修正：加入 anchor.high > anchor.low 驗證                        |
//+------------------------------------------------------------------+
AnchorResult GetAnchorPoints(string symbol,
                             ENUM_TIMEFRAMES tf,
                             int    pivot_n     = 3,
                             int    pivot_look  = 50,
                             int    sr_lookback = 100,
                             double sr_pips     = 10.0,
                             int    sr_min      = 4,
                             double sr_tol_pips = 10.0,
                             int    shift       = 1)
{
    AnchorResult anchor;
    anchor.high     = 0;
    anchor.low      = 0;
    anchor.high_bar = 0;
    anchor.low_bar  = 0;
    anchor.high_sr  = 0;
    anchor.low_sr   = 0;
    anchor.valid    = false;

    double pip           = GetPipSize(symbol);
    double current_price = iClose(symbol, tf, shift);
    double sr_tolerance  = sr_tol_pips * pip;

    //--- S/R 密集區
    SRResult sr = CalcSRZones(symbol, tf, sr_lookback, sr_pips, sr_min, shift);

    //--- Pivot 候選
    PivotPoint pivot_highs[];
    PivotPoint pivot_lows[];

    int high_count = FindPivotHighs(symbol, tf, pivot_n, pivot_look,
                                    shift, pivot_highs, current_price);
    int low_count  = FindPivotLows (symbol, tf, pivot_n, pivot_look,
                                    shift, pivot_lows,  current_price);

    //--- Cross-reference Pivot + S/R
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

    //--- 揀最佳錨點
    PivotPoint best_high = SelectBestAnchor(pivot_highs, high_count, symbol);
    PivotPoint best_low  = SelectBestAnchor(pivot_lows,  low_count,  symbol);

    if(!best_high.valid || !best_low.valid)
        return anchor;

    //--- Bug 4 fix：確保 high > low，防止橫行市場搵到錯誤錨點
    if(best_high.price <= best_low.price)
    {
        PrintFormat("⚠️ PivotSR：Pivot High (%.5f) <= Pivot Low (%.5f)，錨點無效",
                    best_high.price, best_low.price);
        return anchor;
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
