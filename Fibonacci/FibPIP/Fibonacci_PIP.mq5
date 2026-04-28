//+------------------------------------------------------------------+
//|  Fibonacci_PIP.mq5                                               |
//|  MQL5 Indicator Toolbox                                          |
//|  PIP Fibonacci Indicator                                         |
//|  v1.20：雙 CSV logging                                           |
//|    File A — 每 bar log（所有 Fib levels + 當前價）               |
//|    File B — 錨點變化 log（只有錨點改變時記錄）                    |
//|  + S/R 評分獨立開關                                               |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "1.20"
#property description "PIP-based Fibonacci with dual CSV logging. Bar log + Anchor change log."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Toolbox/FibPIP.mqh>
#include <Toolbox/FibTypes.mqh>
#include <Toolbox/Fibonacci.mqh>

//=== PIP 算法參數 ===
input int           InpPIPOrder       = 5;
input int           InpWindowSize     = 50;
input ENUM_PIP_DIST InpDistMode       = PIP_VER_DIS;
input double        InpMinRangePips   = 10.0;

//=== S/R 評分（獨立開關）===
input bool          InpUseSR          = true;     // 開啟 S/R overlap 評分
input int           InpSRLookback     = 100;
input double        InpSRZonePips     = 10.0;
input int           InpSRMinCount     = 4;
input double        InpSRTolPips      = 10.0;

//=== Fib 顯示 ===
input bool          InpIsBuy          = true;
input bool          InpShowExtensions = true;
input double        InpAtrMult        = 0.20;
input int           InpAtrPeriod      = 14;
input int           InpLineLookback   = 100;

//=== 鎖定機制 ===
input bool          InpUseLock        = true;

//=== CSV Logging ===
input bool          InpLogBarCSV      = true;    // 每 bar log
input bool          InpLogAnchorCSV   = true;    // 錨點變化 log
input string        InpLogFolder      = "FibPIP_Logs";

//=== Journal ===
input bool          InpPrintLog       = true;

//--- Globals
const string PREFIX       = "PIP_FIB_LINE_";
const string PREFIX_LABEL = "PIP_FIB_LBL_";
int       g_atrHandle   = INVALID_HANDLE;
FibLevels g_locked_fib;
bool      g_is_locked   = false;
int       g_locked_hbar = 0;
int       g_locked_lbar = 0;
double    g_locked_geom  = 0;
double    g_locked_sr    = 0;
int       g_locked_ol   = 0;

// CSV file handles
int g_bar_csv    = INVALID_HANDLE;
int g_anchor_csv = INVALID_HANDLE;
string g_bar_csv_path    = "";
string g_anchor_csv_path = "";

//+------------------------------------------------------------------+
//|  CSV 工具函數                                                    |
//+------------------------------------------------------------------+
string DistModeStr(ENUM_PIP_DIST m)
{
    switch(m) { case PIP_EUC_DIS: return "EUC"; case PIP_PER_DIS: return "PER"; default: return "VER"; }
}

bool EnsureLogFolder()
{
    if(!FolderCreate(InpLogFolder, FILE_COMMON)) return false;
    return true;
}

string BuildFilePath(string suffix)
{
    string sym = _Symbol;
    StringReplace(sym, ".", "_");
    string tf_str = EnumToString(Period());
    StringReplace(tf_str, "PERIOD_", "");
    string dir_str = InpIsBuy ? "BUY" : "SELL";
    string dist_str = DistModeStr(InpDistMode);
    string sr_str = InpUseSR ? "SR1" : "SR0";

    return InpLogFolder + "\\" + sym + "_" + tf_str + "_" + dir_str
           + "_O" + IntegerToString(InpPIPOrder)
           + "_W" + IntegerToString(InpWindowSize)
           + "_" + dist_str
           + "_" + sr_str
           + "_" + suffix + ".csv";
}

void WriteBarHeader()
{
    if(g_bar_csv == INVALID_HANDLE) return;
    string hdr = "datetime,symbol,timeframe,direction,dist_mode,pip_order,window_size,use_sr,"
                 "current_price,"
                 "anchor_high,anchor_low,anchor_high_bar,anchor_low_bar,"
                 "range_pips,geom_score,fib_sr_score,sr_overlap,"
                 "fib_236,fib_382,fib_500,fib_618,fib_786,"
                 "fib_1000,fib_1618,fib_2618,fib_3618,"
                 "atr,locked\n";
    FileWriteString(g_bar_csv, hdr);
}

void WriteAnchorHeader()
{
    if(g_anchor_csv == INVALID_HANDLE) return;
    string hdr = "datetime,symbol,timeframe,direction,dist_mode,pip_order,window_size,use_sr,"
                 "anchor_high,anchor_low,anchor_high_bar,anchor_low_bar,"
                 "range_pips,geom_score,fib_sr_score,sr_overlap,range_ok,"
                 "fib_236,fib_382,fib_500,fib_618,fib_786,"
                 "fib_1000,fib_1618,fib_2618,fib_3618,"
                 "event\n";
    FileWriteString(g_anchor_csv, hdr);
}

string FibRowCore(const FibLevels &f, const PIPAnchorResult &a)
{
    return DoubleToString(f.swing_high, 5) + ","
         + DoubleToString(f.swing_low, 5) + ","
         + IntegerToString(a.high_bar) + ","
         + IntegerToString(a.low_bar) + ","
         + DoubleToString(a.range_pips, 2) + ","
         + DoubleToString(a.geom_score, 2) + ","
         + DoubleToString(a.fib_sr_score, 2) + ","
         + IntegerToString(a.sr_overlap_count) + ","
         + DoubleToString(f.fib_236, 5) + ","
         + DoubleToString(f.fib_382, 5) + ","
         + DoubleToString(f.fib_500, 5) + ","
         + DoubleToString(f.fib_618, 5) + ","
         + DoubleToString(f.fib_786, 5) + ","
         + DoubleToString(f.fib_1000, 5) + ","
         + DoubleToString(f.fib_1618, 5) + ","
         + DoubleToString(f.fib_2618, 5) + ","
         + DoubleToString(f.fib_3618, 5);
}

string MetaPrefix()
{
    string tf_str = EnumToString(Period());
    StringReplace(tf_str, "PERIOD_", "");
    return _Symbol + "," + tf_str + ","
         + (InpIsBuy ? "BUY" : "SELL") + ","
         + DistModeStr(InpDistMode) + ","
         + IntegerToString(InpPIPOrder) + ","
         + IntegerToString(InpWindowSize) + ","
         + (InpUseSR ? "1" : "0") + ",";
}

void WriteBarRow(datetime dt, double current_price,
                 const FibLevels &f, const PIPAnchorResult &a,
                 double atr, bool locked)
{
    if(g_bar_csv == INVALID_HANDLE) return;
    string row = TimeToString(dt, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + ","
               + MetaPrefix()
               + DoubleToString(current_price, 5) + ","
               + FibRowCore(f, a) + ","
               + DoubleToString(atr, 5) + ","
               + (locked ? "1" : "0") + "\n";
    FileWriteString(g_bar_csv, row);
    FileFlush(g_bar_csv);
}

void WriteAnchorRow(datetime dt, const FibLevels &f, const PIPAnchorResult &a, string event)
{
    if(g_anchor_csv == INVALID_HANDLE) return;
    string row = TimeToString(dt, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + ","
               + MetaPrefix()
               + FibRowCore(f, a) + ","
               + (a.range_ok ? "1" : "0") + ","
               + event + "\n";
    FileWriteString(g_anchor_csv, row);
    FileFlush(g_anchor_csv);
}

//+------------------------------------------------------------------+
//|  Chart 畫線                                                      |
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

void DrawFibLabel(string name, double price, color clr, string text)
{
    string   obj = PREFIX_LABEL + name;
    datetime t   = iTime(_Symbol, PERIOD_CURRENT, 5);
    if(ObjectFind(0, obj) < 0)
        ObjectCreate(0, obj, OBJ_TEXT, 0, t, price);
    ObjectSetInteger(0, obj, OBJPROP_TIME,       t);
    ObjectSetDouble(0, obj,  OBJPROP_PRICE,      price);
    ObjectSetString(0, obj,  OBJPROP_TEXT,       text);
    ObjectSetInteger(0, obj, OBJPROP_COLOR,      clr);
    ObjectSetInteger(0, obj, OBJPROP_FONTSIZE,   8);
    ObjectSetString(0, obj,  OBJPROP_FONT,       "Arial");
    ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, obj, OBJPROP_BACK,       false);
}

void DeleteAllObjects()
{
    int total = ObjectsTotal(0, 0, OBJ_TREND);
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, 0, OBJ_TREND);
        if(StringFind(name, PREFIX) == 0) ObjectDelete(0, name);
    }
    total = ObjectsTotal(0, 0, OBJ_TEXT);
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, 0, OBJ_TEXT);
        if(StringFind(name, PREFIX_LABEL) == 0) ObjectDelete(0, name);
    }
}

void DrawFibSet(string name, double price, color clr, ENUM_LINE_STYLE style, int width, string level_str)
{
    string text = "[PIP] " + level_str + "  " + DoubleToString(price, 5);
    DrawFibLine(name, price, clr, style, width, text);
    DrawFibLabel(name, price, clr, text);
}

void DrawAllFibLines(const FibLevels &f)
{
    DrawFibSet("SH",   f.swing_high, clrAqua,          STYLE_DOT,   1, "1.000");
    DrawFibSet("SL",   f.swing_low,  clrLightSkyBlue,  STYLE_DOT,   1, "0.000");
    DrawFibSet("236",  f.fib_236,    clrYellow,         STYLE_DASH,  1, "0.236");
    DrawFibSet("382",  f.fib_382,    clrYellowGreen,    STYLE_DASH,  1, "0.382");
    DrawFibSet("500",  f.fib_500,    clrLime,           STYLE_SOLID, 1, "0.500");
    DrawFibSet("618",  f.fib_618,    clrLimeGreen,      STYLE_SOLID, 2, "0.618");
    DrawFibSet("786",  f.fib_786,    clrGreen,          STYLE_SOLID, 1, "0.786");
    if(InpShowExtensions)
    {
        DrawFibSet("1618", f.fib_1618, clrPlum,         STYLE_DASH,  1, "1.618");
        DrawFibSet("2618", f.fib_2618, clrOrchid,       STYLE_DASH,  1, "2.618");
        DrawFibSet("3618", f.fib_3618, clrMediumOrchid, STYLE_SOLID, 2, "3.618");
    }
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
int OnInit()
{
    g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpAtrPeriod);
    if(g_atrHandle == INVALID_HANDLE) { Print("ERROR: iATR failed"); return INIT_FAILED; }
    g_is_locked = false;

    // 建立 log 資料夾 + 開啟 CSV files
    EnsureLogFolder();

    if(InpLogBarCSV)
    {
        g_bar_csv_path = BuildFilePath("bar");
        g_bar_csv = FileOpen(g_bar_csv_path, FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ',');
        if(g_bar_csv != INVALID_HANDLE) WriteBarHeader();
        else PrintFormat("⚠️ 無法開啟 bar CSV: %s", g_bar_csv_path);
    }

    if(InpLogAnchorCSV)
    {
        g_anchor_csv_path = BuildFilePath("anchor");
        g_anchor_csv = FileOpen(g_anchor_csv_path, FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ',');
        if(g_anchor_csv != INVALID_HANDLE) WriteAnchorHeader();
        else PrintFormat("⚠️ 無法開啟 anchor CSV: %s", g_anchor_csv_path);
    }

    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("FibPIP(%s,O=%d,W=%d,%s%s)",
                     InpIsBuy ? "BUY" : "SELL",
                     InpPIPOrder, InpWindowSize,
                     DistModeStr(InpDistMode),
                     InpUseSR ? ",SR" : ""));

    PrintFormat("✅ FibPIP 初始化 | Bar CSV: %s | Anchor CSV: %s",
                g_bar_csv != INVALID_HANDLE ? g_bar_csv_path : "OFF",
                g_anchor_csv != INVALID_HANDLE ? g_anchor_csv_path : "OFF");

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    DeleteAllObjects();
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
    if(rates_total < InpWindowSize + 10) return 0;

    ArraySetAsSeries(time, true);
    static datetime last_bar_time = 0;
    if(time[0] == last_bar_time) return rates_total;
    last_bar_time = time[0];

    double atr_buf[];
    ArraySetAsSeries(atr_buf, true);
    double atr = 0;
    if(CopyBuffer(g_atrHandle, 0, 1, 1, atr_buf) > 0) atr = atr_buf[0];

    double pip_size = GetPipSize(_Symbol);
    double threshold = atr * InpAtrMult;
    datetime bar_time = time[1]; // 用已收市 bar 嘅時間

    //----------------------------------------------------------------
    //  搵 PIP 錨點
    //----------------------------------------------------------------
    PIPAnchorResult anchor = GetAnchorPoints_PIP(
        _Symbol, PERIOD_CURRENT,
        InpIsBuy,
        InpPIPOrder, InpWindowSize, InpDistMode,
        InpMinRangePips, 1,
        InpUseSR, InpSRLookback, InpSRZonePips, InpSRMinCount, InpSRTolPips);

    //----------------------------------------------------------------
    //  鎖定機制
    //----------------------------------------------------------------
    bool anchor_changed = false;
    string lock_event = "";

    if(InpUseLock)
    {
        if(g_is_locked && anchor.valid)
        {
            double locked_range = g_locked_fib.swing_high - g_locked_fib.swing_low;
            double new_range    = anchor.high - anchor.low;
            if(new_range < locked_range * 0.5)
            {
                g_is_locked    = false;
                anchor_changed = true;
                lock_event     = "UNLOCK_RANGE_SHRINK";
                if(InpPrintLog)
                    PrintFormat("⚠️ PIP Fib 解鎖 | 舊:%.1f pips → 新:%.1f pips",
                                locked_range / pip_size, new_range / pip_size);
            }
        }

        if(!g_is_locked && anchor.valid && anchor.range_ok)
        {
            FibLevels candidate = CalcFibLevels(anchor.high, anchor.low, InpIsBuy);

            bool do_lock = true;
            if(InpUseSR && anchor.sr_overlap_count < 1) do_lock = false; // 至少 1 個 S/R 重疊

            if(do_lock)
            {
                g_locked_fib  = candidate;
                g_is_locked   = true;
                g_locked_hbar = anchor.high_bar;
                g_locked_lbar = anchor.low_bar;
                g_locked_geom = anchor.geom_score;
                g_locked_sr   = anchor.fib_sr_score;
                g_locked_ol   = anchor.sr_overlap_count;
                anchor_changed = true;
                lock_event     = "NEW_LOCK";

                if(InpPrintLog)
                    PrintFormat("✅ PIP Fib 鎖定 | H:%.5f(bar%d) L:%.5f(bar%d) Range:%.1f GeomScore:%.1f SR:%.1f OL:%d",
                                anchor.high, anchor.high_bar,
                                anchor.low,  anchor.low_bar,
                                anchor.range_pips, anchor.geom_score,
                                anchor.fib_sr_score, anchor.sr_overlap_count);
            }
        }
    }
    else if(anchor.valid && anchor.range_ok)
    {
        FibLevels candidate = CalcFibLevels(anchor.high, anchor.low, InpIsBuy);
        bool changed = (MathAbs(candidate.swing_high - g_locked_fib.swing_high) > _Point ||
                        MathAbs(candidate.swing_low  - g_locked_fib.swing_low)  > _Point);
        g_locked_fib  = candidate;
        g_locked_hbar = anchor.high_bar;
        g_locked_lbar = anchor.low_bar;
        g_locked_geom = anchor.geom_score;
        g_locked_sr   = anchor.fib_sr_score;
        g_locked_ol   = anchor.sr_overlap_count;
        g_is_locked   = true;
        if(changed) { anchor_changed = true; lock_event = "UPDATE_NO_LOCK"; }
    }

    //----------------------------------------------------------------
    //  畫線 + Logging
    //----------------------------------------------------------------
    if(g_is_locked)
    {
        DrawAllFibLines(g_locked_fib);

        double current_price = close[rates_total - 1];

        // 每 bar log
        if(InpLogBarCSV && g_bar_csv != INVALID_HANDLE)
        {
            // 建立臨時 PIPAnchorResult 用於 log（用鎖定值填充）
            PIPAnchorResult log_anchor;
            log_anchor.high             = g_locked_fib.swing_high;
            log_anchor.low              = g_locked_fib.swing_low;
            log_anchor.high_bar         = g_locked_hbar;
            log_anchor.low_bar          = g_locked_lbar;
            log_anchor.range_pips       = (g_locked_fib.swing_high - g_locked_fib.swing_low) / pip_size;
            log_anchor.geom_score       = g_locked_geom;
            log_anchor.fib_sr_score     = g_locked_sr;
            log_anchor.sr_overlap_count = g_locked_ol;
            log_anchor.range_ok         = true;
            WriteBarRow(bar_time, current_price, g_locked_fib, log_anchor, atr, InpUseLock && g_is_locked);
        }

        // 錨點變化 log
        if(InpLogAnchorCSV && g_anchor_csv != INVALID_HANDLE && anchor_changed && anchor.valid)
        {
            FibLevels log_fib = CalcFibLevels(anchor.high, anchor.low, InpIsBuy);
            WriteAnchorRow(bar_time, log_fib, anchor, lock_event);
        }

        // Journal
        if(InpPrintLog)
        {
            PrintFormat("=== FibPIP | %s | %s | %s | %s ===",
                        _Symbol, InpIsBuy ? "BUY" : "SELL",
                        DistModeStr(InpDistMode),
                        TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
            PrintFormat("  錨點 | H:%.5f(bar%d) L:%.5f(bar%d) Range:%.1f pips GeomScore:%.1f%s",
                        g_locked_fib.swing_high, g_locked_hbar,
                        g_locked_fib.swing_low,  g_locked_lbar,
                        (g_locked_fib.swing_high - g_locked_fib.swing_low) / pip_size,
                        g_locked_geom,
                        InpUseSR ? StringFormat(" SR:%.1f OL:%d", g_locked_sr, g_locked_ol) : "");
            PrintFormat("  Fib  | 0.382:%.5f  0.500:%.5f  0.618:%.5f",
                        g_locked_fib.fib_382, g_locked_fib.fib_500, g_locked_fib.fib_618);

            string near_label; double near_price;
            if(IsFibNear(current_price, g_locked_fib, threshold, near_label, near_price))
                PrintFormat("  >>> 接近 Fib %s (%.5f) — 當前: %.5f  距離: %.1f pips",
                            near_label, near_price, current_price,
                            MathAbs(current_price - near_price) / pip_size);
        }
    }
    else if(InpPrintLog)
    {
        if(!anchor.valid)
            Print("  [FibPIP] 搵唔到錨點 — 調整 Order/Window/MinRange 或切換方向");
        else if(!anchor.range_ok)
            PrintFormat("  [FibPIP] Range 太細：%.1f pips（需要 >= %.1f）",
                        anchor.range_pips, InpMinRangePips);
        else if(InpUseSR && anchor.sr_overlap_count < 1)
            PrintFormat("  [FibPIP] S/R 重疊不足（0 個），唔鎖定");
    }

    return rates_total;
}
