//+------------------------------------------------------------------+
//|  EngulfPinBar.mqh                                                |
//|  MQL5 Indicator Toolbox                                          |
//|  純邏輯庫 Pure logic library                                      |
//|  冇圖表輸出，冇事件函數 No chart output, no event functions        |
//|  依賴 Depends on: ATR.mqh (GetPipSize)                           |
//|  #include <Toolbox/EngulfPinBar.mqh>                             |
//+------------------------------------------------------------------+
#pragma once
#include <Toolbox/ATR.mqh>

//--- Struct：單根 bar 嘅 OHLC 衍生值
struct CandleData
{
    double open, high, low, close;
    double body;        // |close - open|
    double upperWick;   // high - max(open, close)
    double lowerWick;   // min(open, close) - low
    bool   bullish;     // close > open
    bool   bearish;     // close < open
};

//--- Struct：Pattern 檢測結果
struct CandleSignal
{
    bool   bullEngulf;  // 看漲吞噬 Bullish Engulfing
    bool   bearEngulf;  // 看跌吞噬 Bearish Engulfing
    bool   bullPin;     // 看漲針形 Bullish Pin Bar
    bool   bearPin;     // 看跌針形 Bearish Pin Bar
    bool   detected;    // 任何一個觸發
    string direction;   // "BUY" / "SELL" / "NONE"
};

//+------------------------------------------------------------------+
//|  BuildCandleData                                                 |
//|  由 OHLC 計算衍生值，填入 CandleData struct                       |
//+------------------------------------------------------------------+
CandleData BuildCandleData(double o, double h, double l, double c)
{
    CandleData cd;
    cd.open      = o;
    cd.high      = h;
    cd.low       = l;
    cd.close     = c;
    cd.body      = MathAbs(c - o);
    cd.upperWick = h - MathMax(o, c);
    cd.lowerWick = MathMin(o, c) - l;
    cd.bullish   = (c > o);
    cd.bearish   = (c < o);
    return cd;
}

//+------------------------------------------------------------------+
//|  GetCandleData                                                   |
//|  直接從 chart 取得指定 bar 嘅 CandleData                          |
//|  shift = 1 → bar1（最後收盤 bar）                                 |
//+------------------------------------------------------------------+
CandleData GetCandleData(string symbol, ENUM_TIMEFRAMES tf, int shift)
{
    return BuildCandleData(
        iOpen (symbol, tf, shift),
        iHigh (symbol, tf, shift),
        iLow  (symbol, tf, shift),
        iClose(symbol, tf, shift)
    );
}

//+------------------------------------------------------------------+
//|  DetectCandlePattern                                             |
//|  偵測 bar1 嘅 Engulfing 同 Pin Bar pattern                       |
//|  symbol       : 交易品種                                          |
//|  tf           : 時間框架                                           |
//|  pin_body_multi : Pin Bar：影線 >= 燭身 × 此倍數（預設 2.0）      |
//|  pin_opp_multi  : Pin Bar：反向影線 <= 燭身 × 此倍數（預設 0.5）  |
//|  min_body_pips  : 最小燭身 pips，過濾 Doji（預設 0.5）            |
//+------------------------------------------------------------------+
CandleSignal DetectCandlePattern(string symbol,
                                 ENUM_TIMEFRAMES tf,
                                 double pin_body_multi  = 2.0,
                                 double pin_opp_multi   = 0.5,
                                 double min_body_pips   = 0.5)
{
    CandleSignal sig;
    sig.bullEngulf = false;
    sig.bearEngulf = false;
    sig.bullPin    = false;
    sig.bearPin    = false;
    sig.detected   = false;
    sig.direction  = "NONE";

    //--- 取 bar1 同 bar2（只用已收盤 bar，唔用 bar0）
    CandleData b1 = GetCandleData(symbol, tf, 1);
    CandleData b2 = GetCandleData(symbol, tf, 2);

    //--- 最小燭身過濾（統一用 ATR.mqh 嘅 GetPipSize）
    double pipSize     = GetPipSize(symbol);
    double minBodySize = min_body_pips * pipSize;

    //--- 看漲吞噬 Bullish Engulfing
    //    bar2 係陰燭，bar1 係陽燭
    //    bar1 燭身完全包住 bar2 燭身：
    //      bar1 Open < bar2 Close  AND  bar1 Close > bar2 Open
    sig.bullEngulf = b2.bearish
                     && b1.bullish
                     && (b1.open  < b2.close)
                     && (b1.close > b2.open)
                     && (b1.body  > minBodySize);

    //--- 看跌吞噬 Bearish Engulfing
    //    bar2 係陽燭，bar1 係陰燭
    //    bar1 燭身完全包住 bar2 燭身：
    //      bar1 Open > bar2 Close  AND  bar1 Close < bar2 Open
    sig.bearEngulf = b2.bullish
                     && b1.bearish
                     && (b1.open  > b2.close)
                     && (b1.close < b2.open)
                     && (b1.body  > minBodySize);

    //--- 看漲針形 Bullish Pin Bar
    //    長下影線，短上影線
    //    下影線 >= 燭身 × pin_body_multi
    //    上影線 <= 燭身 × pin_opp_multi
    sig.bullPin = (b1.body      > minBodySize)
                  && (b1.lowerWick >= b1.body * pin_body_multi)
                  && (b1.upperWick <= b1.body * pin_opp_multi);

    //--- 看跌針形 Bearish Pin Bar
    //    長上影線，短下影線
    //    上影線 >= 燭身 × pin_body_multi
    //    下影線 <= 燭身 × pin_opp_multi
    sig.bearPin = (b1.body      > minBodySize)
                  && (b1.upperWick >= b1.body * pin_body_multi)
                  && (b1.lowerWick <= b1.body * pin_opp_multi);

    //--- 方向判斷（看漲優先）
    sig.detected = (sig.bullEngulf || sig.bearEngulf ||
                    sig.bullPin    || sig.bearPin);

    if(sig.detected)
    {
        if(sig.bullEngulf || sig.bullPin)
            sig.direction = "BUY";
        else
            sig.direction = "SELL";
    }

    return sig;
}
