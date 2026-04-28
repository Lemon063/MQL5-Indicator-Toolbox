//+------------------------------------------------------------------+
//|  Fibonacci_M5.mq5                                                |
//|  MQL5 Indicator Toolbox                                          |
//|  M5 mode：距離優先 + Fib-SR 評分 + 鎖定/解鎖機制                 |
//|  Attach 到 M5 chart                                              |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "1.00"
#property description "M5 Fib levels via PivotSR. Distance priority + lock/unlock."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Toolbox/Fibonacci.mqh>

//--- Inputs: Pivot
input int    InpPivotN       = 5;     // Pivot 左右確認 bars
input int    InpPivotLook    = 96;    // Pivot 回望 bars（8小時）

//--- Inputs: S/R
input int    InpSRLookback   = 100;   // S/R 回望 bars
input double InpSRZonePips   = 10.0;  // S/R 格距 pips
input int    InpSRMinCount   = 4;     // S/R 最低出現次數
input double InpSRTolPips    = 10.0;  // Pivot-SR 配對容忍度 pips

//--- Inputs: Fib
input bool   InpIsBuy        = true;  // true = BUY，false = SELL
input bool   InpShowExtensions = true;
input double InpAtrMult      = 0.20;
input int    InpAtrPeriod    = 14;
input int    InpLineLookback = 100;   // Fib 線往左延伸幾多 bars

//--- Inputs: 鎖定機制
input int    InpMinOverlap   = 3;     // 最少 Fib-SR 重疊數量
input double InpMinScore     = 6.0;   // 最低 Fib-SR 分數
input double InpMinRangePips = 10.0;  // 最小波段 pips

//--- Inputs: Display
input bool   InpPrintLog     = true;

//--- Globals
const string PREFIX       = "FIB_M5_LINE_";
const string PREFIX_LABEL = "FIB_M5_LBL_";
int       g_atrHandle  = INVALID_HANDLE;
FibLevels g_locked_fib;
bool      g_is_locked  = false;
int       g_locked_hbar = 0;
int       g_locked_lbar = 0;

//+------------------------------------------------------------------+
void DrawFibLine(string name, double price, color clr,
                 ENUM_LINE_STYLE style, int width, string tooltip)
{
    string   obj     = PREFIX + name;
    datetime t_end   = iTime(_Symbol, PERIOD_CURRENT, 0);
    datetime t_start = iTime(_Symbol, PERIOD_CURRENT, InpLineLookback);

    if(ObjectFind(0, obj) < 0)
        ObjectCreate(0, obj, OBJ_TREND, 0, t_start, price, t_end, price);

    ObjectSetInteger(0, obj, OBJPROP_TIME,  0, t_start);
    ObjectSetInteger(0, obj, OBJPROP_TIME,  1, t_end);
    ObjectSetDouble(0, obj,  OBJPROP_PRICE, 0, price);
    ObjectSetDouble(0, obj,  OBJPROP_PRICE, 1, price);
    ObjectSetInteger(0, obj, OBJPROP_COLOR,      clr);
    ObjectSetInteger(0, obj, OBJPROP_STYLE,      style);
    ObjectSetInteger(0, obj, OBJPROP_WIDTH,      width);
    ObjectSetString(0, obj,  OBJPROP_TOOLTIP,    tooltip);
    ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, obj, OBJPROP_RAY_RIGHT,  false);
    ObjectSetInteger(0, obj, OBJPROP_BACK,       true);
}

//+------------------------------------------------------------------+
void DrawFibLabel(string name, double price, color clr, string label_text)
{
    string   obj = PREFIX_LABEL + name;
    datetime t   = iTime(_Symbol, PERIOD_CURRENT, 5);

    if(ObjectFind(0, obj) < 0)
        ObjectCreate(0, obj, OBJ_TEXT, 0, t, price);

    ObjectSetInteger(0, obj, OBJPROP_TIME,       t);
    ObjectSetDouble(0, obj,  OBJPROP_PRICE,      price);
    ObjectSetString(0, obj,  OBJPROP_TEXT,       label_text);
    ObjectSetInteger(0, obj, OBJPROP_COLOR,      clr);
    ObjectSetInteger(0, obj, OBJPROP_FONTSIZE,   8);
    ObjectSetString(0, obj,  OBJPROP_FONT,       "Arial");
    ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, obj, OBJPROP_BACK,       false);
}

//+------------------------------------------------------------------+
void DeleteFibObjects()
{
    int total = ObjectsTotal(0, 0, OBJ_TREND);
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, 0, OBJ_TREND);
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
void DrawAllFibLines(const FibLevels &f)
{
    DrawFibSet("SwingHigh", f.swing_high, clrWhite,        STYLE_DOT,   1, "1.000");
    DrawFibSet("SwingLow",  f.swing_low,  clrSkyBlue,      STYLE_DOT,   1, "0.000");
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

    g_is_locked  = false;
    g_locked_hbar = 0;
    g_locked_lbar = 0;

    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("Fib_M5(%s,N=%d)", InpIsBuy ? "BUY" : "SELL", InpPivotN));

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
    double atr = 0;
    if(CopyBuffer(g_atrHandle, 0, 1, 1, atr_buf) > 0)
        atr = atr_buf[0];

    double threshold = atr * InpAtrMult;
    double pip       = GetPipSize(_Symbol);

    SRResult sr  = CalcSRZones(_Symbol, PERIOD_CURRENT,
                                InpSRLookback, InpSRZonePips,
                                InpSRMinCount, 1);
    double   tol = InpSRTolPips * pip;

    //--- 解鎖 check
    if(g_is_locked)
    {
        int    ol_count = 0;
        double ol_score = CalcFibSRScore(g_locked_fib, sr, tol, ol_count, true);

        if(ol_count < InpMinOverlap || ol_score < InpMinScore)
        {
            g_is_locked = false;
            if(InpPrintLog)
                PrintFormat("⚠️ 錨點解鎖 | 重疊:%d 分數:%.1f（門檻 >=%d / %.1f）",
                            ol_count, ol_score, InpMinOverlap, InpMinScore);
        }
    }

    //--- 搵新錨點
    if(!g_is_locked)
    {
        AnchorResult anchor = GetAnchorPoints(
            _Symbol, PERIOD_CURRENT, ANCHOR_M5,
            InpIsBuy,
            InpPivotN, InpPivotLook,
            InpSRLookback, InpSRZonePips,
            InpSRMinCount, InpSRTolPips,
            InpMinRangePips, 1);

        if(anchor.valid)
        {
            FibLevels candidate = CalcFibLevels(anchor.high, anchor.low, InpIsBuy);

            int    cand_count = 0;
            double cand_score = CalcFibSRScore(candidate, sr, tol,
                                               cand_count, anchor.range_ok);

            if(cand_count >= InpMinOverlap && cand_score >= InpMinScore)
            {
                g_locked_fib  = candidate;
                g_is_locked   = true;
                g_locked_hbar = anchor.high_bar;
                g_locked_lbar = anchor.low_bar;

                if(InpPrintLog)
                    PrintFormat("✅ 新錨點鎖定 | High:%.5f (bar %d)  Low:%.5f (bar %d) | 重疊:%d 分數:%.1f",
                                anchor.high, anchor.high_bar,
                                anchor.low,  anchor.low_bar,
                                cand_count, cand_score);
            }
            else if(InpPrintLog)
                PrintFormat("⚠️ 候選錨點分數唔夠 | 重疊:%d 分數:%.1f（需要 >=%d / %.1f）%s",
                            cand_count, cand_score, InpMinOverlap, InpMinScore,
                            anchor.range_ok ? "" : " [range 太細 -3分]");
        }
    }

    //--- 畫線
    if(g_is_locked)
    {
        DrawAllFibLines(g_locked_fib);

        if(InpPrintLog)
        {
            int    lock_ol = 0;
            double lock_sc = CalcFibSRScore(g_locked_fib, sr, tol, lock_ol, true);

            PrintFormat("=== Fibonacci M5 | %s | %s | %s ===",
                        _Symbol,
                        InpIsBuy ? "BUY" : "SELL",
                        TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));

            PrintFormat("  狀態 Status  | 🔒 已鎖定 | 重疊:%d 分數:%.1f", lock_ol, lock_sc);

            PrintFormat("  錨點 Anchors | 波段高 1.000: %.5f (bar %d)  波段低 0.000: %.5f (bar %d)  幅度: %.1f pips",
                        g_locked_fib.swing_high, g_locked_hbar,
                        g_locked_fib.swing_low,  g_locked_lbar,
                        g_locked_fib.range / pip);

            PrintFormat("  回撤 Retrace | 0.236: %.5f  0.382: %.5f  0.500: %.5f  0.618: %.5f  0.786: %.5f",
                        g_locked_fib.fib_236, g_locked_fib.fib_382,
                        g_locked_fib.fib_500, g_locked_fib.fib_618, g_locked_fib.fib_786);

            if(InpShowExtensions)
                PrintFormat("  延伸 Ext     | 1.618: %.5f  2.618: %.5f  3.618: %.5f（耗盡位）",
                            g_locked_fib.fib_1618, g_locked_fib.fib_2618, g_locked_fib.fib_3618);

            PrintFormat("  ATR 接近閾值 | ATR: %.5f  閾值: %.5f (%.1f pips)",
                        atr, threshold, threshold / pip);

            string near_label;
            double near_price;
            if(IsFibNear(close[rates_total - 1], g_locked_fib, threshold, near_label, near_price))
                PrintFormat("  >>> 價格接近 Fib %s (%.5f) — 當前價: %.5f  距離: %.1f pips",
                            near_label, near_price, close[rates_total - 1],
                            MathAbs(close[rates_total - 1] - near_price) / pip);
            else
                PrintFormat("  當前價 %.5f — 未接近任何 Fib level", close[rates_total - 1]);
        }
    }
    else if(InpPrintLog)
        Print("  [M5 Fib] 未鎖定，等待符合條件嘅錨點");

    return rates_total;
}
