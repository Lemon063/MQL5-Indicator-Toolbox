//+------------------------------------------------------------------+
//|  Stochastic.mqh                                                  |
//|  MQL5 Indicator Toolbox                                          |
//|  純邏輯庫 Pure logic library                                      |
//|  冇圖表輸出，冇事件函數 No chart output, no event functions        |
//|  #include <Toolbox/Stochastic.mqh>                               |
//+------------------------------------------------------------------+
#pragma once

//--- Struct：儲存一根 bar 嘅 Stoch 數值
struct StochBar
{
    double K;   // Main line  (K value)
    double D;   // Signal line (D value)
};

//--- Struct：Cross 檢測結果
struct StochSignal
{
    bool   crossUp;    // 金叉 Golden cross：K 由下穿上 D
    bool   crossDown;  // 死叉 Death cross：K 由上穿下 D
    bool   isOB;       // 超買 Overbought：K1 >= InpOB
    bool   isOS;       // 超賣 Oversold：K1 <= InpOS
    double K0, D0;     // bar0（當前未收盤 bar）
    double K1, D1;     // bar1（最後收盤 bar，用作 cross 判斷）
    double K2, D2;     // bar2（前一收盤 bar，用作 cross 判斷）
};

//+------------------------------------------------------------------+
//|  GetStochValues                                                  |
//|  取得指定 bar 嘅 K 同 D 值                                        |
//|  shift = 1 → bar1（最後收盤 bar）                                 |
//+------------------------------------------------------------------+
StochBar GetStochValues(int handle, int shift)
{
    StochBar result;
    result.K = 0;
    result.D = 0;

    double kBuf[], dBuf[];
    ArraySetAsSeries(kBuf, true);
    ArraySetAsSeries(dBuf, true);

    if(CopyBuffer(handle, MAIN_LINE,   shift, 1, kBuf) < 1) return result;
    if(CopyBuffer(handle, SIGNAL_LINE, shift, 1, dBuf) < 1) return result;

    result.K = kBuf[0];
    result.D = dBuf[0];
    return result;
}

//+------------------------------------------------------------------+
//|  DetectStochSignal                                               |
//|  一次過取得 bar0/1/2 數值並判斷 cross + OB/OS                     |
//|  handle   : iStochastic() 返回嘅 handle                          |
//|  ob_level : 超買水平（預設 80）                                    |
//|  os_level : 超賣水平（預設 20）                                    |
//+------------------------------------------------------------------+
StochSignal DetectStochSignal(int handle,
                              double ob_level = 80.0,
                              double os_level = 20.0)
{
    StochSignal sig;
    sig.crossUp   = false;
    sig.crossDown = false;
    sig.isOB      = false;
    sig.isOS      = false;
    sig.K0 = sig.D0 = sig.K1 = sig.D1 = sig.K2 = sig.D2 = 0;

    //--- 靜態 array + CopyBuffer(start=0, count=3)
    //    AsSeries=false（靜態 array 唔受 ArraySetAsSeries 影響）
    //    index 0 = 最舊（bar2），index 2 = 最新（bar0）
    double K[3], D[3];
    if(CopyBuffer(handle, MAIN_LINE,   0, 3, K) < 3) return sig;
    if(CopyBuffer(handle, SIGNAL_LINE, 0, 3, D) < 3) return sig;

    //--- 對應關係
    sig.K2 = K[0]; sig.D2 = D[0];  // bar2：較舊收盤 bar
    sig.K1 = K[1]; sig.D1 = D[1];  // bar1：最後收盤 bar（cross 判斷用）
    sig.K0 = K[2]; sig.D0 = D[2];  // bar0：當前未收盤 bar（唔用於 cross）

    //--- Cross 判斷（只用 bar1 / bar2）
    //    spec_v3_trader_logic.md §5.3
    //    CrossUp   = K2 <= D2 AND K1 > D1
    //    CrossDown = K2 >= D2 AND K1 < D1
    sig.crossUp   = (sig.K2 <= sig.D2) && (sig.K1 > sig.D1);
    sig.crossDown = (sig.K2 >= sig.D2) && (sig.K1 < sig.D1);

    //--- OB / OS（基於 bar1 K 值）
    sig.isOB = (sig.K1 >= ob_level);
    sig.isOS = (sig.K1 <= os_level);

    return sig;
}

//+------------------------------------------------------------------+
//|  CreateStochHandle                                               |
//|  建立 iStochastic handle，方便 caller 統一初始化                  |
//+------------------------------------------------------------------+
int CreateStochHandle(string symbol, ENUM_TIMEFRAMES tf,
                      int k_period, int d_period, int smooth)
{
    return iStochastic(symbol, tf,
                       k_period, d_period, smooth,
                       MODE_SMA, STO_LOWHIGH);
}
