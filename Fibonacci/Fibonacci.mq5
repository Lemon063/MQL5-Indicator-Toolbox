//+------------------------------------------------------------------+
//|  Fibonacci.mq5                                                   |
//|  MQL5 Indicator Toolbox                                          |
//|  視覺圖表 indicator — attach 到 chart 驗證邏輯                    |
//|  畫所有 Fib levels 水平線 + Journal log                          |
//|  依賴 Depends on: SwingHighLow.mqh（via Fibonacci.mqh）          |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "1.10"
#property description "Draws Fib retracement + extension levels. Prints values to Journal."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Toolbox/Fibonacci.mqh>

//--- Inputs
input int    InpSwingBars      = 20;    // 波段回望 K線數 / Swing lookback bars
input bool   InpIsBuy          = true;  // true = 做多方向，false = 做空方向
input double InpAtrMult        = 0.20;  // Fib 接近閾值乘數（× ATR）/ Proximity multiplier
input int    InpAtrPeriod      = 14;    // ATR 週期 / ATR period
input bool   InpPrintLog       = true;  // 輸出至 Journal / Print to Journal
input bool   InpShowExtensions = true;  // 顯示延伸位 1.618 / 2.618 / 3.618

//--- Line object name prefix
string PREFIX = "FIB_";

//--- ATR handle（OnInit 建立，OnDeinit 釋放）
int g_atrHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
void DrawFibLine(string name, double price, color clr,
                 ENUM_LINE_STYLE style, int width, string label)
{
    string obj_name = PREFIX + name;
    if(ObjectFind(0, obj_name) < 0)
        ObjectCreate(0, obj_name, OBJ_HLINE, 0, 0, price);

    ObjectSetDouble(0, obj_name, OBJPROP_PRICE, price);
    ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, obj_name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, width);
    ObjectSetString(0, obj_name, OBJPROP_TOOLTIP, label);
    ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
void DeleteFibLines()
{
    int total = ObjectsTotal(0, 0, OBJ_HLINE);
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, 0, OBJ_HLINE);
        if(StringFind(name, PREFIX) == 0)
            ObjectDelete(0, name);
    }
}

//+------------------------------------------------------------------+
int OnInit()
{
    //--- 建立 ATR handle 一次，保留至 OnDeinit
    g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpAtrPeriod);
    if(g_atrHandle == INVALID_HANDLE)
    {
        Print("錯誤 ERROR: iATR handle 建立失敗");
        return INIT_FAILED;
    }

    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("Fib(%d,%s)", InpSwingBars, InpIsBuy ? "BUY" : "SELL"));

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    DeleteFibLines();

    //--- 釋放 ATR handle
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
    if(rates_total < InpSwingBars + 2)
        return 0;

    //--- 只喺新 bar 重新計算
    if(prev_calculated == rates_total)
        return rates_total;

    //--- 取 Fib levels（用 PERIOD_CURRENT 跟 chart TF）
    FibLevels f = CalcFibAuto(_Symbol, PERIOD_CURRENT, InpSwingBars, InpIsBuy, 1);

    //--- 取 ATR（用已建立嘅 handle，唔重複建立）
    double atr_buf[];
    ArraySetAsSeries(atr_buf, true);
    double atr = 0;
    if(CopyBuffer(g_atrHandle, 0, 1, 1, atr_buf) > 0)
        atr = atr_buf[0];

    double threshold = atr * InpAtrMult;
    double pip       = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;

    //--- 畫回撤線
    DrawFibLine("236",  f.fib_236, clrGold,        STYLE_DASH,  1, "Fib 0.236");
    DrawFibLine("382",  f.fib_382, clrOrange,       STYLE_DASH,  1, "Fib 0.382");
    DrawFibLine("500",  f.fib_500, clrDarkOrange,   STYLE_SOLID, 1, "Fib 0.500");
    DrawFibLine("618",  f.fib_618, clrOrangeRed,    STYLE_SOLID, 2, "Fib 0.618");
    DrawFibLine("786",  f.fib_786, clrRed,          STYLE_SOLID, 1, "Fib 0.786");

    //--- 畫錨點線
    DrawFibLine("SwingHigh", f.swing_high, clrDarkRed,  STYLE_DOT, 1, "Swing High (1.000)");
    DrawFibLine("SwingLow",  f.swing_low,  clrDarkBlue, STYLE_DOT, 1, "Swing Low  (0.000)");

    //--- 畫延伸線
    if(InpShowExtensions)
    {
        DrawFibLine("1618", f.fib_1618, clrMediumPurple, STYLE_DASH,  1, "Fib 1.618");
        DrawFibLine("2618", f.fib_2618, clrPurple,       STYLE_DASH,  1, "Fib 2.618");
        DrawFibLine("3618", f.fib_3618, clrDarkViolet,   STYLE_SOLID, 2, "Fib 3.618 (Exhaustion)");
    }

    ChartRedraw(0);

    //--- Journal print
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

        PrintFormat("  錨點 Anchors    | 波段高: %.5f  波段低: %.5f  幅度 Range: %.1f pips",
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
