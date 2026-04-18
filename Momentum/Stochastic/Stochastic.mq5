//+------------------------------------------------------------------+
//|  Stochastic.mq5                                                  |
//|  MQL5 Indicator Toolbox                                          |
//|  視覺圖表 indicator — attach 到 chart 驗證邏輯                    |
//|  Sub-window 顯示 K/D 線，圖表畫箭咀，Journal 印出 cross + OB/OS  |
//|  CSV log 輸出同 Sandbox EA 一致，方便對比                         |
//+------------------------------------------------------------------+
#property copyright   "MQL5 Indicator Toolbox"
#property version     "1.00"
#property description "Stochastic K/D + cross detection + OB/OS. Prints to Journal + CSV."

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2

//--- K line（白色實線）
#property indicator_label1  "K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrWhite
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- D line（橙色虛線）
#property indicator_label2  "D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_DASH
#property indicator_width2  1

//--- OB / OS 水平線
#property indicator_level1  80.0
#property indicator_level2  20.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

#include <Toolbox/Stochastic.mqh>

//--- Inputs
input int    InpK          = 14;              // K 週期 / K period
input int    InpD          = 3;               // D 週期 / D period
input int    InpSmooth     = 3;               // 平滑 / Smooth
input double InpOB         = 80.0;            // 超買水平 / Overbought level
input double InpOS         = 20.0;            // 超賣水平 / Oversold level
input bool   InpBarLatch   = true;            // 每 bar 只接受一個信號 / One signal per bar
input bool   InpPrintLog   = true;            // 輸出至 Journal / Print to Journal
input bool   InpLogToFile  = true;            // 輸出至 CSV / Write CSV
input string InpLogFile    = "StochSignals.csv"; // CSV 檔案名

//--- Buffers
double Buffer_K[];
double Buffer_D[];
double Buffer_ArrowUp[];    // 金叉箭咀（畫喺 main chart window）
double Buffer_ArrowDown[];  // 死叉箭咀

//--- State
int      g_handle         = INVALID_HANDLE;
int      g_fileHandle     = INVALID_HANDLE;
datetime g_lastSigBarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
    SetIndexBuffer(0, Buffer_K,         INDICATOR_DATA);
    SetIndexBuffer(1, Buffer_D,         INDICATOR_DATA);
    SetIndexBuffer(2, Buffer_ArrowUp,   INDICATOR_DATA);
    SetIndexBuffer(3, Buffer_ArrowDown, INDICATOR_DATA);

    ArraySetAsSeries(Buffer_K,         true);
    ArraySetAsSeries(Buffer_D,         true);
    ArraySetAsSeries(Buffer_ArrowUp,   true);
    ArraySetAsSeries(Buffer_ArrowDown, true);

    //--- Arrow buffers 初始值設 EMPTY_VALUE
    PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

    g_handle = CreateStochHandle(_Symbol, PERIOD_M5, InpK, InpD, InpSmooth);
    if(g_handle == INVALID_HANDLE)
    {
        Print("錯誤 ERROR: iStochastic handle 建立失敗 for ", _Symbol);
        return INIT_FAILED;
    }

    if(InpLogToFile)
    {
        g_fileHandle = FileOpen(InpLogFile, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
        if(g_fileHandle != INVALID_HANDLE)
            FileWrite(g_fileHandle,
                      "serverTime",
                      "bar0Time", "bar1Time", "bar2Time",
                      "K0", "D0", "K1", "D1", "K2", "D2",
                      "crossUp", "crossDown",
                      "isOS", "isOB",
                      "direction");
    }

    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("Stoch(%d,%d,%d)", InpK, InpD, InpSmooth));

    PrintFormat("初始化完成 Initialized | %s | K=%d D=%d Sm=%d | OB=%.0f OS=%.0f | BarLatch=%s",
                _Symbol, InpK, InpD, InpSmooth, InpOB, InpOS,
                InpBarLatch ? "ON" : "OFF");

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(g_handle != INVALID_HANDLE)
    {
        IndicatorRelease(g_handle);
        g_handle = INVALID_HANDLE;
    }
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
    if(rates_total < InpK + InpD + InpSmooth + 5)
        return 0;

    ArraySetAsSeries(time, true);

    int start = (prev_calculated == 0) ? rates_total - 1 : prev_calculated;

    //--- 填充 K / D buffer
    for(int i = start; i >= 0; i--)
    {
        int shift = i;
        StochBar bar = GetStochValues(g_handle, shift);
        Buffer_K[i] = bar.K;
        Buffer_D[i] = bar.D;
        Buffer_ArrowUp[i]   = EMPTY_VALUE;
        Buffer_ArrowDown[i] = EMPTY_VALUE;
    }

    //--- 只喺新 bar 做 signal detection
    if(prev_calculated == rates_total)
        return rates_total;

    StochSignal sig = DetectStochSignal(g_handle, InpOB, InpOS);

    //--- Bar latch
    datetime bar1Time = iTime(_Symbol, PERIOD_M5, 1);
    string   direction = "NONE";
    bool     accepted  = false;

    if(sig.crossUp || sig.crossDown)
    {
        if(InpBarLatch && bar1Time == g_lastSigBarTime)
        {
            //--- 重複信號，拒絕
        }
        else
        {
            accepted          = true;
            g_lastSigBarTime  = bar1Time;
            direction         = sig.crossUp ? "BUY" : "SELL";

            //--- 畫箭咀喺 bar1
            if(sig.crossUp)
                Buffer_ArrowUp[1]   = Buffer_K[1];
            else
                Buffer_ArrowDown[1] = Buffer_K[1];
        }
    }

    //--- Journal log
    if(InpPrintLog)
    {
        datetime bar0Time = iTime(_Symbol, PERIOD_M5, 0);
        datetime bar2Time = iTime(_Symbol, PERIOD_M5, 2);

        PrintFormat("[Stoch 隨機指標] %s | bar1=%s",
                    _Symbol,
                    TimeToString(bar1Time, TIME_DATE|TIME_MINUTES));

        PrintFormat("  K值   | K0=%.2f  K1=%.2f  K2=%.2f",
                    sig.K0, sig.K1, sig.K2);

        PrintFormat("  D值   | D0=%.2f  D1=%.2f  D2=%.2f",
                    sig.D0, sig.D1, sig.D2);

        PrintFormat("  狀態  | 金叉 CrossUp=%d  死叉 CrossDown=%d  超買 OB=%d  超賣 OS=%d",
                    (int)sig.crossUp, (int)sig.crossDown,
                    (int)sig.isOB,    (int)sig.isOS);

        PrintFormat("  結果  | 方向 Direction=%s  接受 Accepted=%d",
                    direction, (int)accepted);
    }

    //--- CSV log
    if(InpLogToFile && g_fileHandle != INVALID_HANDLE)
    {
        datetime bar0Time = iTime(_Symbol, PERIOD_M5, 0);
        datetime bar2Time = iTime(_Symbol, PERIOD_M5, 2);

        FileWrite(g_fileHandle,
                  TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                  TimeToString(bar0Time, TIME_DATE|TIME_MINUTES),
                  TimeToString(bar1Time, TIME_DATE|TIME_MINUTES),
                  TimeToString(bar2Time, TIME_DATE|TIME_MINUTES),
                  DoubleToString(sig.K0, 2), DoubleToString(sig.D0, 2),
                  DoubleToString(sig.K1, 2), DoubleToString(sig.D1, 2),
                  DoubleToString(sig.K2, 2), DoubleToString(sig.D2, 2),
                  (int)sig.crossUp,  (int)sig.crossDown,
                  (int)sig.isOS,     (int)sig.isOB,
                  direction);
    }

    return rates_total;
}
