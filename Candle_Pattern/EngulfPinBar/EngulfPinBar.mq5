//+------------------------------------------------------------------+
//|  EngulfPinBar.mq5                                                |
//|  MQL5 Indicator Toolbox                                          |
//|  視覺圖表 indicator — attach 到 chart 驗證邏輯                    |
//|  圖表畫箭咀標記 pattern，Journal 印出詳細數值，CSV log             |
//|  依賴 Depends on: ATR.mqh (via EngulfPinBar.mqh)                |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "1.00"
#property description "Engulfing + Pin Bar detection. Arrows on chart + Journal + CSV."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- 看漲箭咀（綠色，向上）
#property indicator_label1  "看漲信號 Bullish"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  2

//--- 看跌箭咀（紅色，向下）
#property indicator_label2  "看跌信號 Bearish"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2

#include <Toolbox/EngulfPinBar.mqh>

//--- Inputs
input double InpPinBodyMulti  = 2.0;   // Pin Bar：影線倍數 / Shadow multiplier
input double InpPinOppMulti   = 0.5;   // Pin Bar：反向影線上限 / Opposite shadow limit
input double InpMinBodyPips   = 0.5;   // 最小燭身 pips / Min body pips (Doji filter)
input bool   InpBarLatch      = true;  // 每 bar 只接受一個信號 / One signal per bar
input bool   InpPrintLog      = true;  // 輸出至 Journal / Print to Journal
input bool   InpLogToFile     = true;  // 輸出至 CSV / Write CSV
input string InpLogFile       = "CandleSignals.csv"; // CSV 檔案名

//--- Buffers
double Buffer_Bull[];   // 看漲箭咀位置（bar Low 下方）
double Buffer_Bear[];   // 看跌箭咀位置（bar High 上方）

//--- State
int      g_fileHandle     = INVALID_HANDLE;
datetime g_lastSigBarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
    SetIndexBuffer(0, Buffer_Bull, INDICATOR_DATA);
    SetIndexBuffer(1, Buffer_Bear, INDICATOR_DATA);

    ArraySetAsSeries(Buffer_Bull, true);
    ArraySetAsSeries(Buffer_Bear, true);

    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

    //--- 箭咀形狀：233 = 向上三角，234 = 向下三角
    PlotIndexSetInteger(0, PLOT_ARROW, 233);
    PlotIndexSetInteger(1, PLOT_ARROW, 234);

    if(InpLogToFile)
    {
        g_fileHandle = FileOpen(InpLogFile, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
        if(g_fileHandle != INVALID_HANDLE)
            FileWrite(g_fileHandle,
                      "serverTime", "bar1Time", "bar2Time",
                      "BullEngulf", "BearEngulf",
                      "BullPin",    "BearPin",
                      "detected",   "direction");
    }

    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("EngulfPinBar(%.1f,%.1f,%.1f)",
                     InpPinBodyMulti, InpPinOppMulti, InpMinBodyPips));

    PrintFormat("初始化完成 Initialized | %s | PinMult=%.1f OppMult=%.1f MinBody=%.1f pips",
                _Symbol, InpPinBodyMulti, InpPinOppMulti, InpMinBodyPips);

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(g_fileHandle != INVALID_HANDLE)
    {
        FileClose(g_fileHandle);
        g_fileHandle = INVALID_HANDLE;
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
    if(rates_total < 5)
        return 0;

    ArraySetAsSeries(time,  true);
    ArraySetAsSeries(high,  true);
    ArraySetAsSeries(low,   true);

    int start = (prev_calculated == 0) ? rates_total - 1 : prev_calculated;

    //--- 初始化 buffer
    for(int i = start; i >= 0; i--)
    {
        Buffer_Bull[i] = EMPTY_VALUE;
        Buffer_Bear[i] = EMPTY_VALUE;
    }

    //--- 只喺新 bar 做 detection
    if(prev_calculated == rates_total)
        return rates_total;

    //--- Pattern detection
    CandleSignal sig = DetectCandlePattern(_Symbol, PERIOD_M5,
                                           InpPinBodyMulti,
                                           InpPinOppMulti,
                                           InpMinBodyPips);

    datetime bar1Time = iTime(_Symbol, PERIOD_M5, 1);
    datetime bar2Time = iTime(_Symbol, PERIOD_M5, 2);
    bool     accepted = false;

    if(sig.detected)
    {
        //--- Bar latch
        if(InpBarLatch && bar1Time == g_lastSigBarTime)
        {
            sig.detected  = false;
            sig.direction = "NONE";
        }
        else
        {
            accepted         = true;
            g_lastSigBarTime = bar1Time;

            //--- 畫箭咀：看漲喺 bar1 Low 下方，看跌喺 bar1 High 上方
            if(sig.direction == "BUY")
                Buffer_Bull[1] = low[1]  - GetPipSize(_Symbol) * 3;
            else
                Buffer_Bear[1] = high[1] + GetPipSize(_Symbol) * 3;
        }
    }

    //--- Journal log
    if(InpPrintLog)
    {
        CandleData b1 = GetCandleData(_Symbol, PERIOD_M5, 1);
        CandleData b2 = GetCandleData(_Symbol, PERIOD_M5, 2);
        double     pip = GetPipSize(_Symbol);

        PrintFormat("[EngulfPinBar 蠟燭形態] %s | bar1=%s",
                    _Symbol,
                    TimeToString(bar1Time, TIME_DATE|TIME_MINUTES));

        PrintFormat("  bar1 | O=%.5f H=%.5f L=%.5f C=%.5f | 燭身=%.1f pips | 上影=%.1f pips | 下影=%.1f pips | %s",
                    b1.open, b1.high, b1.low, b1.close,
                    b1.body      / pip,
                    b1.upperWick / pip,
                    b1.lowerWick / pip,
                    b1.bullish ? "陽燭" : (b1.bearish ? "陰燭" : "Doji"));

        PrintFormat("  bar2 | O=%.5f H=%.5f L=%.5f C=%.5f | %s",
                    b2.open, b2.high, b2.low, b2.close,
                    b2.bullish ? "陽燭" : (b2.bearish ? "陰燭" : "Doji"));

        PrintFormat("  形態 | 看漲吞噬=%d  看跌吞噬=%d  看漲針=%d  看跌針=%d",
                    (int)sig.bullEngulf, (int)sig.bearEngulf,
                    (int)sig.bullPin,    (int)sig.bearPin);

        PrintFormat("  結果 | 方向 Direction=%s  接受 Accepted=%d",
                    sig.direction, (int)accepted);
    }

    //--- CSV log
    if(InpLogToFile && g_fileHandle != INVALID_HANDLE)
    {
        FileWrite(g_fileHandle,
                  TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                  TimeToString(bar1Time, TIME_DATE|TIME_MINUTES),
                  TimeToString(bar2Time, TIME_DATE|TIME_MINUTES),
                  (int)sig.bullEngulf, (int)sig.bearEngulf,
                  (int)sig.bullPin,    (int)sig.bearPin,
                  (int)sig.detected,   sig.direction);
    }

    return rates_total;
}
