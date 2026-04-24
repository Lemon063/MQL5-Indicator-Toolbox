//+------------------------------------------------------------------+
//|  Fibonacci.mq5                                                   |
//|  MQL5 Indicator Toolbox                                          |
//|  視覺圖表 indicator — attach 到 chart 驗證邏輯                    |
//|  畫所有 Fib levels 水平線 + label + tooltip + Journal log         |
//|  依賴 Depends on: PivotSR.mqh → SupportResistance.mqh           |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "2.00"
#property description "Fib levels via Pivot+SR anchors. Labels + tooltips + Journal."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Toolbox/Fibonacci.mqh>

//--- Inputs: Pivot
input int    InpPivotN         = 3;     // Pivot 左右確認 bars
input int    InpPivotLook      = 50;    // Pivot 回望 bars

//--- Inputs: S/R
input int    InpSRLookback     = 100;   // S/R 回望 bars
input double InpSRZonePips     = 10.0;  // S/R 格距 pips
input int    InpSRMinCount     = 4;     // S/R 最低出現次數
input double InpSRTolPips      = 10.0;  // Pivot-SR 配對容忍度 pips

//--- Inputs: Fib
input bool   InpIsBuy          = true;  // true = 做多，false = 做空
input bool   InpShowExtensions = true;  // 顯示延伸位
input double InpAtrMult        = 0.20;  // Fib 接近閾值乘數（× ATR）
input int    InpAtrPeriod      = 14;    // ATR 週期

//--- Inputs: Display
input bool   InpPrintLog       = true;  // 輸出至 Journal

//--- Prefixes
string PREFIX       = "FIB_LINE_";
string PREFIX_LABEL = "FIB_LBL_";

//--- ATR handle
int g_atrHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
void DrawFibLine(string name, double price, color clr,
                 ENUM_LINE_STYLE style, int width, string tooltip)
{
    string obj = PREFIX + name;
    if(ObjectFind(0, obj) < 0)
        ObjectCreate(0, obj, OBJ_HLINE, 0, 0, price);

    ObjectSetDouble(0, obj, OBJPROP_PRICE,        price);
    ObjectSetInteger(0, obj, OBJPROP_COLOR,       clr);
    ObjectSetInteger(0, obj, OBJPROP_STYLE,       style);
    ObjectSetInteger(0, obj, OBJPROP_WIDTH,       width);
    ObjectSetString(0, obj, OBJPROP_TOOLTIP,      tooltip);
    ObjectSetInteger(0, obj, OBJPROP_SELECTABLE,  false);
    ObjectSetInteger(0, obj, OBJPROP_BACK,        true);
}

//+------------------------------------------------------------------+
void DrawFibLabel(string name, double price, color clr, string label_text)
{
    string obj     = PREFIX_LABEL + name;
    int    visible = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
    int    first   = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
    datetime t     = iTime(_Symbol, PERIOD_CURRENT, MathMax(first - visible + 2, 0));

    if(ObjectFind(0, obj) < 0)
        ObjectCreate(0, obj, OBJ_TEXT, 0, t, price);

    ObjectSetInteger(0, obj, OBJPROP_TIME,        t);
    ObjectSetDouble(0, obj, OBJPROP_PRICE,        price);
    ObjectSetString(0, obj, OBJPROP_TEXT,         label_text);
    ObjectSetInteger(0, obj, OBJPROP_COLOR,       clr);
    ObjectSetInteger(0, obj, OBJPROP_FONTSIZE,    8);
    ObjectSetString(0, obj, OBJPROP_FONT,         "Arial");
    ObjectSetInteger(0, obj, OBJPROP_SELECTABLE,  false);
    ObjectSetInteger(0, obj, OBJPROP_BACK,        false);
}

//+------------------------------------------------------------------+
void DeleteFibObjects()
{
    int total = ObjectsTotal(0, 0, OBJ_HLINE);
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, 0, OBJ_HLINE);
        if(StringFind(name, PREFIX) == 0)
            ObjectDelete(0, name);
    }
    total = ObjectsTotal(0, 0, OBJ_TEXT);
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, 0, OBJ_TEXT);
        if(StringFind(name, PREFIX_LABEL) == 0)
            ObjectDelete(0, name);
    }
}

//+------------------------------------------------------------------+
void DrawFibSet(string name, double price, color clr,
                ENUM_LINE_STYLE style, int width, string level_str)
{
    string text = level_str + "  " + DoubleToString(price, 5);
    DrawFibLine(name, price, clr, style, width, text);
    DrawFibLabel(name, price, clr, text);
}

//+------------------------------------------------------------------+
int OnInit()
{
    g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpAtrPeriod);
    if(g_atrHandle == INVALID_HANDLE)
    {
        Print("錯誤 ERROR: iATR handle 建立失敗");
        return INIT_FAILED;
    }

    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("Fib_PivotSR(%d,%s)", InpPivotN, InpIsBuy ? "BUY" : "SELL"));

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    DeleteFibObjects();
    if(g_atrHandle != INVALID_HANDLE)
    {
        IndicatorRelease(g_atrHandle);
        g_atrHandle = INVALID_HANDLE;
    }
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

    if(prev_calculated == rates_total)
        return rates_total;

    //--- Fib levels via PivotSR
    FibLevels f = CalcFibAuto(
        _Symbol, PERIOD_CURRENT, InpIsBuy,
        InpPivotN, InpPivotLook,
        InpSRLookback, InpSRZonePips,
        InpSRMinCount, InpSRTolPips, 1);

    if(f.range == 0)
    {
        if(InpPrintLog)
            Print("  錨點搵唔到 — 可能需要調整 Pivot 或 S/R 參數");
        return rates_total;
    }

    //--- ATR for proximity
    double atr_buf[];
    ArraySetAsSeries(atr_buf, true);
    double atr = 0;
    if(CopyBuffer(g_atrHandle, 0, 1, 1, atr_buf) > 0)
        atr = atr_buf[0];

    double threshold = atr * InpAtrMult;
    double pip       = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;

    //--- 畫線 + label
    DrawFibSet("SwingHigh", f.swing_high, clrWhite,       STYLE_DOT,  1, "1.000");
    DrawFibSet("SwingLow",  f.swing_low,  clrSkyBlue,      STYLE_DOT,  1, "0.000");
    DrawFibSet("236",  f.fib_236,  clrGold,        STYLE_DASH,  1, "0.236");
    DrawFibSet("382",  f.fib_382,  clrOrange,      STYLE_DASH,  1, "0.382");
    DrawFibSet("500",  f.fib_500,  clrDarkOrange,  STYLE_SOLID, 1, "0.500");
    DrawFibSet("618",  f.fib_618,  clrOrangeRed,   STYLE_SOLID, 2, "0.618");
    DrawFibSet("786",  f.fib_786,  clrRed,         STYLE_SOLID, 1, "0.786");

    if(InpShowExtensions)
    {
        DrawFibSet("1618", f.fib_1618, clrMediumPurple, STYLE_DASH,  1, "1.618");
        DrawFibSet("2618", f.fib_2618, clrPurple,       STYLE_DASH,  1, "2.618");
        DrawFibSet("3618", f.fib_3618, clrDarkViolet,   STYLE_SOLID, 2, "3.618 Exhaustion");
    }

    ChartRedraw(0);

    //--- Journal
    if(InpPrintLog)
    {
        double current_price = close[rates_total - 1];
        string near_label;
        double near_price;
        bool   is_near = IsFibNear(current_price, f, threshold, near_label, near_price);

        PrintFormat("=== Fibonacci 費波那契 | %s | %s | %s ===",
                    _Symbol,
                    InpIsBuy ? "BUY" : "SELL",
                    TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));

        PrintFormat("  錨點 Anchors    | 波段高 1.000: %.5f  波段低 0.000: %.5f  幅度 Range: %.1f pips",
                    f.swing_high, f.swing_low, f.range / pip);

        PrintFormat("  回撤 Retrace    | 0.236: %.5f  0.382: %.5f  0.500: %.5f  0.618: %.5f  0.786: %.5f",
                    f.fib_236, f.fib_382, f.fib_500, f.fib_618, f.fib_786);

        if(InpShowExtensions)
            PrintFormat("  延伸 Extensions | 1.618: %.5f  2.618: %.5f  3.618: %.5f（耗盡位 Exhaustion）",
                        f.fib_1618, f.fib_2618, f.fib_3618);

        PrintFormat("  ATR 接近閾值    | ATR: %.5f  閾值 Threshold: %.5f (%.1f pips)",
                    atr, threshold, threshold / pip);

        if(is_near)
            PrintFormat("  >>> 價格接近 Fib %s (%.5f) — 當前價 Current: %.5f  距離 Dist: %.1f pips",
                        near_label, near_price, current_price,
                        MathAbs(current_price - near_price) / pip);
        else
            PrintFormat("  當前價 %.5f — 未接近任何 Fib level", current_price);
    }

    return rates_total;
}
