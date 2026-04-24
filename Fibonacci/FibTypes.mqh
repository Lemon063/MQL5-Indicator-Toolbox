//+------------------------------------------------------------------+
//|  FibTypes.mqh                                                    |
//|  MQL5 Indicator Toolbox                                          |
//|  Fibonacci struct 定義 — 純 types，冇邏輯                        |
//|  抽出獨立 file 避免 PivotSR.mqh 同 Fibonacci.mqh 循環依賴        |
//|  #include <Toolbox/FibTypes.mqh>                                 |
//+------------------------------------------------------------------+
#ifndef __FIBTYPES_MQH__
#define __FIBTYPES_MQH__

//+------------------------------------------------------------------+
//|  FibLevels                                                       |
//|  儲存一組完整嘅 Fibonacci levels                                  |
//+------------------------------------------------------------------+
struct FibLevels
{
    //--- 錨點
    double swing_high;   // Pivot High 錨點（1.000）
    double swing_low;    // Pivot Low 錨點（0.000）
    double range;        // swing_high - swing_low

    //--- Retracement levels
    double fib_236;
    double fib_382;
    double fib_500;
    double fib_618;
    double fib_786;

    //--- Extension levels
    double fib_1000;     // = swing_high (BUY) 或 swing_low (SELL)
    double fib_1618;
    double fib_2618;
    double fib_3618;

    bool   is_buy;       // true = BUY 方向，false = SELL 方向
};

#endif // __FIBTYPES_MQH__
