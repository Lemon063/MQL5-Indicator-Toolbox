//+------------------------------------------------------------------+
//|  PivotSR_M5.mq5                                                  |
//|  MQL5 Indicator Toolbox                                          |
//|  視覺圖表 indicator — attach 到 M5 chart 驗證邏輯                |
//|  顯示 M5 Pivot High/Low + S/R 密集區                             |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "1.00"
#property description "M5 Pivot High/Low + S/R zones. Attach to M5 chart."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Pivot High（紫紅色箭咀向下）
#property indicator_label1  "Pivot High"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrMediumVioletRed
#property indicator_width1  2

//--- Pivot Low（藍色箭咀向上）
#property indicator_label2  "Pivot Low"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrDodgerBlue
#property indicator_width2  2

#include <Toolbox/PivotSR.mqh>

//--- Inputs
input int    InpPivotN      = 3;     // Pivot 左右確認 bars
input int    InpPivotLook   = 50;    // Pivot 回望 bars
input int    InpSRLookback  = 100;   // S/R 回望 bars
input double InpSRZonePips  = 10.0;  // S/R 格距 pips
input int    InpSRMinCount  = 4;     // S/R 最低出現次數
input double InpSRTolPips   = 10.0;  // Pivot-SR 配對容忍度 pips
input bool   InpPrintLog    = true;  // 輸出至 Journal

//--- Buffers
double Buffer_PivotHigh[];
double Buffer_PivotLow[];

//+------------------------------------------------------------------+
int OnInit()
{
    SetIndexBuffer(0, Buffer_PivotHigh, INDICATOR_DATA);
    SetIndexBuffer(1, Buffer_PivotLow,  INDICATOR_DATA);

    ArraySetAsSeries(Buffer_PivotHigh, true);
    ArraySetAsSeries(Buffer_PivotLow,  true);

    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

    //--- 箭咀形狀：向下 = 234，向上 = 233
    PlotIndexSetInteger(0, PLOT_ARROW, 234);
    PlotIndexSetInteger(1, PLOT_ARROW, 233);

    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("PivotSR_M5(N=%d)", InpPivotN));

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
    if(rates_total < InpPivotLook + InpPivotN * 2 + 2)
        return 0;

    int limit = (prev_calculated == 0) ? rates_total - InpPivotN - 1
                                       : rates_total - prev_calculated;

    //--- 初始化 buffer
    for(int i = limit; i >= 0; i--)
    {
        Buffer_PivotHigh[i] = EMPTY_VALUE;
        Buffer_PivotLow[i]  = EMPTY_VALUE;
    }

    //--- 標記所有 Pivot High/Low
    for(int i = limit; i >= InpPivotN; i--)
    {
        int shift = i;
        if(IsPivotHigh(_Symbol, PERIOD_M5, shift, InpPivotN))
            Buffer_PivotHigh[i] = iHigh(_Symbol, PERIOD_M5, shift);

        if(IsPivotLow(_Symbol, PERIOD_M5, shift, InpPivotN))
            Buffer_PivotLow[i] = iLow(_Symbol, PERIOD_M5, shift);
    }

    //--- 只喺新 bar 印 Journal
    if(InpPrintLog && prev_calculated != rates_total)
    {
        AnchorResult anchor = GetAnchorPoints(
            _Symbol, PERIOD_M5,
            InpPivotN, InpPivotLook,
            InpSRLookback, InpSRZonePips,
            InpSRMinCount, InpSRTolPips, 1);

        double pip = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;

        PrintFormat("=== PivotSR M5 | %s | %s ===",
                    _Symbol,
                    TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));

        if(anchor.valid)
        {
            PrintFormat("  錨點 Anchors | 高 Pivot High: %.5f (bar %d, S/R強度:%d)  低 Pivot Low: %.5f (bar %d, S/R強度:%d)",
                        anchor.high, anchor.high_bar, anchor.high_sr,
                        anchor.low,  anchor.low_bar,  anchor.low_sr);
            PrintFormat("  幅度 Range   | %.1f pips",
                        (anchor.high - anchor.low) / pip);
        }
        else
            Print("  錨點搵唔到有效 Pivot — 可能需要調整參數");
    }

    return rates_total;
}
