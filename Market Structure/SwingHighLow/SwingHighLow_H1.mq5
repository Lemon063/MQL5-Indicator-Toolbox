//+------------------------------------------------------------------+
//|  SwingHighLow_H1.mq5                                             |
//|  MQL5 Indicator Toolbox                                          |
//|  視覺圖表 indicator — attach 到 H1 chart 驗證邏輯                |
//|  只顯示 H1 Swing High / Low                                      |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "1.10"
#property description "H1 Swing High/Low. Attach to H1 chart. Prints to Journal."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- H1 Swing High（深紅實線）
#property indicator_label1  "H1 Swing High"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDarkRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- H1 Swing Low（深藍實線）
#property indicator_label2  "H1 Swing Low"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrMidnightBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#include <Toolbox/SwingHighLow.mqh>

//--- Inputs
input int  InpSwingBars = 30;    // H1 lookback K線數 / H1 lookback bars
input bool InpPrintLog  = true;  // 輸出至 Journal / Print to Journal

//--- Buffers
double Buffer_High[];
double Buffer_Low[];

//+------------------------------------------------------------------+
int OnInit()
{
    SetIndexBuffer(0, Buffer_High, INDICATOR_DATA);
    SetIndexBuffer(1, Buffer_Low,  INDICATOR_DATA);

    ArraySetAsSeries(Buffer_High, true);
    ArraySetAsSeries(Buffer_Low,  true);

    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("SwingHL_H1(%d)", InpSwingBars));

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
    if(rates_total < InpSwingBars + 2)
        return 0;

    //--- 計算起點
    int limit = (prev_calculated == 0) ? rates_total - InpSwingBars - 1
                                       : rates_total - prev_calculated;

    for(int i = limit; i >= 0; i--)
    {
        int shift = i + 1;

        Buffer_High[i] = GetSwingHigh(_Symbol, PERIOD_H1, InpSwingBars, shift);
        Buffer_Low[i]  = GetSwingLow (_Symbol, PERIOD_H1, InpSwingBars, shift);
    }

    //--- 只喺新 bar 印 Journal
    if(InpPrintLog && prev_calculated != rates_total)
    {
        SwingResult h1  = GetSwing(_Symbol, PERIOD_H1, InpSwingBars, 1);
        double      pip = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;

        PrintFormat("=== SwingHighLow 波段高低位 H1 | %s | %s ===",
                    _Symbol,
                    TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));

        PrintFormat("  H1(%d bars) | 波段高 SwingHigh: %.5f (bar %d)  波段低 SwingLow: %.5f (bar %d)  幅度 Range: %.1f pips",
                    InpSwingBars,
                    h1.high, h1.high_shift,
                    h1.low,  h1.low_shift,
                    (h1.high - h1.low) / pip);
    }

    return rates_total;
}
