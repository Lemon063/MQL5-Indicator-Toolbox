// ExportUSDJPYHistory.mq5
// Read-only MT5 script: export native USDJPY M5/H1/H4/D1 OHLCV history to CSV.
#property script_show_inputs

input string InpSymbol = "USDJPY";
input string InpDateFrom = "2023.01.01 00:00";
input string InpDateTo = "2026.08.19 23:59";
input string InpOutputPrefix = "USDJPY";

struct ExportJob
{
   ENUM_TIMEFRAMES timeframe;
   string name;
};

bool ExportTimeframe(const string symbol,
                     const ENUM_TIMEFRAMES timeframe,
                     const string timeframe_name,
                     const datetime from_time,
                     const datetime to_time,
                     const string output_prefix,
                     const int digits)
{
   MqlRates rates[];
   int copied = CopyRates(symbol, timeframe, from_time, to_time, rates);
   if(copied <= 0)
   {
      Print("CopyRates failed for ", symbol, " ", timeframe_name,
            ". error=", GetLastError(),
            ". Ensure history is loaded and Max. bars in chart is high enough.");
      return false;
   }

   string filename = output_prefix + "_" + timeframe_name + "_export.csv";
   int handle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
   {
      Print("FileOpen failed for ", filename, ". error=", GetLastError());
      return false;
   }

   FileWrite(handle,
             "datetime",
             "open",
             "high",
             "low",
             "close",
             "tick_volume",
             "spread_points",
             "real_volume");

   for(int i = 0; i < copied; i++)
   {
      FileWrite(handle,
                TimeToString(rates[i].time, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
                DoubleToString(rates[i].open, digits),
                DoubleToString(rates[i].high, digits),
                DoubleToString(rates[i].low, digits),
                DoubleToString(rates[i].close, digits),
                (string)rates[i].tick_volume,
                (string)rates[i].spread,
                (string)rates[i].real_volume);
   }

   FileClose(handle);

   Print("Exported ", copied, " bars to MQL5/Files/", filename);
   Print(timeframe_name, " first bar: ", TimeToString(rates[0].time, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
         " last bar: ", TimeToString(rates[copied - 1].time, TIME_DATE | TIME_MINUTES | TIME_SECONDS));
   return true;
}

void OnStart()
{
   datetime from_time = StringToTime(InpDateFrom);
   datetime to_time = StringToTime(InpDateTo);
   if(from_time <= 0 || to_time <= 0 || from_time >= to_time)
   {
      Print("Invalid date range. InpDateFrom=", InpDateFrom, " InpDateTo=", InpDateTo);
      return;
   }

   if(!SymbolSelect(InpSymbol, true))
   {
      Print("SymbolSelect failed for ", InpSymbol, ". error=", GetLastError());
      return;
   }

   int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
   Print("Starting read-only export for ", InpSymbol,
         " from ", TimeToString(from_time, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
         " to ", TimeToString(to_time, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
         ". digits=", digits);

   ExportJob jobs[4] =
   {
      {PERIOD_M5, "M5"},
      {PERIOD_H1, "H1"},
      {PERIOD_H4, "H4"},
      {PERIOD_D1, "D1"}
   };

   bool all_ok = true;
   for(int i = 0; i < 4; i++)
   {
      bool ok = ExportTimeframe(InpSymbol, jobs[i].timeframe, jobs[i].name, from_time, to_time, InpOutputPrefix, digits);
      all_ok = all_ok && ok;
   }

   if(all_ok)
      Print("All exports completed.");
   else
      Print("One or more exports failed. Check the Experts log before using the CSV files.");
}
