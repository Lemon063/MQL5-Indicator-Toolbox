//+------------------------------------------------------------------+
//|  ATR.mq5                                                         |
//|  MQL5 Indicator Toolbox                                          |
//|  Visual chart indicator — attach to chart to verify logic        |
//|  Draws ATR line in sub-window + prints all derived values        |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "1.00"
#property description "ATR with derived values: SL, trailing, Fib threshold. Prints to Journal."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Raw ATR (white)
#property indicator_label1  "ATR"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrWhite
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- SL distance (1.5x ATR) — orange
#property indicator_label2  "SL 1.5x"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_DASH
#property indicator_width2  1

//--- Event SL (2.0x ATR) — red
#property indicator_label3  "SL 2.0x (Event)"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_style3  STYLE_DASH
#property indicator_width3  1

#include <Toolbox/ATR.mqh>

//--- Inputs
input int    InpATRPeriod     = 14;    // ATR 計算週期 / ATR period
input double InpSL_Mult       = 1.50;  // 正常 SL 乘數 / Normal SL multiplier
input double InpEventSL_Mult  = 2.00;  // 新聞時段 SL 乘數 / Event SL multiplier
input double InpFibMult       = 0.20;  // Fib 接近閾值乘數 / Fib proximity multiplier
input bool   InpPrintLog      = true;  // 輸出至 Journal / Print to Journal

//--- Buffers
double Buffer_ATR[];
double Buffer_SL[];
double Buffer_EventSL[];

//+------------------------------------------------------------------+
int OnInit()
{
    SetIndexBuffer(0, Buffer_ATR,     INDICATOR_DATA);
    SetIndexBuffer(1, Buffer_SL,      INDICATOR_DATA);
    SetIndexBuffer(2, Buffer_EventSL, INDICATOR_DATA);

    ArraySetAsSeries(Buffer_ATR,     true);
    ArraySetAsSeries(Buffer_SL,      true);
    ArraySetAsSeries(Buffer_EventSL, true);

    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("ATR(%d)", InpATRPeriod));

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
{
    if(rates_total < InpATRPeriod + 2)
        return 0;

    int start = (prev_calculated == 0) ? rates_total - 1 : prev_calculated;

    for(int i = start; i >= 0; i--)
    {
        int shift = rates_total - 1 - i;
        if(shift < 1) shift = 1;

        double atr = GetATR(_Symbol, PERIOD_M5, InpATRPeriod, shift);

        Buffer_ATR[i]     = atr;
        Buffer_SL[i]      = atr * InpSL_Mult;
        Buffer_EventSL[i] = atr * InpEventSL_Mult;
    }

    //--- Print latest values on new bar
    if(InpPrintLog && prev_calculated != rates_total)
    {
        double atr       = GetATR(_Symbol, PERIOD_M5, InpATRPeriod, 1);
        double pip       = GetPipSize(_Symbol);
        double sl_pips   = GetEffectiveSL_Pips(_Symbol, PERIOD_M5, InpATRPeriod, InpSL_Mult, 1);
        double ev_pips   = GetEffectiveSL_Pips(_Symbol, PERIOD_M5, InpATRPeriod, InpEventSL_Mult, 1);
        double trail     = GetTrailingStop_ATR(_Symbol, PERIOD_M5, InpATRPeriod, InpSL_Mult, 1);
        double fib_thr   = GetFibProximityThreshold(_Symbol, PERIOD_M5, InpATRPeriod, InpFibMult, 1);
        double min_sl    = GetMinSL_Pips(_Symbol);

        PrintFormat("=== ATR 真實波幅 | %s | %s ===",
                    _Symbol,
                    TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));

        PrintFormat("  ATR 原始值   | %.5f  (%.1f pips)",
                    atr, atr / pip);

        PrintFormat("  正常止損 SL  | %.1fx ATR = %.5f  (%.1f pips)  |  最低下限: %.1f pips  |  有效 SL: %.1f pips",
                    InpSL_Mult, atr * InpSL_Mult, atr * InpSL_Mult / pip, min_sl, sl_pips);

        PrintFormat("  新聞止損 SL  | %.1fx ATR = %.5f  (%.1f pips)  |  有效 SL: %.1f pips",
                    InpEventSL_Mult, atr * InpEventSL_Mult, atr * InpEventSL_Mult / pip, ev_pips);

        PrintFormat("  追蹤止損     | %.1fx ATR = %.5f  (%.1f pips)",
                    InpSL_Mult, trail, trail / pip);

        PrintFormat("  Fib 接近閾值 | %.2fx ATR = %.5f  (%.1f pips)",
                    InpFibMult, fib_thr, fib_thr / pip);
    }

    return rates_total;
}
