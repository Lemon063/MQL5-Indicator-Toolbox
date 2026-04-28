//+------------------------------------------------------------------+
//|  FibComparison.mq5                                               |
//|  MQL5 Indicator Toolbox                                          |
//|  A/B 比較：PIP Fibonacci vs 傳統 PivotSR Fibonacci               |
//|  v1.20：雙 CSV logging — 兩組數據並排寫入同一個 file             |
//|    File A — 每 bar log（PIP + PSR 所有 Fib levels）              |
//|    File B — 錨點變化 log（任一組錨點改變時記錄）                  |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "1.20"
#property description "Compare PIP-based Fib vs Traditional PivotSR Fib with dual CSV logging."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Toolbox/FibPIP.mqh>
#include <Toolbox/FibTypes.mqh>
#include <Toolbox/Fibonacci.mqh>
#include <Toolbox/PivotSR.mqh>

//=== 通用 ===
input bool   InpIsBuy          = true;
input bool   InpShowExtensions = true;
input bool   InpPrintLog       = true;
input int    InpAtrPeriod      = 14;
input double InpAtrMult        = 0.20;
input int    InpLineLookback   = 100;

//=== 組 A：PIP ===
input int           InpPIP_Order    = 5;
input int           InpPIP_Window   = 50;
input ENUM_PIP_DIST InpPIP_DistMode = PIP_VER_DIS;
input double        InpPIP_MinRange = 10.0;
input bool          InpPIP_UseSR    = true;   // PIP 是否加 S/R 評分

//=== 組 B：傳統 PivotSR ===
input int    InpPSR_PivotN     = 5;
input int    InpPSR_PivotLook  = 96;
input int    InpPSR_SRLookback = 100;
input double InpPSR_SRZonePips = 10.0;
input int    InpPSR_SRMinCount = 4;
input double InpPSR_SRTolPips  = 10.0;
input double InpPSR_MinRange   = 10.0;

//=== 共用 S/R 參數（PIP SR + PSR 用同一組，確保公平比較）===
input int    InpSRLookback     = 100;
input double InpSRZonePips     = 10.0;
input int    InpSRMinCount     = 4;
input double InpSRTolPips      = 10.0;

//=== CSV Logging ===
input bool   InpLogBarCSV      = true;
input bool   InpLogAnchorCSV   = true;
input string InpLogFolder      = "FibCMP_Logs";

//--- Object prefixes
const string PA = "CMPFIB_A_LINE_";
const string LA = "CMPFIB_A_LBL_";
const string PB = "CMPFIB_B_LINE_";
const string LB = "CMPFIB_B_LBL_";

int g_atrHandle = INVALID_HANDLE;
int g_bar_csv    = INVALID_HANDLE;
int g_anchor_csv = INVALID_HANDLE;

// 記錄上一次錨點，用嚟判斷有冇變化
double g_prev_a_high = 0, g_prev_a_low = 0;
double g_prev_b_high = 0, g_prev_b_low = 0;

//+------------------------------------------------------------------+
//|  CSV 工具                                                        |
//+------------------------------------------------------------------+
string DistModeStr(ENUM_PIP_DIST m)
{
    switch(m) { case PIP_EUC_DIS: return "EUC"; case PIP_PER_DIS: return "PER"; default: return "VER"; }
}

bool EnsureLogFolder()
{
    FolderCreate(InpLogFolder, FILE_COMMON);
    return true;
}

string BuildFilePath(string suffix)
{
    string sym = _Symbol;
    StringReplace(sym, ".", "_");
    string tf_str = EnumToString(Period());
    StringReplace(tf_str, "PERIOD_", "");
    return InpLogFolder + "\\" + sym + "_" + tf_str + "_"
           + (InpIsBuy ? "BUY" : "SELL")
           + "_CMP_" + suffix + ".csv";
}

void WriteBarHeader()
{
    if(g_bar_csv == INVALID_HANDLE) return;
    // 兩組並排：每個 column 有 _a 或 _b 後綴
    string h = "datetime,symbol,timeframe,direction,current_price,"
               // 組 A
               "a_method,a_dist_mode,a_order,a_window,a_use_sr,"
               "a_high,a_low,a_high_bar,a_low_bar,a_range_pips,"
               "a_geom_score,a_sr_score,a_sr_overlap,"
               "a_fib236,a_fib382,a_fib500,a_fib618,a_fib786,"
               "a_fib1000,a_fib1618,a_fib2618,a_fib3618,"
               // 組 B
               "b_method,b_pivotN,b_pivotLook,"
               "b_high,b_low,b_high_bar,b_low_bar,b_range_pips,"
               "b_sr_score,b_sr_overlap,"
               "b_fib236,b_fib382,b_fib500,b_fib618,b_fib786,"
               "b_fib1000,b_fib1618,b_fib2618,b_fib3618,"
               // 差值
               "diff_high_pips,diff_low_pips,"
               "diff_fib382_pips,diff_fib500_pips,diff_fib618_pips,"
               "atr\n";
    FileWriteString(g_bar_csv, h);
}

void WriteAnchorHeader()
{
    if(g_anchor_csv == INVALID_HANDLE) return;
    string h = "datetime,symbol,timeframe,direction,changed_group,"
               "a_high,a_low,a_high_bar,a_low_bar,a_range_pips,a_geom_score,a_sr_score,a_sr_overlap,"
               "a_fib236,a_fib382,a_fib500,a_fib618,a_fib786,a_fib1000,a_fib1618,a_fib2618,a_fib3618,"
               "b_high,b_low,b_high_bar,b_low_bar,b_range_pips,b_sr_score,b_sr_overlap,"
               "b_fib236,b_fib382,b_fib500,b_fib618,b_fib786,b_fib1000,b_fib1618,b_fib2618,b_fib3618,"
               "diff_fib618_pips,diff_fib382_pips\n";
    FileWriteString(g_anchor_csv, h);
}

string FibStr(const FibLevels &f)
{
    return DoubleToString(f.fib_236, 5) + ","
         + DoubleToString(f.fib_382, 5) + ","
         + DoubleToString(f.fib_500, 5) + ","
         + DoubleToString(f.fib_618, 5) + ","
         + DoubleToString(f.fib_786, 5) + ","
         + DoubleToString(f.fib_1000, 5) + ","
         + DoubleToString(f.fib_1618, 5) + ","
         + DoubleToString(f.fib_2618, 5) + ","
         + DoubleToString(f.fib_3618, 5);
}

void WriteBarRow(datetime dt, double current_price,
                 const FibLevels &fa, const PIPAnchorResult &aa,
                 const FibLevels &fb, const AnchorResult &ab,
                 double fib_sr_b, int sr_ol_b,
                 double atr, double pip_size)
{
    if(g_bar_csv == INVALID_HANDLE) return;
    string tf_str = EnumToString(Period());
    StringReplace(tf_str, "PERIOD_", "");

    double diff_high  = (fa.swing_high - fb.swing_high) / pip_size;
    double diff_low   = (fa.swing_low  - fb.swing_low)  / pip_size;
    double diff_382   = (fa.fib_382    - fb.fib_382)    / pip_size;
    double diff_500   = (fa.fib_500    - fb.fib_500)    / pip_size;
    double diff_618   = (fa.fib_618    - fb.fib_618)    / pip_size;

    string row = TimeToString(dt, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + ","
               + _Symbol + "," + tf_str + ","
               + (InpIsBuy ? "BUY" : "SELL") + ","
               + DoubleToString(current_price, 5) + ","
               // A
               + "PIP," + DistModeStr(InpPIP_DistMode) + ","
               + IntegerToString(InpPIP_Order) + ","
               + IntegerToString(InpPIP_Window) + ","
               + (InpPIP_UseSR ? "1" : "0") + ","
               + DoubleToString(fa.swing_high, 5) + ","
               + DoubleToString(fa.swing_low, 5) + ","
               + IntegerToString(aa.high_bar) + ","
               + IntegerToString(aa.low_bar) + ","
               + DoubleToString(aa.range_pips, 2) + ","
               + DoubleToString(aa.geom_score, 2) + ","
               + DoubleToString(aa.fib_sr_score, 2) + ","
               + IntegerToString(aa.sr_overlap_count) + ","
               + FibStr(fa) + ","
               // B
               + "PSR,"
               + IntegerToString(InpPSR_PivotN) + ","
               + IntegerToString(InpPSR_PivotLook) + ","
               + DoubleToString(fb.swing_high, 5) + ","
               + DoubleToString(fb.swing_low, 5) + ","
               + IntegerToString(ab.high_bar) + ","
               + IntegerToString(ab.low_bar) + ","
               + DoubleToString(ab.range_pips, 2) + ","
               + DoubleToString(fib_sr_b, 2) + ","
               + IntegerToString(sr_ol_b) + ","
               + FibStr(fb) + ","
               // 差值
               + DoubleToString(diff_high, 2) + ","
               + DoubleToString(diff_low, 2) + ","
               + DoubleToString(diff_382, 2) + ","
               + DoubleToString(diff_500, 2) + ","
               + DoubleToString(diff_618, 2) + ","
               + DoubleToString(atr, 5) + "\n";
    FileWriteString(g_bar_csv, row);
    FileFlush(g_bar_csv);
}

void WriteAnchorRow(datetime dt,
                    const FibLevels &fa, const PIPAnchorResult &aa,
                    const FibLevels &fb, const AnchorResult &ab,
                    double fib_sr_b, int sr_ol_b,
                    string changed_group, double pip_size)
{
    if(g_anchor_csv == INVALID_HANDLE) return;
    string tf_str = EnumToString(Period());
    StringReplace(tf_str, "PERIOD_", "");

    double diff_618 = (fa.fib_618 - fb.fib_618) / pip_size;
    double diff_382 = (fa.fib_382 - fb.fib_382) / pip_size;

    string row = TimeToString(dt, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + ","
               + _Symbol + "," + tf_str + ","
               + (InpIsBuy ? "BUY" : "SELL") + ","
               + changed_group + ","
               // A
               + DoubleToString(fa.swing_high, 5) + ","
               + DoubleToString(fa.swing_low, 5) + ","
               + IntegerToString(aa.high_bar) + ","
               + IntegerToString(aa.low_bar) + ","
               + DoubleToString(aa.range_pips, 2) + ","
               + DoubleToString(aa.geom_score, 2) + ","
               + DoubleToString(aa.fib_sr_score, 2) + ","
               + IntegerToString(aa.sr_overlap_count) + ","
               + FibStr(fa) + ","
               // B
               + DoubleToString(fb.swing_high, 5) + ","
               + DoubleToString(fb.swing_low, 5) + ","
               + IntegerToString(ab.high_bar) + ","
               + IntegerToString(ab.low_bar) + ","
               + DoubleToString(ab.range_pips, 2) + ","
               + DoubleToString(fib_sr_b, 2) + ","
               + IntegerToString(sr_ol_b) + ","
               + FibStr(fb) + ","
               + DoubleToString(diff_618, 2) + ","
               + DoubleToString(diff_382, 2) + "\n";
    FileWriteString(g_anchor_csv, row);
    FileFlush(g_anchor_csv);
}

//+------------------------------------------------------------------+
//|  Chart 畫線                                                      |
//+------------------------------------------------------------------+
void DrawLine(string pfx, string name, double price, color clr,
              ENUM_LINE_STYLE style, int width, string tooltip)
{
    string   obj     = pfx + name;
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

void DrawLabel(string pfx, string name, double price, color clr, string text)
{
    string   obj = pfx + name;
    datetime t   = iTime(_Symbol, PERIOD_CURRENT, 3);
    if(ObjectFind(0, obj) < 0)
        ObjectCreate(0, obj, OBJ_TEXT, 0, t, price);
    ObjectSetInteger(0, obj, OBJPROP_TIME,       t);
    ObjectSetDouble(0, obj,  OBJPROP_PRICE,      price);
    ObjectSetString(0, obj,  OBJPROP_TEXT,       text);
    ObjectSetInteger(0, obj, OBJPROP_COLOR,      clr);
    ObjectSetInteger(0, obj, OBJPROP_FONTSIZE,   7);
    ObjectSetString(0, obj,  OBJPROP_FONT,       "Arial");
    ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, obj, OBJPROP_BACK,       false);
}

void DeleteGroup(string lp, string ll)
{
    int total = ObjectsTotal(0, 0, OBJ_TREND);
    for(int i = total - 1; i >= 0; i--)
    {
        string nm = ObjectName(0, i, 0, OBJ_TREND);
        if(StringFind(nm, lp) == 0) ObjectDelete(0, nm);
    }
    total = ObjectsTotal(0, 0, OBJ_TEXT);
    for(int i = total - 1; i >= 0; i--)
    {
        string nm = ObjectName(0, i, 0, OBJ_TEXT);
        if(StringFind(nm, ll) == 0) ObjectDelete(0, nm);
    }
}

void DrawFibGroup(const FibLevels &f, string lp, string ll, string tag)
{
    bool is_a = (StringFind(lp, "_A_") >= 0);
    color c0   = is_a ? clrAqua        : clrOrange;
    color c236 = is_a ? clrYellow      : clrGold;
    color c382 = is_a ? clrYellowGreen : clrDarkOrange;
    color c500 = is_a ? clrLime        : clrOrangeRed;
    color c618 = is_a ? clrLimeGreen   : clrTomato;
    color c786 = is_a ? clrGreen       : clrRed;
    color c100 = is_a ? clrLightCyan   : clrWhiteSmoke;
    color cext = is_a ? clrPlum        : clrMediumPurple;
    string s   = " [" + tag + "]";

    DrawLine(lp, "SH",   f.swing_high, c100, STYLE_DOT,  1, "1.000" + s);
    DrawLine(lp, "SL",   f.swing_low,  c0,   STYLE_DOT,  1, "0.000" + s);
    DrawLine(lp, "236",  f.fib_236,    c236, STYLE_DASH, 1, "0.236" + s);
    DrawLine(lp, "382",  f.fib_382,    c382, STYLE_DASH, 1, "0.382" + s);
    DrawLine(lp, "500",  f.fib_500,    c500, STYLE_SOLID,1, "0.500" + s);
    DrawLine(lp, "618",  f.fib_618,    c618, STYLE_SOLID,2, "0.618" + s);
    DrawLine(lp, "786",  f.fib_786,    c786, STYLE_SOLID,1, "0.786" + s);
    DrawLabel(ll, "SH",  f.swing_high, c100, "1.000" + s);
    DrawLabel(ll, "SL",  f.swing_low,  c0,   "0.000" + s);
    DrawLabel(ll, "236", f.fib_236,    c236, "0.236" + s);
    DrawLabel(ll, "382", f.fib_382,    c382, "0.382" + s);
    DrawLabel(ll, "500", f.fib_500,    c500, "0.500" + s);
    DrawLabel(ll, "618", f.fib_618,    c618, "0.618" + s);
    DrawLabel(ll, "786", f.fib_786,    c786, "0.786" + s);
    if(InpShowExtensions)
    {
        DrawLine(lp, "1618", f.fib_1618, cext, STYLE_DASH, 1, "1.618" + s);
        DrawLine(lp, "2618", f.fib_2618, cext, STYLE_DASH, 1, "2.618" + s);
        DrawLine(lp, "3618", f.fib_3618, cext, STYLE_SOLID,2, "3.618" + s);
        DrawLabel(ll, "1618", f.fib_1618, cext, "1.618" + s);
        DrawLabel(ll, "2618", f.fib_2618, cext, "2.618" + s);
        DrawLabel(ll, "3618", f.fib_3618, cext, "3.618" + s);
    }
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
int OnInit()
{
    g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpAtrPeriod);
    if(g_atrHandle == INVALID_HANDLE) { Print("ERROR: iATR failed"); return INIT_FAILED; }

    EnsureLogFolder();
    if(InpLogBarCSV)
    {
        int h = FileOpen(BuildFilePath("bar"), FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ',');
        if(h != INVALID_HANDLE) { g_bar_csv = h; WriteBarHeader(); }
        else PrintFormat("⚠️ 無法開啟 bar CSV");
    }
    if(InpLogAnchorCSV)
    {
        int h = FileOpen(BuildFilePath("anchor"), FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ',');
        if(h != INVALID_HANDLE) { g_anchor_csv = h; WriteAnchorHeader(); }
        else PrintFormat("⚠️ 無法開啟 anchor CSV");
    }

    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("FibCMP(%s,O=%d,W=%d,N=%d)",
                     InpIsBuy ? "BUY" : "SELL",
                     InpPIP_Order, InpPIP_Window, InpPSR_PivotN));

    PrintFormat("✅ FibComparison 初始化完成 | Logs: %s", InpLogFolder);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    DeleteGroup(PA, LA);
    DeleteGroup(PB, LB);
    if(g_atrHandle != INVALID_HANDLE) { IndicatorRelease(g_atrHandle); g_atrHandle = INVALID_HANDLE; }
    if(g_bar_csv    != INVALID_HANDLE) { FileClose(g_bar_csv);    g_bar_csv    = INVALID_HANDLE; }
    if(g_anchor_csv != INVALID_HANDLE) { FileClose(g_anchor_csv); g_anchor_csv = INVALID_HANDLE; }
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
    int min_bars = MathMax(InpPIP_Window, InpPSR_PivotLook) + InpPSR_PivotN * 2 + 10;
    if(rates_total < min_bars) return 0;

    ArraySetAsSeries(time, true);
    static datetime last_bar_time = 0;
    if(time[0] == last_bar_time) return rates_total;
    last_bar_time = time[0];

    double atr_buf[];
    ArraySetAsSeries(atr_buf, true);
    double atr = 0;
    if(CopyBuffer(g_atrHandle, 0, 1, 1, atr_buf) > 0) atr = atr_buf[0];

    double pip_size      = GetPipSize(_Symbol);
    double current_price = close[rates_total - 1];
    datetime bar_time    = time[1];

    //--- 組 A：PIP
    PIPAnchorResult aa = GetAnchorPoints_PIP(
        _Symbol, PERIOD_CURRENT, InpIsBuy,
        InpPIP_Order, InpPIP_Window, InpPIP_DistMode, InpPIP_MinRange, 1,
        InpPIP_UseSR, InpSRLookback, InpSRZonePips, InpSRMinCount, InpSRTolPips);

    //--- 組 B：傳統 PivotSR
    AnchorResult ab = GetAnchorPoints(
        _Symbol, PERIOD_CURRENT, ANCHOR_M5, InpIsBuy,
        InpPSR_PivotN, InpPSR_PivotLook,
        InpSRLookback, InpSRZonePips, InpSRMinCount, InpSRTolPips,
        InpPSR_MinRange, 1);

    bool drew_a = false, drew_b = false;
    FibLevels fa, fb;

    // 初始化空 FibLevels（以防其中一組搵唔到）
    fa.swing_high = 0; fa.swing_low = 0; fa.range = 0; fa.is_buy = InpIsBuy;
    fa.fib_236=0; fa.fib_382=0; fa.fib_500=0; fa.fib_618=0; fa.fib_786=0;
    fa.fib_1000=0; fa.fib_1618=0; fa.fib_2618=0; fa.fib_3618=0;
    fb = fa;

    double fib_sr_b = 0;
    int    sr_ol_b  = 0;

    if(aa.valid && aa.range_ok)
    {
        fa = CalcFibLevels(aa.high, aa.low, InpIsBuy);
        DrawFibGroup(fa, PA, LA, "PIP");
        drew_a = true;
    }
    else DeleteGroup(PA, LA);

    if(ab.valid)
    {
        fb = CalcFibLevels(ab.high, ab.low, InpIsBuy);
        DrawFibGroup(fb, PB, LB, "PSR");
        drew_b = true;

        // 計算 PSR 組嘅 Fib-SR score（用共用 S/R 參數）
        if(InpPIP_UseSR)
        {
            SRResult sr_b = CalcSRZones(_Symbol, PERIOD_CURRENT, InpSRLookback, InpSRZonePips, InpSRMinCount, 1);
            double tol_b  = InpSRTolPips * pip_size;
            fib_sr_b = CalcFibSRScore(fb, sr_b, tol_b, sr_ol_b, ab.range_ok);
        }
    }
    else DeleteGroup(PB, LB);

    //--- 判斷錨點有冇變化
    bool a_changed = (drew_a && (MathAbs(aa.high - g_prev_a_high) > _Point ||
                                  MathAbs(aa.low  - g_prev_a_low)  > _Point));
    bool b_changed = (drew_b && (MathAbs(ab.high  - g_prev_b_high) > _Point ||
                                  MathAbs(ab.low   - g_prev_b_low)  > _Point));
    if(a_changed) { g_prev_a_high = aa.high; g_prev_a_low = aa.low; }
    if(b_changed) { g_prev_b_high = ab.high; g_prev_b_low = ab.low; }

    //--- CSV: bar log（兩組都有數據先寫，確保並排有意義）
    if(InpLogBarCSV && drew_a && drew_b)
    {
        // 填充臨時 AnchorResult 用於 log（如果只有 a 搵到，用空值）
        AnchorResult ab_log = ab;
        if(!drew_b) { ab_log.high=0; ab_log.low=0; ab_log.high_bar=0; ab_log.low_bar=0; ab_log.range_pips=0; }
        WriteBarRow(bar_time, current_price, fa, aa, fb, ab_log, fib_sr_b, sr_ol_b, atr, pip_size);
    }

    //--- CSV: anchor log
    if(InpLogAnchorCSV && (a_changed || b_changed) && drew_a && drew_b)
    {
        string changed_group = a_changed && b_changed ? "BOTH" : (a_changed ? "A_PIP" : "B_PSR");
        AnchorResult ab_log = ab;
        WriteAnchorRow(bar_time, fa, aa, fb, ab_log, fib_sr_b, sr_ol_b, changed_group, pip_size);
    }

    //--- Journal
    if(InpPrintLog && drew_a && drew_b)
    {
        double diff_618 = (fa.fib_618 - fb.fib_618) / pip_size;
        double diff_382 = (fa.fib_382 - fb.fib_382) / pip_size;
        string agree618 = MathAbs(diff_618) < 5.0 ? "✅" : "⚠️";
        string agree382 = MathAbs(diff_382) < 5.0 ? "✅" : "⚠️";

        PrintFormat("=== FibCMP | %s | %s | %s ===",
                    _Symbol, InpIsBuy ? "BUY" : "SELL",
                    TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
        PrintFormat("  [A-PIP] H:%.5f(bar%d) L:%.5f(bar%d) Range:%.1fpips Geom:%.1f SR:%.1f OL:%d",
                    fa.swing_high, aa.high_bar, fa.swing_low, aa.low_bar,
                    aa.range_pips, aa.geom_score, aa.fib_sr_score, aa.sr_overlap_count);
        PrintFormat("  [B-PSR] H:%.5f(bar%d) L:%.5f(bar%d) Range:%.1fpips SR:%.1f OL:%d",
                    fb.swing_high, ab.high_bar, fb.swing_low, ab.low_bar,
                    ab.range_pips, fib_sr_b, sr_ol_b);
        PrintFormat("  diff 0.618: %+.1f pips %s | diff 0.382: %+.1f pips %s",
                    diff_618, agree618, diff_382, agree382);
    }

    return rates_total;
}
