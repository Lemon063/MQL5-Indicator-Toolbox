//+------------------------------------------------------------------+
//|  Fibonacci_PIP_OptB.mq5                                          |
//|  MQL5 Indicator Toolbox                                          |
//|  Option B：無鎖定，每 bar 重新計 PIP 錨點                        |
//|  靈敏度優先，雜音交 H1 Fib 過濾                                  |
//|  v1.00：CSV logging 同 Option A 格式一致                         |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "1.00"
#property description "PIP Fib Option B — No lock. Recalculates every bar. Sensitive to turning points."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Toolbox/FibPIP.mqh>
#include <Toolbox/FibTypes.mqh>
#include <Toolbox/Fibonacci.mqh>

//--- Inputs: PIP
input int           InpPIPOrder     = 5;
input int           InpWindowSize   = 96;
input ENUM_PIP_DIST InpDistMode     = PIP_VER_DIS;
input double        InpMinRangePips = 5.0;   // 放寬，增加靈敏度

//--- Inputs: S/R
input bool          InpUseSR        = true;
input int           InpSRLookback   = 100;
input double        InpSRZonePips   = 10.0;
input int           InpSRMinCount   = 4;
input double        InpSRTolPips    = 10.0;

//--- Inputs: Fib
input bool          InpIsBuy          = true;
input bool          InpShowExtensions = true;
input double        InpAtrMult        = 0.20;
input int           InpAtrPeriod      = 14;
input int           InpLineLookback   = 100;

//--- Inputs: CSV
input bool          InpLogBarCSV    = true;
input bool          InpLogAnchorCSV = true;
input string        InpLogFolder    = "FibPIPB_Logs";

//--- Inputs: Display
input bool          InpPrintLog     = true;

//--- Globals
const string PREFIX       = "PIP_B_LINE_";
const string PREFIX_LABEL = "PIP_B_LBL_";
int    g_atrHandle  = INVALID_HANDLE;
int    g_bar_csv    = INVALID_HANDLE;
int    g_anchor_csv = INVALID_HANDLE;
double g_prev_high  = 0;
double g_prev_low   = 0;

//+------------------------------------------------------------------+
//|  CSV 工具                                                        |
//+------------------------------------------------------------------+
bool EnsureLogFolder() { FolderCreate(InpLogFolder, FILE_COMMON); return true; }

string DistStr(ENUM_PIP_DIST m)
{ switch(m){case PIP_EUC_DIS:return "EUC";case PIP_PER_DIS:return "PER";default:return "VER";} }

string BuildFilePath(string suffix)
{
    string sym = _Symbol; StringReplace(sym,".","-");
    string tf  = EnumToString(Period()); StringReplace(tf,"PERIOD_","");
    return InpLogFolder+"\\"+sym+"_"+tf+"_"+(InpIsBuy?"BUY":"SELL")
           +"_O"+IntegerToString(InpPIPOrder)
           +"_W"+IntegerToString(InpWindowSize)
           +"_"+DistStr(InpDistMode)
           +"_PIP_B_"+suffix+".csv";
}

void WriteBarHeader()
{
    if(g_bar_csv==INVALID_HANDLE) return;
    FileWriteString(g_bar_csv,
        "datetime,symbol,timeframe,direction,method,"
        "current_price,"
        "anchor_high,anchor_low,anchor_high_bar,anchor_low_bar,"
        "range_pips,geom_score,fib_sr_score,sr_overlap,"
        "fib_236,fib_382,fib_500,fib_618,fib_786,"
        "fib_1000,fib_1618,fib_2618,fib_3618,"
        "atr,anchor_changed\n");
}

void WriteAnchorHeader()
{
    if(g_anchor_csv==INVALID_HANDLE) return;
    FileWriteString(g_anchor_csv,
        "datetime,symbol,timeframe,direction,method,"
        "anchor_high,anchor_low,anchor_high_bar,anchor_low_bar,"
        "range_pips,geom_score,fib_sr_score,sr_overlap,range_ok,"
        "fib_236,fib_382,fib_500,fib_618,fib_786,"
        "fib_1000,fib_1618,fib_2618,fib_3618,"
        "event\n");
}

string MetaPfx()
{
    string tf = EnumToString(Period()); StringReplace(tf,"PERIOD_","");
    return _Symbol+","+tf+","+(InpIsBuy?"BUY":"SELL")+",PIP_B,";
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
                 const FibLevels &f, const PIPAnchorResult &a, bool changed)
{
    if(g_bar_csv==INVALID_HANDLE) return;
    double pip = GetPipSize(_Symbol);
    string row = TimeToString(dt,TIME_DATE|TIME_MINUTES|TIME_SECONDS)+","
               + MetaPfx()
               + DoubleToString(price,5)+","
               + DoubleToString(f.swing_high,5)+","
               + DoubleToString(f.swing_low,5)+","
               + IntegerToString(a.high_bar)+","
               + IntegerToString(a.low_bar)+","
               + DoubleToString(a.range_pips,2)+","
               + DoubleToString(a.geom_score,2)+","
               + DoubleToString(a.fib_sr_score,2)+","
               + IntegerToString(a.sr_overlap_count)+","
               + FibStr(f)+","
               + DoubleToString(atr,5)+","
               + (changed?"1":"0")+"\n";
    FileWriteString(g_bar_csv,row);
    FileFlush(g_bar_csv);
}

void WriteAnchorRow(datetime dt, const FibLevels &f,
                    const PIPAnchorResult &a, string event)
{
    if(g_anchor_csv==INVALID_HANDLE) return;
    string row = TimeToString(dt,TIME_DATE|TIME_MINUTES|TIME_SECONDS)+","
               + MetaPfx()
               + DoubleToString(f.swing_high,5)+","
               + DoubleToString(f.swing_low,5)+","
               + IntegerToString(a.high_bar)+","
               + IntegerToString(a.low_bar)+","
               + DoubleToString(a.range_pips,2)+","
               + DoubleToString(a.geom_score,2)+","
               + DoubleToString(a.fib_sr_score,2)+","
               + IntegerToString(a.sr_overlap_count)+","
               + (a.range_ok?"1":"0")+","
               + FibStr(f)+","
               + event+"\n";
    FileWriteString(g_anchor_csv,row);
    FileFlush(g_anchor_csv);
}

//+------------------------------------------------------------------+
//|  Chart 畫線（青色系，同 Option A PIP 區分）                      |
//+------------------------------------------------------------------+
void DrawLine(string name, double price, color clr,
              ENUM_LINE_STYLE style, int width, string tip)
{
    string   obj     = PREFIX+name;
    datetime t_end   = iTime(_Symbol,PERIOD_CURRENT,0);
    datetime t_start = iTime(_Symbol,PERIOD_CURRENT,InpLineLookback);
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
    string   obj = PREFIX_LABEL+name;
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
    { string nm=ObjectName(0,i,0,OBJ_TREND); if(StringFind(nm,PREFIX)==0) ObjectDelete(0,nm); }
    total = ObjectsTotal(0,0,OBJ_TEXT);
    for(int i=total-1;i>=0;i--)
    { string nm=ObjectName(0,i,0,OBJ_TEXT); if(StringFind(nm,PREFIX_LABEL)==0) ObjectDelete(0,nm); }
}

void DrawFibSet(string name, double price, color clr, ENUM_LINE_STYLE style, int width, string lvl)
{
    string text = "[PIP-B] "+lvl+"  "+DoubleToString(price,5);
    DrawLine(name,price,clr,style,width,text);
    DrawLabel(name,price,clr,text);
}

void DrawAllFibLines(const FibLevels &f)
{
    DrawFibSet("SH",  f.swing_high, clrAqua,         STYLE_DOT,  1,"1.000");
    DrawFibSet("SL",  f.swing_low,  clrLightSkyBlue, STYLE_DOT,  1,"0.000");
    DrawFibSet("236", f.fib_236,    clrYellow,        STYLE_DASH, 1,"0.236");
    DrawFibSet("382", f.fib_382,    clrYellowGreen,   STYLE_DASH, 1,"0.382");
    DrawFibSet("500", f.fib_500,    clrLime,          STYLE_SOLID,1,"0.500");
    DrawFibSet("618", f.fib_618,    clrLimeGreen,     STYLE_SOLID,2,"0.618");
    DrawFibSet("786", f.fib_786,    clrGreen,         STYLE_SOLID,1,"0.786");
    if(InpShowExtensions)
    {
        DrawFibSet("1618",f.fib_1618,clrPlum,         STYLE_DASH, 1,"1.618");
        DrawFibSet("2618",f.fib_2618,clrOrchid,       STYLE_DASH, 1,"2.618");
        DrawFibSet("3618",f.fib_3618,clrMediumOrchid, STYLE_SOLID,2,"3.618");
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
        StringFormat("FibPIP_B(%s,O=%d,W=%d,%s)",
                     InpIsBuy?"BUY":"SELL",InpPIPOrder,InpWindowSize,DistStr(InpDistMode)));

    PrintFormat("✅ FibPIP_B (Option B) 初始化 | Bar CSV: %s",
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
    if(rates_total < InpWindowSize + 10) return 0;

    ArraySetAsSeries(time,true);
    static datetime last_bar_time = 0;
    if(time[0]==last_bar_time) return rates_total;
    last_bar_time = time[0];

    double atr_buf[];
    ArraySetAsSeries(atr_buf,true);
    double atr = 0;
    if(CopyBuffer(g_atrHandle,0,1,1,atr_buf)>0) atr=atr_buf[0];

    double pip_size  = GetPipSize(_Symbol);
    double threshold = atr * InpAtrMult;
    datetime bar_time = time[1];

    //--- 每 bar 直接用 PIP 算法搵錨點
    //    唔 call GetAnchorPoints_PIP()，因為佢入面嘅 FindPIPAnchors 有方向性驗證
    //    忠實於原版 pip_algo_us.py：搵幾何距離最大嘅轉角點，取最高同最低做錨點

    double prices[];
    ArraySetAsSeries(prices, true);
    int copied = CopyClose(_Symbol, PERIOD_CURRENT, 0, 1 + InpWindowSize + 1, prices);
    if(copied < 1 + InpWindowSize) return rates_total;

    int start_bar = 1 + InpWindowSize - 1;  // 舊端
    int end_bar   = 1;                       // 新端（shift=1，唔用未收市 bar）

    PIPResult pip;
    if(!CalcPIPPoints(prices, start_bar, end_bar, InpPIPOrder, InpDistMode, pip))
    {
        if(InpPrintLog) Print("[PIP-B] CalcPIPPoints 失敗");
        return rates_total;
    }

    // 搵最高同最低 PIP 點（冇方向性驗證）
    double best_high = -DBL_MAX, best_low = DBL_MAX;
    int    best_high_bar = -1,   best_low_bar = -1;
    for(int i = 0; i < pip.count; i++)
    {
        if(pip.points[i].price > best_high)
        {
            best_high     = pip.points[i].price;
            best_high_bar = pip.points[i].bar;
        }
        if(pip.points[i].price < best_low)
        {
            best_low     = pip.points[i].price;
            best_low_bar = pip.points[i].bar;
        }
    }

    if(best_high_bar < 0 || best_low_bar < 0 || best_high <= best_low)
    {
        if(InpPrintLog) Print("[PIP-B] 搵唔到有效 High/Low");
        return rates_total;
    }

    double range_pips = (best_high - best_low) / pip_size;
    if(InpMinRangePips > 0 && range_pips < InpMinRangePips)
    {
        if(InpPrintLog)
            PrintFormat("[PIP-B] Range 太細：%.1f pips（需要 >= %.1f）", range_pips, InpMinRangePips);
        return rates_total;
    }

    // 填充 PIPAnchorResult 做 log 用
    PIPAnchorResult anchor;
    anchor.high             = best_high;
    anchor.low              = best_low;
    anchor.high_bar         = best_high_bar;
    anchor.low_bar          = best_low_bar;
    anchor.range_pips       = range_pips;
    anchor.geom_score       = range_pips;
    anchor.range_ok         = true;
    anchor.valid            = true;
    anchor.pip_order        = InpPIPOrder;
    anchor.window_size      = InpWindowSize;
    anchor.dist_mode        = InpDistMode;
    anchor.sr_used          = InpUseSR;
    anchor.fib_sr_score     = 0;
    anchor.sr_overlap_count = 0;

    // S/R 評分（選用）
    if(InpUseSR)
    {
        SRResult sr = CalcSRZones(_Symbol, PERIOD_CURRENT,
                                  InpSRLookback, InpSRZonePips, InpSRMinCount, 1);
        double tol = InpSRTolPips * pip_size;
        FibLevels f_tmp = CalcFibLevels(best_high, best_low, InpIsBuy);
        int ol = 0;
        anchor.fib_sr_score    = CalcFibSRScore_PIP(f_tmp, sr, tol, ol, true);
        anchor.sr_overlap_count = ol;
    }

    FibLevels f = CalcFibLevels(anchor.high, anchor.low, InpIsBuy);

    //--- 錨點有冇改變
    bool changed = (MathAbs(anchor.high - g_prev_high) > _Point ||
                    MathAbs(anchor.low  - g_prev_low)  > _Point);
    if(changed)
    {
        g_prev_high = anchor.high;
        g_prev_low  = anchor.low;
        if(InpLogAnchorCSV)
            WriteAnchorRow(bar_time, f, anchor, "UPDATE");
        if(InpPrintLog)
            PrintFormat("[PIP-B] 錨點更新 | H:%.5f(bar%d) L:%.5f(bar%d) Range:%.1f SR:%.1f OL:%d",
                        anchor.high, anchor.high_bar,
                        anchor.low,  anchor.low_bar,
                        anchor.range_pips, anchor.fib_sr_score, anchor.sr_overlap_count);
    }

    //--- 畫線
    DrawAllFibLines(f);

    //--- Bar log
    if(InpLogBarCSV)
        WriteBarRow(bar_time, close[rates_total-1], atr, f, anchor, changed);

    //--- Journal
    if(InpPrintLog)
    {
        string near_label; double near_price;
        if(IsFibNear(close[rates_total-1], f, threshold, near_label, near_price))
            PrintFormat("[PIP-B] 接近 Fib %s (%.5f) 距離:%.1f pips",
                        near_label, near_price,
                        MathAbs(close[rates_total-1]-near_price)/pip_size);
    }

    return rates_total;
}
