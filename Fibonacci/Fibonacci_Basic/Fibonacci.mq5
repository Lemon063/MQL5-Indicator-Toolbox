//+------------------------------------------------------------------+
//|  Fibonacci.mq5                                                   |
//|  MQL5 Indicator Toolbox                                          |
//|  視覺圖表 indicator — attach 到 chart 驗證邏輯                    |
//|  M5 mode：距離優先 + Fib-SR 評分 + 鎖定/解鎖機制                 |
//|  H1 mode：S/R 強度優先 + 波段完整性驗證，唔鎖定                   |
//|  v3.20：DrawFibLine 改用 OBJ_TREND 限制線長（唔延伸）             |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "3.20"
#property description "Fib levels via PivotSR. M5=lock/unlock. H1=wave integrity+strength."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Toolbox/Fibonacci.mqh>

enum ENUM_FIB_MODE
{
    FIB_MODE_M5,
    FIB_MODE_H1
};

input ENUM_FIB_MODE InpFibMode      = FIB_MODE_M5;
input int    InpPivotN_M5           = 5;     // M5 Pivot 確認 bars
input int    InpPivotN_H1           = 8;     // H1 Pivot 確認 bars
input int    InpPivotLook_M5        = 96;    // M5 回望 bars（8小時）
input int    InpPivotLook_H1        = 336;   // H1 回望 bars（14日）
input int    InpSRLookback          = 100;
input double InpSRZonePips          = 10.0;
input int    InpSRMinCount          = 4;
input double InpSRTolPips           = 10.0;
input bool   InpIsBuy               = true;
input bool   InpShowExtensions      = true;
input double InpAtrMult             = 0.20;
input int    InpAtrPeriod           = 14;
input int    InpMinOverlap          = 3;
input double InpMinScore            = 6.0;
input double InpMinRangePips        = 10.0;
input int    InpLineLookback        = 100;   // Fib 線往左延伸幾多 bars
input bool   InpPrintLog            = true;

string g_prefix;
string g_prefix_label;
int    g_atrHandle = INVALID_HANDLE;
FibLevels g_locked_fib;
bool      g_is_locked    = false;
int       g_locked_hbar  = 0;   // 鎖定錨點嘅 high_bar
int       g_locked_lbar  = 0;   // 鎖定錨點嘅 low_bar

//+------------------------------------------------------------------+
//|  DrawFibLine — 改用 OBJ_TREND，固定起點終點，唔延伸              |
//+------------------------------------------------------------------+
void DrawFibLine(string name, double price, color clr,
                 ENUM_LINE_STYLE style, int width, string tooltip)
{
    string   obj     = g_prefix + name;
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
    string   obj = g_prefix_label + name;
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
        if(StringFind(name, g_prefix) == 0)
            ObjectDelete(0, name);
    }
    total = ObjectsTotal(0, 0, OBJ_TEXT);
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, 0, OBJ_TEXT);
        if(StringFind(name, g_prefix_label) == 0)
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
    g_prefix       = (InpFibMode == FIB_MODE_M5) ? "FIB_M5_LINE_" : "FIB_H1_LINE_";
    g_prefix_label = (InpFibMode == FIB_MODE_M5) ? "FIB_M5_LBL_"  : "FIB_H1_LBL_";

    g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpAtrPeriod);
    if(g_atrHandle == INVALID_HANDLE)
    {
        Print("錯誤 ERROR: iATR handle 建立失敗");
        return INIT_FAILED;
    }

    g_is_locked = false;

    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("Fib_%s(%s,N=%d)",
                     InpFibMode == FIB_MODE_M5 ? "M5" : "H1",
                     InpIsBuy ? "BUY" : "SELL",
                     InpFibMode == FIB_MODE_H1 ? InpPivotN_H1 : InpPivotN_M5));

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
void PrintFibLog(const FibLevels &f,
                 double atr, double threshold, double pip,
                 double current_price,
                 string mode_str, bool is_locked,
                 int overlap_count, double score,
                 int high_bar, int low_bar)
{
    PrintFormat("=== Fibonacci 費波那契 | %s | %s | %s | %s ===",
                _Symbol,
                InpIsBuy ? "BUY" : "SELL",
                mode_str,
                TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));

    if(mode_str == "M5")
    {
        string lock_str = is_locked
            ? StringFormat("🔒 已鎖定 | 重疊:%d 分數:%.1f", overlap_count, score)
            : "🔓 未鎖定";
        PrintFormat("  狀態 Status  | %s", lock_str);
    }

    PrintFormat("  錨點 Anchors | 波段高 1.000: %.5f (bar %d)  波段低 0.000: %.5f (bar %d)  幅度 Range: %.1f pips",
                f.swing_high, high_bar, f.swing_low, low_bar, f.range / pip);

    PrintFormat("  回撤 Retrace | 0.236: %.5f  0.382: %.5f  0.500: %.5f  0.618: %.5f  0.786: %.5f",
                f.fib_236, f.fib_382, f.fib_500, f.fib_618, f.fib_786);

    if(InpShowExtensions)
        PrintFormat("  延伸 Ext     | 1.618: %.5f  2.618: %.5f  3.618: %.5f（耗盡位）",
                    f.fib_1618, f.fib_2618, f.fib_3618);

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
    //--- 按 mode 決定實際用嘅 pivot 參數
    int pivot_n    = (InpFibMode == FIB_MODE_H1) ? InpPivotN_H1    : InpPivotN_M5;
    int pivot_look = (InpFibMode == FIB_MODE_H1) ? InpPivotLook_H1 : InpPivotLook_M5;

    if(rates_total < pivot_look + pivot_n * 2 + 2)
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

    //================================================================
    //  H1 mode
    //================================================================
    if(InpFibMode == FIB_MODE_H1)
    {
        AnchorResult anchor_h1 = GetAnchorPoints(
            _Symbol, PERIOD_CURRENT, ANCHOR_H1, InpIsBuy,
            pivot_n, pivot_look,
            InpSRLookback, InpSRZonePips,
            InpSRMinCount, InpSRTolPips,
            0.0, 1);

        if(!anchor_h1.valid)
        {
            if(InpPrintLog)
                Print("  錨點搵唔到 — 調整 Pivot / S/R 參數或切換 BUY/SELL");
            return rates_total;
        }

        FibLevels f = CalcFibLevels(anchor_h1.high, anchor_h1.low, InpIsBuy);

        DrawAllFibLines(f);

        if(InpPrintLog)
        {
            SRResult sr_h1 = CalcSRZones(_Symbol, PERIOD_CURRENT,
                                          InpSRLookback, InpSRZonePips,
                                          InpSRMinCount, 1);
            double tol_h1 = InpSRTolPips * pip;
            int    ol_h1  = 0;
            double sc_h1  = CalcFibSRScore(f, sr_h1, tol_h1, ol_h1, true);
            PrintFibLog(f, atr, threshold, pip,
                        close[rates_total - 1], "H1", false, ol_h1, sc_h1,
                        anchor_h1.high_bar, anchor_h1.low_bar);
        }

        return rates_total;
    }

    //================================================================
    //  M5 mode
    //================================================================
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
            pivot_n, pivot_look,
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
            PrintFibLog(g_locked_fib, atr, threshold, pip,
                        close[rates_total - 1], "M5", true, lock_ol, lock_sc,
                        g_locked_hbar, g_locked_lbar);
        }
    }
    else if(InpPrintLog)
        Print("  [M5 Fib] 未鎖定，等待符合條件嘅錨點");

    return rates_total;
}
