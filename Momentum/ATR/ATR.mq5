//+------------------------------------------------------------------+
//|  ATR.mq5                                                         |
//|  MQL5 Indicator Toolbox                                          |
//|  視覺圖表 indicator — attach 到 chart 驗證邏輯                    |
//|  Sub-window 顯示 ATR 線 + 印出所有衍生數值                        |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "1.20"
#property description "ATR with derived values: SL, trailing, Fib threshold. Prints to Journal."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Raw ATR（白色實線）
#property indicator_label1  "ATR"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrWhite
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- SL 1.5x ATR（橙色虛線）
#property indicator_label2  "SL 1.5x"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_DASH
#property indicator_width2  1

//--- Event SL 2.0x ATR（紅色虛線）
#property indicator_label3  "SL 2.0x (Event)"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_style3  STYLE_DASH
#property indicator_width3  1

#include <Toolbox/ATR.mqh>

//--- Inputs
input int    InpATRPeriod    = 14;    // ATR 計算週期 / ATR period
input double InpSL_Mult      = 1.50;  // 正常 SL 乘數 / Normal SL multiplier
input double InpEventSL_Mult = 2.00;  // 新聞時段 SL 乘數 / Event SL multiplier
input double InpFibMult      = 0.20;  // Fib 接近閾值乘數 / Fib proximity multiplier
input bool   InpPrintLog     = true;  // 輸出至 Journal / Print to Journal

//--- Buffers
double Buffer_ATR[];
double Buffer_SL[];
double Buffer_EventSL[];

//--- Handle（OnInit 建立，OnDeinit 釋放）
int g_atrHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
{
    SetIndexBuffer(0, Buffer_ATR,     INDICATOR_DATA);
    SetIndexBuffer(1, Buffer_SL,      INDICATOR_DATA);
    SetIndexBuffer(2, Buffer_EventSL, INDICATOR_DATA);

    ArraySetAsSeries(Buffer_ATR,     true);
    ArraySetAsSeries(Buffer_SL,      true);
    ArraySetAsSeries(Buffer_EventSL, true);

    //--- PERIOD_CURRENT：跟住 chart TF，唔寫死
    //    attach M5 chart → 計 M5 ATR
    //    attach H1 chart → 計 H1 ATR
    g_atrHandle = CreateATRHandle(_Symbol, PERIOD_CURRENT, InpATRPeriod);
    if(g_atrHandle == INVALID_HANDLE)
        return INIT_FAILED;

    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("ATR(%d)", InpATRPeriod));

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ReleaseATRHandle(g_atrHandle);
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

    //--- 填充 buffer
    for(int i = start; i >= 0; i--)
    {
        int shift = rates_total - 1 - i;
        if(shift < 1) shift = 1;

        double atr        = GetATR(g_atrHandle, shift);
        Buffer_ATR[i]     = atr;
        Buffer_SL[i]      = atr * InpSL_Mult;
        Buffer_EventSL[i] = atr * InpEventSL_Mult;
    }

    //--- 只喺新 bar 印 Journal
    if(InpPrintLog && prev_calculated != rates_total)
    {
        double atr     = GetATR(g_atrHandle, 1);
        double pip     = GetPipSize(_Symbol);
        double sl_pips = GetEffectiveSL_Pips(g_atrHandle, _Symbol, InpSL_Mult, 1);
        double ev_pips = GetEffectiveSL_Pips(g_atrHandle, _Symbol, InpEventSL_Mult, 1);
        double trail   = GetTrailingStop_ATR(g_atrHandle, InpSL_Mult, 1);
        double fib_thr = GetFibProximityThreshold(g_atrHandle, InpFibMult, 1);
        double min_sl  = GetMinSL_Pips(_Symbol);

        PrintFormat("=== ATR 真實波幅 | %s | %s | TF: %s ===",
                    _Symbol,
                    TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES),
                    EnumToString(Period()));

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
