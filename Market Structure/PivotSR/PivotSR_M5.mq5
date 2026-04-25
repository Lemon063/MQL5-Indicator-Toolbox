//+------------------------------------------------------------------+
//|  PivotSR_M5.mq5                                                  |
//|  MQL5 Indicator Toolbox                                          |
//|  視覺圖表 indicator — attach 到 M5 chart 驗證邏輯                |
//|  M5 mode：距離優先                                                |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "2.10"
#property description "M5 Pivot High/Low + S/R zones. Distance priority. Attach to M5 chart."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Pivot High（紫紅色箭咀向下）
#property indicator_label1  "M5 Pivot High"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrMediumVioletRed
#property indicator_width1  2

//--- Pivot Low（藍色箭咀向上）
#property indicator_label2  "M5 Pivot Low"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrDodgerBlue
#property indicator_width2  2

#include <Toolbox/PivotSR.mqh>

//--- Inputs
input bool   InpIsBuy        = true;   // true = BUY 方向，false = SELL 方向
input int    InpPivotN       = 5;      // Pivot 左右確認 bars（M5 建議 5-8）
input int    InpPivotLook    = 50;     // Pivot 回望 bars
input int    InpSRLookback   = 100;    // S/R 回望 bars
input double InpSRZonePips   = 10.0;   // S/R 格距 pips
input int    InpSRMinCount   = 4;      // S/R 最低出現次數
input double InpSRTolPips    = 10.0;   // Pivot-SR 配對容忍度 pips
input double InpMinRangePips = 10.0;   // M5 最小波段 pips
input bool   InpPrintLog     = true;   // 輸出至 Journal

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
        StringFormat("PivotSR_M5(%s,N=%d,Dist_Priority)",
                     InpIsBuy ? "BUY" : "SELL", InpPivotN));

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
        if(IsPivotHigh(_Symbol, PERIOD_M5, i, InpPivotN))
            Buffer_PivotHigh[i] = iHigh(_Symbol, PERIOD_M5, i);
        if(IsPivotLow(_Symbol, PERIOD_M5, i, InpPivotN))
            Buffer_PivotLow[i] = iLow(_Symbol, PERIOD_M5, i);
    }

    if(InpPrintLog && prev_calculated != rates_total)
    {
        //--- ANCHOR_M5：距離優先，加入 InpIsBuy 方向性驗證
        AnchorResult anchor = GetAnchorPoints(
            _Symbol, PERIOD_M5, ANCHOR_M5,
            InpIsBuy,        // ← v2.10：傳入方向
            InpPivotN, InpPivotLook,
            InpSRLookback, InpSRZonePips,
            InpSRMinCount, InpSRTolPips,
            InpMinRangePips, 1);

        double pip = GetPipSize(_Symbol);

        PrintFormat("=== PivotSR M5 | %s | %s | %s ===",
                    _Symbol,
                    InpIsBuy ? "BUY" : "SELL",
                    TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));

        if(anchor.valid)
            PrintFormat("  錨點 Anchors | 高 Pivot High: %.5f (bar %d, S/R強度:%d)  低 Pivot Low: %.5f (bar %d, S/R強度:%d)  幅度: %.1f pips%s",
                        anchor.high, anchor.high_bar, anchor.high_sr,
                        anchor.low,  anchor.low_bar,  anchor.low_sr,
                        (anchor.high - anchor.low) / pip,
                        anchor.range_ok ? "" : " ⚠️ range 太細");
        else
            Print("  錨點搵唔到（或方向性驗證失敗）— 調整 Pivot / S/R 參數或切換 BUY/SELL");
    }

    return rates_total;
}
