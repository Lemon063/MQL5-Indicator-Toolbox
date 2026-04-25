//+------------------------------------------------------------------+
//|  Fibonacci.mqh                                                   |
//|  MQL5 Indicator Toolbox                                          |
//|  純邏輯庫 Pure logic library                                      |
//|  依賴 Depends on: PivotSR.mqh → SupportResistance.mqh           |
//|                                  FibTypes.mqh                   |
//|  #include <Toolbox/Fibonacci.mqh>                                |
//+------------------------------------------------------------------+
#ifndef __FIBONACCI_MQH__
#define __FIBONACCI_MQH__

#include <Toolbox/PivotSR.mqh>
// FibTypes.mqh 已經由 PivotSR.mqh include

//+------------------------------------------------------------------+
//|  CalcFibLevels                                                   |
//|  由錨點計算所有 Fib levels                                        |
//+------------------------------------------------------------------+
FibLevels CalcFibLevels(double swing_high, double swing_low, bool is_buy)
{
    FibLevels f;
    f.swing_high = swing_high;
    f.swing_low  = swing_low;
    f.range      = swing_high - swing_low;
    f.is_buy     = is_buy;

    if(is_buy)
    {
        f.fib_236  = swing_low + 0.236 * f.range;
        f.fib_382  = swing_low + 0.382 * f.range;
        f.fib_500  = swing_low + 0.500 * f.range;
        f.fib_618  = swing_low + 0.618 * f.range;
        f.fib_786  = swing_low + 0.786 * f.range;
        f.fib_1000 = swing_high;
        f.fib_1618 = swing_high + 0.618 * f.range;
        f.fib_2618 = swing_high + 1.618 * f.range;
        f.fib_3618 = swing_high + 2.618 * f.range;
    }
    else
    {
        f.fib_236  = swing_high - 0.236 * f.range;
        f.fib_382  = swing_high - 0.382 * f.range;
        f.fib_500  = swing_high - 0.500 * f.range;
        f.fib_618  = swing_high - 0.618 * f.range;
        f.fib_786  = swing_high - 0.786 * f.range;
        f.fib_1000 = swing_low;
        f.fib_1618 = swing_low  - 0.618 * f.range;
        f.fib_2618 = swing_low  - 1.618 * f.range;
        f.fib_3618 = swing_low  - 2.618 * f.range;
    }

    return f;
}

//+------------------------------------------------------------------+
//|  CalcFibAuto                                                     |
//|  用 PivotSR 自動搵錨點再計算 Fib levels                          |
//|  v2.2：傳入 is_buy 至 GetAnchorPoints，確保方向性驗證             |
//+------------------------------------------------------------------+
FibLevels CalcFibAuto(string symbol,
                      ENUM_TIMEFRAMES  tf,
                      ENUM_ANCHOR_MODE mode,
                      bool   is_buy,
                      int    pivot_n        = 3,
                      int    pivot_look     = 50,
                      int    sr_lookback    = 100,
                      double sr_pips        = 10.0,
                      int    sr_min         = 4,
                      double sr_tol_pips    = 10.0,
                      double min_range_pips = 0.0,
                      int    shift          = 1)
{
    FibLevels f;
    f.swing_high = 0;
    f.swing_low  = 0;
    f.range      = 0;
    f.is_buy     = is_buy;

    AnchorResult anchor = GetAnchorPoints(
        symbol, tf, mode,
        is_buy,        // ← v2.2：傳入方向，觸發 Step 4b 方向性驗證
        pivot_n, pivot_look,
        sr_lookback, sr_pips,
        sr_min, sr_tol_pips,
        min_range_pips, shift);

    if(!anchor.valid)
        return f;

    return CalcFibLevels(anchor.high, anchor.low, is_buy);
}

//+------------------------------------------------------------------+
//|  IsFibNear                                                       |
//|  檢查價格係咪接近任何 Fib level                                   |
//+------------------------------------------------------------------+
bool IsFibNear(double price, const FibLevels &f, double threshold,
               string &nearest_label, double &nearest_price)
{
    double levels[9];
    string labels[9];

    levels[0] = f.fib_236;  labels[0] = "0.236";
    levels[1] = f.fib_382;  labels[1] = "0.382";
    levels[2] = f.fib_500;  labels[2] = "0.500";
    levels[3] = f.fib_618;  labels[3] = "0.618";
    levels[4] = f.fib_786;  labels[4] = "0.786";
    levels[5] = f.fib_1000; labels[5] = "1.000";
    levels[6] = f.fib_1618; labels[6] = "1.618";
    levels[7] = f.fib_2618; labels[7] = "2.618";
    levels[8] = f.fib_3618; labels[8] = "3.618";

    double   closest_dist = DBL_MAX;
    bool     found        = false;
    nearest_label = "none";
    nearest_price = 0;

    for(int i = 0; i < 9; i++)
    {
        double dist = MathAbs(price - levels[i]);
        if(dist < threshold && dist < closest_dist)
        {
            closest_dist  = dist;
            nearest_label = labels[i];
            nearest_price = levels[i];
            found         = true;
        }
    }

    return found;
}

//+------------------------------------------------------------------+
//|  IsWickBeyond3618                                                |
//|  Exhaustion Condition 3：wick 超過 Fib 3.618                     |
//+------------------------------------------------------------------+
bool IsWickBeyond3618(double bar_high, double bar_low, const FibLevels &f)
{
    if(f.is_buy)
        return (bar_high > f.fib_3618);
    else
        return (bar_low  < f.fib_3618);
}

#endif // __FIBONACCI_MQH__
