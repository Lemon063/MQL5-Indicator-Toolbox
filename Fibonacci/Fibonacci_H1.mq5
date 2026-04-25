//+------------------------------------------------------------------+
//|  Fibonacci_H1.mq5                                                |
//|  MQL5 Indicator Toolbox                                          |
//|  H1 mode：S/R 強度優先 + 波段完整性驗證，唔鎖定                   |
//|  Attach 到 H1 chart                                              |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "1.10"
#property description "H1 Fib levels via PivotSR. Representative 14-day swing + OBJ_FIBO anchors."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Toolbox/Fibonacci.mqh>

//--- Inputs: Pivot
input int    InpPivotN         = 8;     // Pivot 左右確認 bars
input int    InpPivotLook      = 336;   // Pivot 回望 bars（14日）

//--- Inputs: S/R
input int    InpSRLookback     = 100;   // S/R 回望 bars
input double InpSRZonePips     = 10.0;  // S/R 格距 pips
input int    InpSRMinCount     = 4;     // S/R 最低出現次數
input double InpSRTolPips      = 10.0;  // Pivot-SR 配對容忍度 pips

//--- Inputs: Fib
input bool   InpIsBuy          = true;  // true = BUY，false = SELL
input bool   InpShowExtensions = true;
input double InpAtrMult        = 0.20;
input int    InpAtrPeriod      = 14;
input int    InpLineLookback   = 100;   // 已保留兼容；OBJ_FIBO 會用真實 anchor time

//--- Inputs: Display
input bool   InpPrintLog       = true;

//--- Globals
const string FIB_OBJECT   = "FIB_H1_MAIN";
const string LEGACY_LINE  = "FIB_H1_LINE_";
const string LEGACY_LABEL = "FIB_H1_LBL_";
int g_atrHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
int FibLevelCount()
{
    return InpShowExtensions ? 10 : 7;
}

//+------------------------------------------------------------------+
double FibLevelValueByIndex(int index)
{
    double values[10] = {0.000, 0.236, 0.382, 0.500, 0.618,
                         0.786, 1.000, 1.618, 2.618, 3.618};
    return values[index];
}

//+------------------------------------------------------------------+
string FibLevelTextByIndex(int index)
{
    string labels[10] = {"0.000", "0.236", "0.382", "0.500", "0.618",
                         "0.786", "1.000", "1.618", "2.618", "3.618 Exhaustion"};
    return labels[index];
}

//+------------------------------------------------------------------+
color FibLevelColorByIndex(int index)
{
    color colors[10] = {clrSkyBlue, clrGold, clrOrange, clrDarkOrange, clrOrangeRed,
                        clrRed, clrWhite, clrMediumPurple, clrPurple, clrDarkViolet};
    return colors[index];
}

//+------------------------------------------------------------------+
ENUM_LINE_STYLE FibLevelStyleByIndex(int index)
{
    ENUM_LINE_STYLE styles[10] = {STYLE_DOT, STYLE_DASH, STYLE_DASH, STYLE_SOLID, STYLE_SOLID,
                                  STYLE_SOLID, STYLE_DOT, STYLE_DASH, STYLE_DASH, STYLE_SOLID};
    return styles[index];
}

//+------------------------------------------------------------------+
int FibLevelWidthByIndex(int index)
{
    int widths[10] = {1, 1, 1, 1, 2, 1, 1, 1, 1, 2};
    return widths[index];
}

//+------------------------------------------------------------------+
bool DrawFibObject(const AnchorResult &anchor, const FibLevels &f)
{
    datetime t0 = f.is_buy ? iTime(_Symbol, PERIOD_CURRENT, anchor.low_bar)
                           : iTime(_Symbol, PERIOD_CURRENT, anchor.high_bar);
    datetime t1 = f.is_buy ? iTime(_Symbol, PERIOD_CURRENT, anchor.high_bar)
                           : iTime(_Symbol, PERIOD_CURRENT, anchor.low_bar);
    double   p0 = f.is_buy ? f.swing_low  : f.swing_high;
    double   p1 = f.is_buy ? f.swing_high : f.swing_low;

    if(t0 == 0 || t1 == 0)
        return false;

    if(ObjectFind(0, FIB_OBJECT) < 0)
    {
        if(!ObjectCreate(0, FIB_OBJECT, OBJ_FIBO, 0, t0, p0, t1, p1))
            return false;
    }

    ObjectSetInteger(0, FIB_OBJECT, OBJPROP_TIME,  0, t0);
    ObjectSetInteger(0, FIB_OBJECT, OBJPROP_TIME,  1, t1);
    ObjectSetDouble(0,  FIB_OBJECT, OBJPROP_PRICE, 0, p0);
    ObjectSetDouble(0,  FIB_OBJECT, OBJPROP_PRICE, 1, p1);
    ObjectSetInteger(0, FIB_OBJECT, OBJPROP_LEVELS, FibLevelCount());
    ObjectSetInteger(0, FIB_OBJECT, OBJPROP_BACK, true);
    ObjectSetInteger(0, FIB_OBJECT, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, FIB_OBJECT, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, FIB_OBJECT, OBJPROP_RAY_RIGHT, false);
    ObjectSetInteger(0, FIB_OBJECT, OBJPROP_HIDDEN, false);
    ObjectSetString(0,  FIB_OBJECT, OBJPROP_TOOLTIP,
                     StringFormat("Representative 14-day Fib | score=%.2f | span=%d bars | range=%.1f pips",
                                  anchor.score, anchor.span_bars, anchor.range_pips));

    for(int i = 0; i < FibLevelCount(); i++)
    {
        ObjectSetDouble(0,  FIB_OBJECT, OBJPROP_LEVELVALUE, i, FibLevelValueByIndex(i));
        ObjectSetString(0,  FIB_OBJECT, OBJPROP_LEVELTEXT,  i, FibLevelTextByIndex(i));
        ObjectSetInteger(0, FIB_OBJECT, OBJPROP_LEVELCOLOR, i, FibLevelColorByIndex(i));
        ObjectSetInteger(0, FIB_OBJECT, OBJPROP_LEVELSTYLE, i, FibLevelStyleByIndex(i));
        ObjectSetInteger(0, FIB_OBJECT, OBJPROP_LEVELWIDTH, i, FibLevelWidthByIndex(i));
    }

    ChartRedraw(0);
    return true;
}

//+------------------------------------------------------------------+
void DeleteFibObjects()
{
    ObjectDelete(0, FIB_OBJECT);

    int total = ObjectsTotal(0, 0, OBJ_TREND);
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, 0, OBJ_TREND);
        if(StringFind(name, LEGACY_LINE) == 0)
            ObjectDelete(0, name);
    }

    total = ObjectsTotal(0, 0, OBJ_TEXT);
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, 0, OBJ_TEXT);
        if(StringFind(name, LEGACY_LABEL) == 0)
            ObjectDelete(0, name);
    }
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
        StringFormat("Fib_H1(%s,N=%d,L=%d)", InpIsBuy ? "BUY" : "SELL", InpPivotN, InpPivotLook));

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

    ArraySetAsSeries(time, true);
    static datetime last_bar_time = 0;
    if(time[0] == last_bar_time)
        return rates_total;
    last_bar_time = time[0];

    double atr_buf[];
    ArraySetAsSeries(atr_buf, true);
    double atr = 0.0;
    if(CopyBuffer(g_atrHandle, 0, 1, 1, atr_buf) > 0)
        atr = atr_buf[0];

    double threshold = atr * InpAtrMult;
    double pip       = GetPipSize(_Symbol);

    AnchorResult anchor = GetAnchorPoints(
        _Symbol, PERIOD_CURRENT, ANCHOR_H1, InpIsBuy,
        InpPivotN, InpPivotLook,
        InpSRLookback, InpSRZonePips,
        InpSRMinCount, InpSRTolPips,
        0.0, 1, InpPrintLog);

    if(!anchor.valid)
    {
        DeleteFibObjects();
        if(InpPrintLog)
            Print("  錨點搵唔到 — 調整 Pivot / S/R 參數或切換 BUY/SELL");
        return rates_total;
    }

    FibLevels f = CalcFibLevels(anchor.high, anchor.low, InpIsBuy);
    if(!DrawFibObject(anchor, f))
    {
        if(InpPrintLog)
            Print("  OBJ_FIBO 建立/更新失敗");
        return rates_total;
    }

    if(InpPrintLog)
    {
        SRResult sr = CalcSRZones(_Symbol, PERIOD_CURRENT,
                                  InpSRLookback, InpSRZonePips,
                                  InpSRMinCount, 1);
        double tol           = InpSRTolPips * pip;
        int    ol            = 0;
        double sc            = CalcFibSRScore(f, sr, tol, ol, anchor.range_ok);
        double current_price = iClose(_Symbol, PERIOD_CURRENT, 0);
        datetime high_time   = iTime(_Symbol, PERIOD_CURRENT, anchor.high_bar);
        datetime low_time    = iTime(_Symbol, PERIOD_CURRENT, anchor.low_bar);

        PrintFormat("=== Fibonacci H1 | %s | %s | %s ===",
                    _Symbol,
                    InpIsBuy ? "BUY" : "SELL",
                    TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));

        PrintFormat("  窗口 Window  | lookback: %d bars (~%.1f days)  pivotN: %d",
                    InpPivotLook, (double)InpPivotLook / 24.0, InpPivotN);

        PrintFormat("  錨點 Anchors | 波段高 1.000: %.5f (bar %d @ %s)  波段低 0.000: %.5f (bar %d @ %s)  幅度: %.1f pips",
                    f.swing_high, anchor.high_bar, TimeToString(high_time, TIME_DATE|TIME_MINUTES),
                    f.swing_low,  anchor.low_bar,  TimeToString(low_time,  TIME_DATE|TIME_MINUTES),
                    f.range / pip);

        PrintFormat("  代表性評分 Rep | anchor_score: %.2f  span: %d bars  range: %.1f pips  range_ok: %s",
                    anchor.score, anchor.span_bars, anchor.range_pips,
                    anchor.range_ok ? "true" : "false");

        PrintFormat("  回撤 Retrace | 0.236: %.5f  0.382: %.5f  0.500: %.5f  0.618: %.5f  0.786: %.5f",
                    f.fib_236, f.fib_382, f.fib_500, f.fib_618, f.fib_786);

        if(InpShowExtensions)
            PrintFormat("  延伸 Ext     | 1.618: %.5f  2.618: %.5f  3.618: %.5f（耗盡位）",
                        f.fib_1618, f.fib_2618, f.fib_3618);

        PrintFormat("  重疊 Overlap | %d  Fib-SR 分數 Score: %.1f", ol, sc);
        PrintFormat("  ATR 接近閾值 | ATR: %.5f  閾值: %.5f (%.1f pips)",
                    atr, threshold, threshold / pip);

        string near_label;
        double near_price;
        if(IsFibNear(current_price, f, threshold, near_label, near_price))
            PrintFormat("  >>> 價格接近 Fib %s (%.5f) — 當前價: %.5f  距離: %.1f pips",
                        near_label, near_price, current_price,
                        MathAbs(current_price - near_price) / pip);
        else
            PrintFormat("  當前價 %.5f — 未接近任何 Fib level", current_price);
    }

    return rates_total;
}
