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
    double price;    // Pivot 價格
    int    bar;      // Bar index（shift）
    int    sr_count; // 對應 S/R 密集區強度（0 = 冇對應）
    double dist;     // 距離現價嘅距離（price units）
    bool   valid;    // 係咪符合所有條件
};

//--- 錨點結果（交畀 Fibonacci 用）
struct AnchorResult
{
    double high;      // 選定嘅 Pivot High 錨點價格
    double low;       // 選定嘅 Pivot Low 錨點價格
    int    high_bar;  // Pivot High 發生嘅 bar index
    int    low_bar;   // Pivot Low 發生嘅 bar index
    int    high_sr;   // Pivot High 對應 S/R 強度
    int    low_sr;    // Pivot Low 對應 S/R 強度
    bool   valid;     // 係咪成功搵到有效錨點
};

//+------------------------------------------------------------------+
//|  IsPivotHigh                                                     |
//|  檢查 bar[i] 係咪真正嘅 Pivot High                               |
//|  條件：左右各 n bars 嘅每一條 bar 都低過 bar[i].high              |
//+------------------------------------------------------------------+
bool IsPivotHigh(string symbol, ENUM_TIMEFRAMES tf, int i, int n)
{
    double pivot_high = iHigh(symbol, tf, i);

    for(int j = 1; j <= n; j++)
    {
        //--- 左邊（更舊嘅 bar，shift 更大）
        if(iHigh(symbol, tf, i + j) >= pivot_high) return false;
        //--- 右邊（更新嘅 bar，shift 更小）
        if(i - j < 0) return false;
        if(iHigh(symbol, tf, i - j) >= pivot_high) return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//|  IsPivotLow                                                     |
//|  檢查 bar[i] 係咪真正嘅 Pivot Low                                |
//|  條件：左右各 n bars 嘅每一條 bar 都高過 bar[i].low              |
//+------------------------------------------------------------------+
bool IsPivotLow(string symbol, ENUM_TIMEFRAMES tf, int i, int n)
{
    double pivot_low = iLow(symbol, tf, i);

    for(int j = 1; j <= n; j++)
    {
        //--- 左邊
        if(iLow(symbol, tf, i + j) <= pivot_low) return false;
        //--- 右邊
        if(i - j < 0) return false;
        if(iLow(symbol, tf, i - j) <= pivot_low) return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//|  FindPivotHighs                                                  |
//|  喺過去 lookback bars 搵所有 Pivot High 候選                      |
//+------------------------------------------------------------------+
int FindPivotHighs(string symbol, ENUM_TIMEFRAMES tf,
                   int pivot_n, int lookback, int shift,
                   PivotPoint &results[], double current_price)
{
    int count = 0;
    int max_results = 50;
    ArrayResize(results, max_results);

    //--- 最早可以確認嘅 bar = shift + pivot_n（右邊需要 pivot_n bars）
    int start = shift + pivot_n;
    int end   = shift + lookback;

    for(int i = start; i < end && count < max_results; i++)
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
//|  喺過去 lookback bars 搵所有 Pivot Low 候選                       |
//+------------------------------------------------------------------+
int FindPivotLows(string symbol, ENUM_TIMEFRAMES tf,
                  int pivot_n, int lookback, int shift,
                  PivotPoint &results[], double current_price)
{
    int count = 0;
    int max_results = 50;
    ArrayResize(results, max_results);

    int start = shift + pivot_n;
    int end   = shift + lookback;

    for(int i = start; i < end && count < max_results; i++)
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
//|  從 Pivot 候選清單中，揀選最佳錨點                                |
//|  優先：距離現價最近                                                |
//|  次要（tiebreaker）：S/R 強度最高                                 |
//+------------------------------------------------------------------+
PivotPoint SelectBestAnchor(PivotPoint &candidates[], int count)
{
    PivotPoint best;
    best.price    = 0;
    best.bar      = 0;
    best.sr_count = 0;
    best.dist     = DBL_MAX;
    best.valid    = false;

    if(count == 0) return best;

    for(int i = 0; i < count; i++)
    {
        if(!candidates[i].valid) continue;

        bool closer    = candidates[i].dist     < best.dist;
        bool same_dist = MathAbs(candidates[i].dist - best.dist) < 0.000001;
        bool stronger  = candidates[i].sr_count > best.sr_count;

        if(closer || (same_dist && stronger))
            best = candidates[i];
    }

    return best;
}

//+------------------------------------------------------------------+
//|  GetAnchorPoints                                                 |
//|  主函數：結合 Pivot + S/R 搵最佳 Fibonacci 錨點                  |
//|                                                                  |
//|  symbol      : 交易品種                                           |
//|  tf          : 時間框架                                           |
//|  pivot_n     : Pivot 左右確認 bars（預設 3）                      |
//|  pivot_look  : Pivot 回望 bars（預設 50）                         |
//|  sr_lookback : S/R 回望 bars（預設 100）                          |
//|  sr_pips     : S/R 格距 pips（預設 10）                           |
//|  sr_min      : S/R 最低出現次數（預設 4）                          |
//|  sr_tol_pips : Pivot 同 S/R 配對容忍度 pips（預設 10）            |
//|  shift       : 從第幾根 bar 開始（預設 1）                         |
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

    double pip          = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
    double current_price = iClose(symbol, tf, shift);
    double sr_tolerance = sr_tol_pips * pip;

    //--- Step 1：計算 S/R 密集區
    SRResult sr = CalcSRZones(symbol, tf, sr_lookback, sr_pips, sr_min, shift);

    //--- Step 2：搵所有 Pivot High/Low 候選
    PivotPoint pivot_highs[];
    PivotPoint pivot_lows[];

    int high_count = FindPivotHighs(symbol, tf, pivot_n, pivot_look,
                                    shift, pivot_highs, current_price);
    int low_count  = FindPivotLows (symbol, tf, pivot_n, pivot_look,
                                    shift, pivot_lows,  current_price);

    //--- Step 3：Cross-reference Pivot 同 S/R
    //    有 S/R 支持 → 記錄強度
    //    冇 S/R 支持 → valid 仍然係 true（唔強制要求 S/R）
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

    //--- Step 4：揀最佳錨點（距離優先，S/R 強度做 tiebreaker）
    PivotPoint best_high = SelectBestAnchor(pivot_highs, high_count);
    PivotPoint best_low  = SelectBestAnchor(pivot_lows,  low_count);

    if(!best_high.valid || !best_low.valid)
        return anchor;

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
