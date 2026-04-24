//+------------------------------------------------------------------+
//|  SupportResistance.mqh                                           |
//|  MQL5 Indicator Toolbox                                          |
//|  純邏輯庫 Pure logic library                                      |
//|  S/R 密集區算法 — 過去 N bars High/Low 價格密集度分析             |
//|  #include <Toolbox/SupportResistance.mqh>                        |
//+------------------------------------------------------------------+
#ifndef __SUPPORTRESISTANCE_MQH__
#define __SUPPORTRESISTANCE_MQH__

#include <Toolbox/ATR.mqh>   // GetPipSize()

//--- 單個 S/R 密集區
struct SRZone
{
    double price;
    int    count;
    bool   valid;
};

//--- S/R 分析結果
struct SRResult
{
    SRZone zones[200];
    int    total;
};

//+------------------------------------------------------------------+
//|  RoundToGrid                                                     |
//+------------------------------------------------------------------+
double RoundToGrid(double price, double grid_size)
{
    return MathRound(price / grid_size) * grid_size;
}

//+------------------------------------------------------------------+
//|  CalcSRZones                                                     |
//|  修正：用 GetPipSize() 統一 pip 計算，修正 JPY pair 問題          |
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

    //--- 修正：統一用 GetPipSize()，唔用 _Point * 10
    double pip       = GetPipSize(symbol);
    double grid_size = zone_pips * pip;

    double temp_prices[400];
    int    temp_counts[400];
    int    temp_total = 0;

    for(int i = shift; i < shift + lookback; i++)
    {
        double h      = iHigh(symbol, tf, i);
        double l      = iLow (symbol, tf, i);
        double grid_h = RoundToGrid(h, grid_size);
        double grid_l = RoundToGrid(l, grid_size);

        //--- High
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

        //--- Low
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
