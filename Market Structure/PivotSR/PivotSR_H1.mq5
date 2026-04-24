//+------------------------------------------------------------------+
//|  PivotSR_H1.mq5                                                  |
//|  MQL5 Indicator Toolbox                                          |
//|  視覺圖表 indicator — attach 到 H1 chart 驗證邏輯                |
//|  H1 mode：S/R 強度優先                                            |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "2.00"
#property description "H1 Pivot High/Low + S/R zones. Strength priority. Attach to H1 chart."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Pivot High（白色箭咀向下）
#property indicator_label1  "H1 Pivot High"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrWhite
#property indicator_width1  2

//--- Pivot Low（淺藍箭咀向上）
#property indicator_label2  "H1 Pivot Low"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrSkyBlue
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
    PlotIndexSetInteger(0, PLOT_ARROW, 234);
    PlotIndexSetInteger(1, PLOT_ARROW, 233);

    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("PivotSR_H1(N=%d,SR_Priority)", InpPivotN));

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

    for(int i = limit; i >= 0; i--)
    {
        Buffer_PivotHigh[i] = EMPTY_VALUE;
        Buffer_PivotLow[i]  = EMPTY_VALUE;
    }

    for(int i = limit; i >= InpPivotN; i--)
    {
        if(IsPivotHigh(_Symbol, PERIOD_H1, i, InpPivotN))
            Buffer_PivotHigh[i] = iHigh(_Symbol, PERIOD_H1, i);
        if(IsPivotLow(_Symbol, PERIOD_H1, i, InpPivotN))
            Buffer_PivotLow[i] = iLow(_Symbol, PERIOD_H1, i);
    }

    if(InpPrintLog && prev_calculated != rates_total)
    {
        //--- ANCHOR_H1：S/R 強度優先
        AnchorResult anchor = GetAnchorPoints(
            _Symbol, PERIOD_H1, ANCHOR_H1,
            InpPivotN, InpPivotLook,
            InpSRLookback, InpSRZonePips,
            InpSRMinCount, InpSRTolPips,
            0.0, 1);

        double pip = GetPipSize(_Symbol);

        PrintFormat("=== PivotSR H1 | %s | %s ===",
                    _Symbol,
                    TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));

        if(anchor.valid)
            PrintFormat("  錨點 Anchors | 高 Pivot High: %.5f (bar %d, S/R強度:%d)  低 Pivot Low: %.5f (bar %d, S/R強度:%d)  幅度: %.1f pips",
                        anchor.high, anchor.high_bar, anchor.high_sr,
                        anchor.low,  anchor.low_bar,  anchor.low_sr,
                        (anchor.high - anchor.low) / pip);
        else
            Print("  錨點搵唔到 — 調整 Pivot 或 S/R 參數");
    }

    return rates_total;
}
