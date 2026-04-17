//+------------------------------------------------------------------+
//|  SwingHighLow.mq5                                                |
//|  MQL5 Indicator Toolbox                                          |
//|  Visual chart indicator — attach to chart to verify logic        |
//|  Shows M5 and H1 swing levels as horizontal lines + Journal log  |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "1.00"
#property description "Draws Swing High/Low for M5 and H1. Prints values to Journal."

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

//--- M5 Swing High (red dashed line)
#property indicator_label1  "M5 Swing High"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_DASH
#property indicator_width1  1

//--- M5 Swing Low (blue dashed line)
#property indicator_label2  "M5 Swing Low"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_DASH
#property indicator_width2  1

//--- H1 Swing High (dark red solid line)
#property indicator_label3  "H1 Swing High"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDarkRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

//--- H1 Swing Low (dark blue solid line)
#property indicator_label4  "H1 Swing Low"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrMidnightBlue
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

#include <Toolbox/SwingHighLow.mqh>

//--- Input parameters
input int    InpSwingBars_M5 = 20;   // M5 lookback K線數 / M5 lookback bars
input int    InpSwingBars_H1 = 30;   // H1 lookback K線數 / H1 lookback bars
input bool   InpPrintLog     = true; // 輸出至 Journal / Print to Journal

//--- Buffers
double Buffer_M5_High[];
double Buffer_M5_Low[];
double Buffer_H1_High[];
double Buffer_H1_Low[];

//+------------------------------------------------------------------+
int OnInit()
{
    SetIndexBuffer(0, Buffer_M5_High, INDICATOR_DATA);
    SetIndexBuffer(1, Buffer_M5_Low,  INDICATOR_DATA);
    SetIndexBuffer(2, Buffer_H1_High, INDICATOR_DATA);
    SetIndexBuffer(3, Buffer_H1_Low,  INDICATOR_DATA);

    ArraySetAsSeries(Buffer_M5_High, true);
    ArraySetAsSeries(Buffer_M5_Low,  true);
    ArraySetAsSeries(Buffer_H1_High, true);
    ArraySetAsSeries(Buffer_H1_Low,  true);

    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("SwingHL(M5:%d H1:%d)", InpSwingBars_M5, InpSwingBars_H1));

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
    //--- Need enough bars
    if(rates_total < InpSwingBars_M5 + 2)
        return 0;

    int start = (prev_calculated == 0) ? rates_total - 1 : prev_calculated;

    for(int i = start; i >= 0; i--)
    {
        int shift = rates_total - 1 - i; // convert buffer index to bar shift
        if(shift < 1) { shift = 1; }     // always use closed bars

        //--- M5 swing (on current chart timeframe, assumed M5)
        Buffer_M5_High[i] = GetSwingHigh(_Symbol, PERIOD_M5, InpSwingBars_M5, shift);
        Buffer_M5_Low[i]  = GetSwingLow (_Symbol, PERIOD_M5, InpSwingBars_M5, shift);

        //--- H1 swing
        Buffer_H1_High[i] = GetSwingHigh(_Symbol, PERIOD_H1, InpSwingBars_H1, shift);
        Buffer_H1_Low[i]  = GetSwingLow (_Symbol, PERIOD_H1, InpSwingBars_H1, shift);
    }

    //--- Print latest values to Journal (only on new bar)
    if(InpPrintLog && prev_calculated != rates_total)
    {
        SwingResult m5 = GetSwing(_Symbol, PERIOD_M5, InpSwingBars_M5, 1);
        SwingResult h1 = GetSwing(_Symbol, PERIOD_H1, InpSwingBars_H1, 1);

        double pip = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;

        PrintFormat("=== SwingHighLow 波段高低位 | %s | %s ===",
                    _Symbol,
                    TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));

        PrintFormat("  M5(%d bars) | 波段高 SwingHigh: %.5f (bar %d)  波段低 SwingLow: %.5f (bar %d)  幅度 Range: %.1f pips",
                    InpSwingBars_M5,
                    m5.high, m5.high_shift,
                    m5.low,  m5.low_shift,
                    (m5.high - m5.low) / pip);

        PrintFormat("  H1(%d bars) | 波段高 SwingHigh: %.5f (bar %d)  波段低 SwingLow: %.5f (bar %d)  幅度 Range: %.1f pips",
                    InpSwingBars_H1,
                    h1.high, h1.high_shift,
                    h1.low,  h1.low_shift,
                    (h1.high - h1.low) / pip);
    }

    return rates_total;
}
