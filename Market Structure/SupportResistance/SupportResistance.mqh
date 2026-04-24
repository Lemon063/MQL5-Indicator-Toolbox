//+------------------------------------------------------------------+
//|  SupportResistance.mqh                                           |
//|  MQL5 Indicator Toolbox                                          |
//|  純邏輯庫 Pure logic library                                      |
//|  S/R 密集區算法 — 過去 N bars High/Low 價格密集度分析             |
//|  #include <Toolbox/SupportResistance.mqh>                        |
//+------------------------------------------------------------------+
#ifndef __SUPPORTRESISTANCE_MQH__
#define __SUPPORTRESISTANCE_MQH__

//--- 單個 S/R 密集區
struct SRZone
{
    double price;      // 密集區中心價格
    int    count;      // 出現次數（High + Low 合計）
    bool   valid;      // 係咪符合最低門檻
};

//--- S/R 分析結果
struct SRResult
{
    SRZone zones[200]; // 最多 200 個密集區
    int    total;      // 實際密集區數量
};

//+------------------------------------------------------------------+
//|  RoundToGrid                                                     |
//|  將價格四捨五入到最近嘅格（grid）                                  |
//|  price    : 輸入價格                                              |
//|  grid_size: 格距（price units，唔係 pips）                        |
//+------------------------------------------------------------------+
double RoundToGrid(double price, double grid_size)
{
    return MathRound(price / grid_size) * grid_size;
}

//+------------------------------------------------------------------+
//|  CalcSRZones                                                     |
//|  計算過去 lookback bars 嘅 S/R 密集區                             |
//|  symbol    : 交易品種                                              |
//|  tf        : 時間框架                                              |
//|  lookback  : 回望 bars 數（預設 100）                              |
//|  zone_pips : 密集區格距 pips（預設 10）                            |
//|  min_count : 最低出現次數門檻（預設 4）                            |
//|  shift     : 從第幾根 bar 開始（1 = 最後收盤 bar）                |
//+------------------------------------------------------------------+
SRResult CalcSRZones(string symbol,
                     ENUM_TIMEFRAMES tf,
                     int    lookback   = 100,
                     double zone_pips  = 10.0,
                     int    min_count  = 4,
                     int    shift      = 1)
{
    SRResult result;
    result.total = 0;

    double pip       = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
    double grid_size = zone_pips * pip;

    //--- 臨時儲存：price → count
    double temp_prices[400];
    int    temp_counts[400];
    int    temp_total = 0;

    //--- 遍歷過去 lookback bars，High + Low 各貢獻一個點
    for(int i = shift; i < shift + lookback; i++)
    {
        double h = iHigh(symbol, tf, i);
        double l = iLow (symbol, tf, i);

        double grid_h = RoundToGrid(h, grid_size);
        double grid_l = RoundToGrid(l, grid_size);

        //--- 處理 High
        bool found_h = false;
        for(int j = 0; j < temp_total; j++)
        {
            if(MathAbs(temp_prices[j] - grid_h) < grid_size * 0.01)
            {
                temp_counts[j]++;
                found_h = true;
                break;
            }
        }
        if(!found_h && temp_total < 400)
        {
            temp_prices[temp_total] = grid_h;
            temp_counts[temp_total] = 1;
            temp_total++;
        }

        //--- 處理 Low
        bool found_l = false;
        for(int j = 0; j < temp_total; j++)
        {
            if(MathAbs(temp_prices[j] - grid_l) < grid_size * 0.01)
            {
                temp_counts[j]++;
                found_l = true;
                break;
            }
        }
        if(!found_l && temp_total < 400)
        {
            temp_prices[temp_total] = grid_l;
            temp_counts[temp_total] = 1;
            temp_total++;
        }
    }

    //--- 過濾：只保留 >= min_count 嘅密集區
    for(int i = 0; i < temp_total && result.total < 200; i++)
    {
        if(temp_counts[i] >= min_count)
        {
            result.zones[result.total].price = temp_prices[i];
            result.zones[result.total].count = temp_counts[i];
            result.zones[result.total].valid = true;
            result.total++;
        }
    }

    return result;
}

//+------------------------------------------------------------------+
//|  IsPriceNearSR                                                   |
//|  檢查某個價格係咪喺任何 S/R 密集區附近                             |
//|  price     : 要檢查嘅價格（通常係 Pivot High/Low）                |
//|  sr        : CalcSRZones() 嘅輸出                                 |
//|  tolerance : 接受誤差（price units）                               |
//|  best_zone : 輸出最近嘅 S/R zone                                  |
//+------------------------------------------------------------------+
bool IsPriceNearSR(double price, const SRResult &sr,
                   double tolerance, SRZone &best_zone)
{
    best_zone.price = 0;
    best_zone.count = 0;
    best_zone.valid = false;

    double closest_dist = DBL_MAX;
    bool   found        = false;

    for(int i = 0; i < sr.total; i++)
    {
        double dist = MathAbs(price - sr.zones[i].price);
        if(dist <= tolerance && dist < closest_dist)
        {
            closest_dist = dist;
            best_zone    = sr.zones[i];
            found        = true;
        }
    }

    return found;
}

//+------------------------------------------------------------------+
//|  GetStrongestSR                                                  |
//|  返回出現次數最多嘅 S/R zone                                       |
//+------------------------------------------------------------------+
SRZone GetStrongestSR(const SRResult &sr)
{
    SRZone best;
    best.price = 0;
    best.count = 0;
    best.valid = false;

    for(int i = 0; i < sr.total; i++)
    {
        if(sr.zones[i].count > best.count)
            best = sr.zones[i];
    }

    return best;
}

#endif // __SUPPORTRESISTANCE_MQH__
