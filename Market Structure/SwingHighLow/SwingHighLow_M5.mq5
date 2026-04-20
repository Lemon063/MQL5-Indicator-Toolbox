//+------------------------------------------------------------------+
//|  SwingHighLow_M5.mq5                                             |
//|  MQL5 Indicator Toolbox                                          |
//|  視覺圖表 indicator — attach 到 M5 chart 驗證邏輯                |
//|  只顯示 M5 Swing High / Low                                      |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "1.10"
#property description "M5 Swing High/Low. Attach to M5 chart. Prints to Journal."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- M5 Swing High（紅色虛線）
#property indicator_label1  "M5 Swing High"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumVioletRed
#property indicator_style1  STYLE_DASH
#property indicator_width1  1

//--- M5 Swing Low（藍色虛線）
#property indicator_label2  "M5 Swing Low"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_DASH
#property indicator_width2  1

#include <Toolbox/SwingHighLow.mqh>

//--- Inputs
input int  InpSwingBars = 20;    // M5 lookback K線數 / M5 lookback bars
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
        StringFormat("SwingHL_M5(%d)", InpSwingBars));

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
    //    prev_calculated == 0 → 第一次計算，由最舊 bar 開始
    //    否則由上次停嘅地方繼續
    int limit = (prev_calculated == 0) ? rates_total - InpSwingBars - 1
                                       : rates_total - prev_calculated;

    for(int i = limit; i >= 0; i--)
    {
        //--- i 係由新到舊嘅 buffer index（AsSeries = true）
        //--- shift = i + 1 確保永遠用已收盤 bar，唔用 bar0
        int shift = i + 1;

        Buffer_High[i] = GetSwingHigh(_Symbol, PERIOD_M5, InpSwingBars, shift);
        Buffer_Low[i]  = GetSwingLow (_Symbol, PERIOD_M5, InpSwingBars, shift);
    }

    //--- 只喺新 bar 印 Journal
    if(InpPrintLog && prev_calculated != rates_total)
    {
        SwingResult m5  = GetSwing(_Symbol, PERIOD_M5, InpSwingBars, 1);
        double      pip = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;

        PrintFormat("=== SwingHighLow 波段高低位 M5 | %s | %s ===",
                    _Symbol,
                    TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));

        PrintFormat("  M5(%d bars) | 波段高 SwingHigh: %.5f (bar %d)  波段低 SwingLow: %.5f (bar %d)  幅度 Range: %.1f pips",
                    InpSwingBars,
                    m5.high, m5.high_shift,
                    m5.low,  m5.low_shift,
                    (m5.high - m5.low) / pip);
    }

    return rates_total;
}
