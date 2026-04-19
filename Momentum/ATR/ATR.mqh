//+------------------------------------------------------------------+
//|  ATR.mqh                                                         |
//|  MQL5 Indicator Toolbox                                          |
//|  純邏輯庫 Pure logic library                                      |
//|  冇圖表輸出，冇事件函數 No chart output, no event functions        |
//|  #include <Toolbox/ATR.mqh>                                      |
//|                                                                  |
//|  Handle 設計：                                                    |
//|  - Caller 喺 OnInit() 用 CreateATRHandle() 建立 handle           |
//|  - Caller 喺 OnDeinit() 用 ReleaseATRHandle() 釋放 handle        |
//|  - GetATR() 接受 handle 作參數，唔自己建立或釋放                  |
//+------------------------------------------------------------------+
#ifndef __ATR_MQH__
#define __ATR_MQH__

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
//|  CreateATRHandle                                                 |
//|  建立 ATR handle — 喺 OnInit() 調用一次                          |
//+------------------------------------------------------------------+
int CreateATRHandle(string symbol, ENUM_TIMEFRAMES tf, int period)
{
    int handle = iATR(symbol, tf, period);
    if(handle == INVALID_HANDLE)
        PrintFormat("錯誤 ERROR: iATR handle 建立失敗 | symbol=%s tf=%d period=%d",
                    symbol, tf, period);
    return handle;
}

//+------------------------------------------------------------------+
//|  ReleaseATRHandle                                                |
//|  釋放 ATR handle — 喺 OnDeinit() 調用                            |
//+------------------------------------------------------------------+
void ReleaseATRHandle(int &handle)
{
    if(handle != INVALID_HANDLE)
    {
        IndicatorRelease(handle);
        handle = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//|  GetATR                                                          |
//|  Returns ATR value                                               |
//|  handle : 由 CreateATRHandle() 建立，caller 保管                 |
//|  shift  : 1 = 最後收盤 bar（預設，EA 安全用）                    |
//+------------------------------------------------------------------+
double GetATR(int handle, int shift = 1)
{
    if(handle == INVALID_HANDLE)
        return 0.0;

    double buf[];
    ArraySetAsSeries(buf, true);

    if(CopyBuffer(handle, 0, shift, 1, buf) <= 0)
        return 0.0;

    return buf[0];
}

//+------------------------------------------------------------------+
//|  GetATRPips                                                      |
//|  Returns ATR in pips                                             |
//+------------------------------------------------------------------+
double GetATRPips(int handle, string symbol, int shift = 1)
{
    double pip = GetPipSize(symbol);
    if(pip == 0) return 0.0;
    return GetATR(handle, shift) / pip;
}

//+------------------------------------------------------------------+
//|  GetSL_ATR                                                       |
//|  Returns SL distance in price based on ATR multiplier            |
//|  Normal SL  : mult = 1.5（v3 spec 起點）                         |
//|  Event SL   : mult = 2.0（news window）                          |
//+------------------------------------------------------------------+
double GetSL_ATR(int handle, double mult = 1.5, int shift = 1)
{
    return GetATR(handle, shift) * mult;
}

//+------------------------------------------------------------------+
//|  GetSL_ATR_Pips                                                  |
//|  Returns SL distance in pips                                     |
//+------------------------------------------------------------------+
double GetSL_ATR_Pips(int handle, string symbol,
                      double mult = 1.5, int shift = 1)
{
    double pip = GetPipSize(symbol);
    if(pip == 0) return 0.0;
    return GetSL_ATR(handle, mult, shift) / pip;
}

//+------------------------------------------------------------------+
//|  GetMinSL_Pips                                                   |
//|  Returns minimum SL floor in pips per symbol（v3 spec）          |
//+------------------------------------------------------------------+
double GetMinSL_Pips(string symbol)
{
    if(symbol == "USDJPY") return 6.0;
    return 4.0;  // 其他品種暫定，forward test 後調整
}

//+------------------------------------------------------------------+
//|  GetEffectiveSL_Pips                                             |
//|  Returns max(ATR-based SL, minimum floor SL) in pips            |
//+------------------------------------------------------------------+
double GetEffectiveSL_Pips(int handle, string symbol,
                            double mult = 1.5, int shift = 1)
{
    double atr_sl = GetSL_ATR_Pips(handle, symbol, mult, shift);
    double min_sl = GetMinSL_Pips(symbol);
    return MathMax(atr_sl, min_sl);
}

//+------------------------------------------------------------------+
//|  GetTrailingStop_ATR                                             |
//|  Returns trailing stop distance in price（Leg B Phase 2）        |
//|  v3 spec: 1.5 × ATR(M5)                                         |
//+------------------------------------------------------------------+
double GetTrailingStop_ATR(int handle, double mult = 1.5, int shift = 1)
{
    return GetATR(handle, shift) * mult;
}

//+------------------------------------------------------------------+
//|  GetFibProximityThreshold                                        |
//|  Returns Fib proximity threshold in price                        |
//|  Pro spec: ATR × 0.20                                           |
//+------------------------------------------------------------------+
double GetFibProximityThreshold(int handle, double mult = 0.20, int shift = 1)
{
    return GetATR(handle, shift) * mult;
}

#endif // __ATR_MQH__
