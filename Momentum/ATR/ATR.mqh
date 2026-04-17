//+------------------------------------------------------------------+
//|  ATR.mqh                                                         |
//|  MQL5 Indicator Toolbox                                          |
//|  Pure logic library — no chart output, no event functions        |
//|  #include <Toolbox/ATR.mqh>                                      |
//+------------------------------------------------------------------+
#pragma once

//+------------------------------------------------------------------+
//|  GetPipSize                                                      |
//|  Returns pip size for any supported symbol                       |
//|  USDJPY (3 digits) → point × 10                                 |
//|  GBPUSD / EURUSD / AUDUSD (5 digits) → point × 10              |
//+------------------------------------------------------------------+
double GetPipSize(string symbol)
{
    return SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
}

//+------------------------------------------------------------------+
//|  GetATR                                                          |
//|  Returns ATR value for given symbol, timeframe, period, shift    |
//|  shift = 1 → last closed bar (default, safe for EA use)         |
//+------------------------------------------------------------------+
double GetATR(string symbol, ENUM_TIMEFRAMES tf, int period, int shift = 1)
{
    int handle = iATR(symbol, tf, period);
    if(handle == INVALID_HANDLE)
        return 0.0;

    double buf[];
    ArraySetAsSeries(buf, true);

    if(CopyBuffer(handle, 0, shift, 1, buf) <= 0)
        return 0.0;

    IndicatorRelease(handle);
    return buf[0];
}

//+------------------------------------------------------------------+
//|  GetATRPips                                                      |
//|  Returns ATR in pips (uses GetPipSize internally)                |
//+------------------------------------------------------------------+
double GetATRPips(string symbol, ENUM_TIMEFRAMES tf, int period, int shift = 1)
{
    double pip = GetPipSize(symbol);
    if(pip == 0) return 0.0;
    return GetATR(symbol, tf, period, shift) / pip;
}

//+------------------------------------------------------------------+
//|  GetSL_ATR                                                       |
//|  Returns SL distance in price based on ATR multiplier            |
//|  Normal SL  : mult = 1.5 (default, v3 spec)                     |
//|  Event SL   : mult = 2.0 (news window, v3 spec)                 |
//+------------------------------------------------------------------+
double GetSL_ATR(string symbol, ENUM_TIMEFRAMES tf, int period,
                 double mult = 1.5, int shift = 1)
{
    return GetATR(symbol, tf, period, shift) * mult;
}

//+------------------------------------------------------------------+
//|  GetSL_ATR_Pips                                                  |
//|  Returns SL distance in pips                                     |
//+------------------------------------------------------------------+
double GetSL_ATR_Pips(string symbol, ENUM_TIMEFRAMES tf, int period,
                      double mult = 1.5, int shift = 1)
{
    double pip = GetPipSize(symbol);
    if(pip == 0) return 0.0;
    return GetSL_ATR(symbol, tf, period, mult, shift) / pip;
}

//+------------------------------------------------------------------+
//|  GetMinSL_Pips                                                   |
//|  Returns minimum SL floor in pips per symbol (v3 spec)          |
//+------------------------------------------------------------------+
double GetMinSL_Pips(string symbol)
{
    //--- v3 spec: USDJPY minimum 6 pips
    if(symbol == "USDJPY") return 6.0;
    //--- Other pairs: 4 pips default (adjust after forward test)
    return 4.0;
}

//+------------------------------------------------------------------+
//|  GetEffectiveSL_Pips                                             |
//|  Returns max(ATR-based SL, minimum floor SL) in pips            |
//+------------------------------------------------------------------+
double GetEffectiveSL_Pips(string symbol, ENUM_TIMEFRAMES tf, int period,
                            double mult = 1.5, int shift = 1)
{
    double atr_sl = GetSL_ATR_Pips(symbol, tf, period, mult, shift);
    double min_sl = GetMinSL_Pips(symbol);
    return MathMax(atr_sl, min_sl);
}

//+------------------------------------------------------------------+
//|  GetTrailingStop_ATR                                             |
//|  Returns trailing stop distance in price (Leg B Phase 2)        |
//|  v3 spec: 1.5 × ATR(M5)                                         |
//+------------------------------------------------------------------+
double GetTrailingStop_ATR(string symbol, ENUM_TIMEFRAMES tf,
                           int period, double mult = 1.5, int shift = 1)
{
    return GetATR(symbol, tf, period, shift) * mult;
}

//+------------------------------------------------------------------+
//|  GetFibProximityThreshold                                        |
//|  Returns Fib proximity threshold in price                        |
//|  Pro spec: ATR × 0.20                                           |
//+------------------------------------------------------------------+
double GetFibProximityThreshold(string symbol, ENUM_TIMEFRAMES tf,
                                int period, double mult = 0.20, int shift = 1)
{
    return GetATR(symbol, tf, period, shift) * mult;
}
