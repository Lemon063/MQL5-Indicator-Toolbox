//+------------------------------------------------------------------+
//|  SwingHighLow.mqh                                                |
//|  MQL5 Indicator Toolbox                                          |
//|  Pure logic library — no chart output, no event functions        |
//|  #include <Toolbox/SwingHighLow.mqh>                             |
//+------------------------------------------------------------------+
#ifndef __SWINGHIGHLOW_MQH__
#define __SWINGHIGHLOW_MQH__

//--- Struct to hold both swing values together
struct SwingResult
{
    double high;       // Swing High price
    double low;        // Swing Low price
    int    high_shift; // Bar index of Swing High (0 = current)
    int    low_shift;  // Bar index of Swing Low  (0 = current)
};

//+------------------------------------------------------------------+
//|  GetSwingHigh                                                    |
//|  Returns the highest High over the last N bars                   |
//|  symbol : trading symbol                                         |
//|  tf     : timeframe (e.g. PERIOD_M5, PERIOD_H1)                 |
//|  n_bars : lookback period                                        |
//|  shift  : start from this bar (1 = last closed bar)             |
//+------------------------------------------------------------------+
double GetSwingHigh(string symbol, ENUM_TIMEFRAMES tf, int n_bars, int shift = 1)
{
    int start = shift;
    int end   = shift + n_bars - 1;

    double highest = -DBL_MAX;
    for(int i = start; i <= end; i++)
    {
        double h = iHigh(symbol, tf, i);
        if(h > highest)
            highest = h;
    }
    return highest;
}

//+------------------------------------------------------------------+
//|  GetSwingLow                                                     |
//|  Returns the lowest Low over the last N bars                     |
//+------------------------------------------------------------------+
double GetSwingLow(string symbol, ENUM_TIMEFRAMES tf, int n_bars, int shift = 1)
{
    int start = shift;
    int end   = shift + n_bars - 1;

    double lowest = DBL_MAX;
    for(int i = start; i <= end; i++)
    {
        double l = iLow(symbol, tf, i);
        if(l < lowest)
            lowest = l;
    }
    return lowest;
}

//+------------------------------------------------------------------+
//|  GetSwingHighShift                                               |
//|  Returns the bar index (shift) where Swing High occurred         |
//+------------------------------------------------------------------+
int GetSwingHighShift(string symbol, ENUM_TIMEFRAMES tf, int n_bars, int shift = 1)
{
    int    start       = shift;
    int    end         = shift + n_bars - 1;
    double highest     = -DBL_MAX;
    int    best_shift  = start;

    for(int i = start; i <= end; i++)
    {
        double h = iHigh(symbol, tf, i);
        if(h > highest)
        {
            highest    = h;
            best_shift = i;
        }
    }
    return best_shift;
}

//+------------------------------------------------------------------+
//|  GetSwingLowShift                                                |
//|  Returns the bar index (shift) where Swing Low occurred          |
//+------------------------------------------------------------------+
int GetSwingLowShift(string symbol, ENUM_TIMEFRAMES tf, int n_bars, int shift = 1)
{
    int    start      = shift;
    int    end        = shift + n_bars - 1;
    double lowest     = DBL_MAX;
    int    best_shift = start;

    for(int i = start; i <= end; i++)
    {
        double l = iLow(symbol, tf, i);
        if(l < lowest)
        {
            lowest     = l;
            best_shift = i;
        }
    }
    return best_shift;
}

//+------------------------------------------------------------------+
//|  GetSwing                                                        |
//|  Returns both Swing High and Low in one call (SwingResult)       |
//+------------------------------------------------------------------+
SwingResult GetSwing(string symbol, ENUM_TIMEFRAMES tf, int n_bars, int shift = 1)
{
    SwingResult result;
    result.high       = GetSwingHigh(symbol, tf, n_bars, shift);
    result.low        = GetSwingLow(symbol, tf, n_bars, shift);
    result.high_shift = GetSwingHighShift(symbol, tf, n_bars, shift);
    result.low_shift  = GetSwingLowShift(symbol, tf, n_bars, shift);
    return result;
}

#endif // __SWINGHIGHLOW_MQH__
