//+------------------------------------------------------------------+
//|  Fibonacci.mqh                                                   |
//|  MQL5 Indicator Toolbox                                          |
//|  Pure logic library — no chart output, no event functions        |
//|  Depends on: SwingHighLow.mqh                                    |
//|  #include <Toolbox/Fibonacci.mqh>                                |
//+------------------------------------------------------------------+
#ifndef __FIBONACCI_MQH__
#define __FIBONACCI_MQH__
#include <Toolbox/SwingHighLow.mqh>

//--- Struct holding all Fib levels for one direction
struct FibLevels
{
    //--- Input anchors
    double swing_high;
    double swing_low;
    double range;

    //--- Retracement levels (support for BUY, resistance for SELL)
    double fib_236;
    double fib_382;
    double fib_500;
    double fib_618;
    double fib_786;

    //--- Extension levels (exhaustion / target)
    double fib_1000;  // 1.000 = swing high itself
    double fib_1618;
    double fib_2618;
    double fib_3618;

    //--- Direction this set was calculated for
    bool   is_buy;    // true = BUY levels, false = SELL levels
};

//+------------------------------------------------------------------+
//|  CalcFibLevels                                                   |
//|  Calculates all Fib retracement + extension levels               |
//|  is_buy  : true  = BUY  (retracements below swing high)          |
//|            false = SELL (retracements above swing low)           |
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
        //--- BUY: retracements count UP from swing_low
        f.fib_236  = swing_low + 0.236 * f.range;
        f.fib_382  = swing_low + 0.382 * f.range;
        f.fib_500  = swing_low + 0.500 * f.range;
        f.fib_618  = swing_low + 0.618 * f.range;
        f.fib_786  = swing_low + 0.786 * f.range;

        //--- Extensions count UP from swing_high
        f.fib_1000 = swing_high;
        f.fib_1618 = swing_high + 0.618 * f.range;
        f.fib_2618 = swing_high + 1.618 * f.range;
        f.fib_3618 = swing_high + 2.618 * f.range;
    }
    else
    {
        //--- SELL: retracements count DOWN from swing_high
        f.fib_236  = swing_high - 0.236 * f.range;
        f.fib_382  = swing_high - 0.382 * f.range;
        f.fib_500  = swing_high - 0.500 * f.range;
        f.fib_618  = swing_high - 0.618 * f.range;
        f.fib_786  = swing_high - 0.786 * f.range;

        //--- Extensions count DOWN from swing_low
        f.fib_1000 = swing_low;
        f.fib_1618 = swing_low  - 0.618 * f.range;
        f.fib_2618 = swing_low  - 1.618 * f.range;
        f.fib_3618 = swing_low  - 2.618 * f.range;
    }

    return f;
}

//+------------------------------------------------------------------+
//|  CalcFibAuto                                                     |
//|  Convenience: pulls SwingHighLow automatically then calculates   |
//+------------------------------------------------------------------+
FibLevels CalcFibAuto(string symbol, ENUM_TIMEFRAMES tf,
                      int n_bars, bool is_buy, int shift = 1)
{
    SwingResult swing = GetSwing(symbol, tf, n_bars, shift);
    return CalcFibLevels(swing.high, swing.low, is_buy);
}

//+------------------------------------------------------------------+
//|  IsFibNear                                                       |
//|  Returns true if price is within threshold of any Fib level      |
//|  threshold = ATR * atr_mult (from ATR.mqh caller)               |
//|  Returns the nearest level label as output string                |
//+------------------------------------------------------------------+
bool IsFibNear(double price, const FibLevels &f, double threshold,
               string &nearest_label, double &nearest_price)
{
    //--- Build lookup table
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

    double   closest_dist  = DBL_MAX;
    bool     found         = false;
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
//|  Exhaustion Condition 3 — candle wick exceeds Fib 3.618          |
//|  For BUY spike: checks upper wick vs fib_3618                    |
//|  For SELL spike: checks lower wick vs fib_3618                   |
//+------------------------------------------------------------------+
bool IsWickBeyond3618(double bar_high, double bar_low, const FibLevels &f)
{
    if(f.is_buy)
        return (bar_high > f.fib_3618);
    else
        return (bar_low < f.fib_3618);
}

#endif // __FIBONACCI_MQH__
