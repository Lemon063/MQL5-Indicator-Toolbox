//+------------------------------------------------------------------+
//|  Fibonacci_M5_OptB.mq5                                           |
//|  MQL5 Indicator Toolbox                                          |
//|  Option B：無鎖定，每 bar 重新計錨點                             |
//|  靈敏度優先，雜音交 H1 Fib 過濾                                  |
//|  v1.00：CSV logging 同 Option A 格式一致                         |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "1.00"
#property description "M5 Fib Option B — No lock. Recalculates every bar. Sensitive to turning points."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Toolbox/Fibonacci.mqh>

//--- Inputs: Pivot
input int    InpPivotN       = 5;
input int    InpPivotLook    = 96;

//--- Inputs: S/R
input int    InpSRLookback   = 100;
input double InpSRZonePips   = 10.0;
input int    InpSRMinCount   = 4;
input double InpSRTolPips    = 10.0;

//--- Inputs: Fib
input bool   InpIsBuy          = true;
input bool   InpShowExtensions = true;
input double InpAtrMult        = 0.20;
input int    InpAtrPeriod      = 14;
input int    InpLineLookback   = 100;
input double InpMinRangePips   = 10.0;  // 有意義嘅最小波段

//--- Inputs: CSV
input bool   InpLogBarCSV    = true;
input bool   InpLogAnchorCSV = true;
input string InpLogFolder    = "FibM5B_Logs";

//--- Inputs: Display
input bool   InpPrintLog     = true;

//--- Globals
const string PREFIX       = "FIB_M5B_LINE_";
const string PREFIX_LABEL = "FIB_M5B_LBL_";
int       g_atrHandle = INVALID_HANDLE;
int       g_bar_csv    = INVALID_HANDLE;
int       g_anchor_csv = INVALID_HANDLE;

// 上一次錨點（用嚟 detect 錨點變化）
double g_prev_high = 0;
double g_prev_low  = 0;

//+------------------------------------------------------------------+
//|  CSV 工具                                                        |
//+------------------------------------------------------------------+
bool EnsureLogFolder() { FolderCreate(InpLogFolder, FILE_COMMON); return true; }

string BuildFilePath(string suffix)
{
    string sym = _Symbol; StringReplace(sym, ".", "_");
    string tf  = EnumToString(Period()); StringReplace(tf, "PERIOD_", "");
    return InpLogFolder + "\\" + sym + "_" + tf + "_"
           + (InpIsBuy ? "BUY" : "SELL")
           + "_N" + IntegerToString(InpPivotN)
           + "_L" + IntegerToString(InpPivotLook)
           + "_PSR_B_" + suffix + ".csv";
}

void WriteBarHeader()
{
    if(g_bar_csv == INVALID_HANDLE) return;
    FileWriteString(g_bar_csv,
        "datetime,symbol,timeframe,direction,method,"
        "current_price,"
        "anchor_high,anchor_low,anchor_high_bar,anchor_low_bar,"
        "range_pips,sr_score,sr_overlap,"
        "fib_236,fib_382,fib_500,fib_618,fib_786,"
        "fib_1000,fib_1618,fib_2618,fib_3618,"
        "atr,anchor_changed\n");
}

void WriteAnchorHeader()
{
    if(g_anchor_csv == INVALID_HANDLE) return;
    FileWriteString(g_anchor_csv,
        "datetime,symbol,timeframe,direction,method,"
        "anchor_high,anchor_low,anchor_high_bar,anchor_low_bar,"
        "range_pips,sr_score,sr_overlap,range_ok,"
        "fib_236,fib_382,fib_500,fib_618,fib_786,"
        "fib_1000,fib_1618,fib_2618,fib_3618,"
        "event\n");
}

string MetaPfx()
{
    string tf = EnumToString(Period()); StringReplace(tf, "PERIOD_", "");
    return _Symbol + "," + tf + "," + (InpIsBuy ? "BUY" : "SELL") + ",PSR_B,";
}

string FibStr(const FibLevels &f)
{
    return DoubleToString(f.fib_236,5)+","+DoubleToString(f.fib_382,5)+","
          +DoubleToString(f.fib_500,5)+","+DoubleToString(f.fib_618,5)+","
          +DoubleToString(f.fib_786,5)+","+DoubleToString(f.fib_1000,5)+","
          +DoubleToString(f.fib_1618,5)+","+DoubleToString(f.fib_2618,5)+","
          +DoubleToString(f.fib_3618,5);
}

void WriteBarRow(datetime dt, double price, double atr,
                 const FibLevels &f, const AnchorResult &a,
                 double sr_score, int sr_ol, bool changed)
{
    if(g_bar_csv == INVALID_HANDLE) return;
    double pip = GetPipSize(_Symbol);
    string row = TimeToString(dt,TIME_DATE|TIME_MINUTES|TIME_SECONDS)+","
               + MetaPfx()
               + DoubleToString(price,5)+","
               + DoubleToString(f.swing_high,5)+","
               + DoubleToString(f.swing_low,5)+","
               + IntegerToString(a.high_bar)+","
               + IntegerToString(a.low_bar)+","
               + DoubleToString((f.swing_high-f.swing_low)/pip,2)+","
               + DoubleToString(sr_score,2)+","
               + IntegerToString(sr_ol)+","
               + FibStr(f)+","
               + DoubleToString(atr,5)+","
               + (changed?"1":"0")+"\n";
    FileWriteString(g_bar_csv, row);
    FileFlush(g_bar_csv);
}

void WriteAnchorRow(datetime dt, const FibLevels &f,
                    const AnchorResult &a,
                    double sr_score, int sr_ol, string event)
{
    if(g_anchor_csv == INVALID_HANDLE) return;
    double pip = GetPipSize(_Symbol);
    string row = TimeToString(dt,TIME_DATE|TIME_MINUTES|TIME_SECONDS)+","
               + MetaPfx()
               + DoubleToString(f.swing_high,5)+","
               + DoubleToString(f.swing_low,5)+","
               + IntegerToString(a.high_bar)+","
               + IntegerToString(a.low_bar)+","
               + DoubleToString((f.swing_high-f.swing_low)/pip,2)+","
               + DoubleToString(sr_score,2)+","
               + IntegerToString(sr_ol)+","
               + (a.range_ok?"1":"0")+","
               + FibStr(f)+","
               + event+"\n";
    FileWriteString(g_anchor_csv, row);
    FileFlush(g_anchor_csv);
}

//+------------------------------------------------------------------+
//|  Chart 畫線                                                      |
//+------------------------------------------------------------------+
void DrawLine(string name, double price, color clr,
              ENUM_LINE_STYLE style, int width, string tip)
{
    string   obj     = PREFIX + name;
    datetime t_end   = iTime(_Symbol, PERIOD_CURRENT, 0);
    datetime t_start = iTime(_Symbol, PERIOD_CURRENT, InpLineLookback);
    if(ObjectFind(0,obj)<0)
        ObjectCreate(0,obj,OBJ_TREND,0,t_start,price,t_end,price);
    ObjectSetInteger(0,obj,OBJPROP_TIME,0,t_start);
    ObjectSetInteger(0,obj,OBJPROP_TIME,1,t_end);
    ObjectSetDouble(0,obj,OBJPROP_PRICE,0,price);
    ObjectSetDouble(0,obj,OBJPROP_PRICE,1,price);
    ObjectSetInteger(0,obj,OBJPROP_COLOR,clr);
    ObjectSetInteger(0,obj,OBJPROP_STYLE,style);
    ObjectSetInteger(0,obj,OBJPROP_WIDTH,width);
    ObjectSetString(0,obj,OBJPROP_TOOLTIP,tip);
    ObjectSetInteger(0,obj,OBJPROP_SELECTABLE,false);
    ObjectSetInteger(0,obj,OBJPROP_RAY_RIGHT,false);
    ObjectSetInteger(0,obj,OBJPROP_BACK,true);
}

void DrawLabel(string name, double price, color clr, string text)
{
    string   obj = PREFIX_LABEL + name;
    datetime t   = iTime(_Symbol,PERIOD_CURRENT,5);
    if(ObjectFind(0,obj)<0)
        ObjectCreate(0,obj,OBJ_TEXT,0,t,price);
    ObjectSetInteger(0,obj,OBJPROP_TIME,t);
    ObjectSetDouble(0,obj,OBJPROP_PRICE,price);
    ObjectSetString(0,obj,OBJPROP_TEXT,text);
    ObjectSetInteger(0,obj,OBJPROP_COLOR,clr);
    ObjectSetInteger(0,obj,OBJPROP_FONTSIZE,8);
    ObjectSetString(0,obj,OBJPROP_FONT,"Arial");
    ObjectSetInteger(0,obj,OBJPROP_SELECTABLE,false);
    ObjectSetInteger(0,obj,OBJPROP_BACK,false);
}

void DeleteAllObjects()
{
    int total = ObjectsTotal(0,0,OBJ_TREND);
    for(int i=total-1;i>=0;i--)
    {
        string nm = ObjectName(0,i,0,OBJ_TREND);
        if(StringFind(nm,PREFIX)==0) ObjectDelete(0,nm);
    }
    total = ObjectsTotal(0,0,OBJ_TEXT);
    for(int i=total-1;i>=0;i--)
    {
        string nm = ObjectName(0,i,0,OBJ_TEXT);
        if(StringFind(nm,PREFIX_LABEL)==0) ObjectDelete(0,nm);
    }
}

void DrawFibSet(string name, double price, color clr,
                ENUM_LINE_STYLE style, int width, string lvl)
{
    string text = "[B] " + lvl + "  " + DoubleToString(price,5);
    DrawLine(name, price, clr, style, width, text);
    DrawLabel(name, price, clr, text);
}

void DrawAllFibLines(const FibLevels &f)
{
    DrawFibSet("SH",  f.swing_high, clrWhite,       STYLE_DOT,  1, "1.000");
    DrawFibSet("SL",  f.swing_low,  clrSkyBlue,     STYLE_DOT,  1, "0.000");
    DrawFibSet("236", f.fib_236,    clrGold,        STYLE_DASH, 1, "0.236");
    DrawFibSet("382", f.fib_382,    clrOrange,      STYLE_DASH, 1, "0.382");
    DrawFibSet("500", f.fib_500,    clrDarkOrange,  STYLE_SOLID,1, "0.500");
    DrawFibSet("618", f.fib_618,    clrOrangeRed,   STYLE_SOLID,2, "0.618");
    DrawFibSet("786", f.fib_786,    clrRed,         STYLE_SOLID,1, "0.786");
    if(InpShowExtensions)
    {
        DrawFibSet("1618",f.fib_1618,clrMediumPurple,STYLE_DASH,1,"1.618");
        DrawFibSet("2618",f.fib_2618,clrPurple,      STYLE_DASH,1,"2.618");
        DrawFibSet("3618",f.fib_3618,clrDarkViolet,  STYLE_SOLID,2,"3.618");
    }
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
int OnInit()
{
    g_atrHandle = iATR(_Symbol,PERIOD_CURRENT,InpAtrPeriod);
    if(g_atrHandle==INVALID_HANDLE){ Print("ERROR: iATR failed"); return INIT_FAILED; }

    EnsureLogFolder();
    if(InpLogBarCSV)
    {
        g_bar_csv = FileOpen(BuildFilePath("bar"),
                             FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,',');
        if(g_bar_csv!=INVALID_HANDLE) WriteBarHeader();
    }
    if(InpLogAnchorCSV)
    {
        g_anchor_csv = FileOpen(BuildFilePath("anchor"),
                                FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,',');
        if(g_anchor_csv!=INVALID_HANDLE) WriteAnchorHeader();
    }

    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("Fib_M5B(%s,N=%d)",InpIsBuy?"BUY":"SELL",InpPivotN));

    PrintFormat("✅ Fib_M5B (Option B) 初始化 | Bar CSV: %s",
                g_bar_csv!=INVALID_HANDLE ? BuildFilePath("bar") : "OFF");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    DeleteAllObjects();
    if(g_atrHandle!=INVALID_HANDLE){ IndicatorRelease(g_atrHandle); g_atrHandle=INVALID_HANDLE; }
    if(g_bar_csv!=INVALID_HANDLE){ FileClose(g_bar_csv); g_bar_csv=INVALID_HANDLE; }
    if(g_anchor_csv!=INVALID_HANDLE){ FileClose(g_anchor_csv); g_anchor_csv=INVALID_HANDLE; }
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
    if(rates_total < InpPivotLook + InpPivotN*2 + 2) return 0;

    ArraySetAsSeries(time,true);
    static datetime last_bar_time = 0;
    if(time[0]==last_bar_time) return rates_total;
    last_bar_time = time[0];

    double atr_buf[];
    ArraySetAsSeries(atr_buf,true);
    double atr = 0;
    if(CopyBuffer(g_atrHandle,0,1,1,atr_buf)>0) atr=atr_buf[0];

    double pip       = GetPipSize(_Symbol);
    double threshold = atr * InpAtrMult;
    datetime bar_time = time[1];

    //--- 每 bar 搵錨點
    //    用 ANCHOR_H1 評分邏輯（波段完整性 + S/R強度優先）
    //    但係喺 M5 timeframe 嘅 8 小時窗口（InpPivotLook=96 bars）內搵
    //    唔係距離優先，係最適合嘅完整波段
    AnchorResult anchor = GetAnchorPoints(
        _Symbol, PERIOD_CURRENT, ANCHOR_H1,
        InpIsBuy,
        InpPivotN, InpPivotLook,
        InpSRLookback, InpSRZonePips,
        InpSRMinCount, InpSRTolPips,
        InpMinRangePips, 1);

    if(!anchor.valid)
    {
        if(InpPrintLog)
            Print("[M5B] 搵唔到錨點");
        return rates_total;
    }

    FibLevels f = CalcFibLevels(anchor.high, anchor.low, InpIsBuy);

    //--- S/R score（做 log 用，唔做篩選）
    SRResult sr  = CalcSRZones(_Symbol,PERIOD_CURRENT,InpSRLookback,InpSRZonePips,InpSRMinCount,1);
    double   tol = InpSRTolPips * pip;
    int      sr_ol  = 0;
    double   sr_score = CalcFibSRScore(f, sr, tol, sr_ol, anchor.range_ok);

    //--- 錨點有冇改變
    bool changed = (MathAbs(anchor.high - g_prev_high) > _Point ||
                    MathAbs(anchor.low  - g_prev_low)  > _Point);
    if(changed)
    {
        g_prev_high = anchor.high;
        g_prev_low  = anchor.low;
        if(InpLogAnchorCSV)
            WriteAnchorRow(bar_time, f, anchor, sr_score, sr_ol, "UPDATE");
        if(InpPrintLog)
            PrintFormat("[M5B] 錨點更新 | H:%.5f(bar%d) L:%.5f(bar%d) Range:%.1f SR:%.1f OL:%d",
                        anchor.high, anchor.high_bar,
                        anchor.low,  anchor.low_bar,
                        (anchor.high-anchor.low)/pip, sr_score, sr_ol);
    }

    //--- 畫線
    DrawAllFibLines(f);

    //--- Bar log
    if(InpLogBarCSV)
        WriteBarRow(bar_time, close[rates_total-1], atr, f, anchor, sr_score, sr_ol, changed);

    //--- Journal
    if(InpPrintLog)
    {
        string near_label; double near_price;
        if(IsFibNear(close[rates_total-1], f, threshold, near_label, near_price))
            PrintFormat("[M5B] 接近 Fib %s (%.5f) 距離:%.1f pips",
                        near_label, near_price,
                        MathAbs(close[rates_total-1]-near_price)/pip);
    }

    return rates_total;
}
