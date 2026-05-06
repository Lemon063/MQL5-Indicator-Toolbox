// ExportOHLC.mq5 — Export USDJPY M5 OHLC for 2026-04-30 to CSV
#property script_show_inputs

input string   InpSymbol   = "USDJPY";
input ENUM_TIMEFRAMES InpTF = PERIOD_M5;
input string   InpDateFrom = "2026.05.05 00:00";
input string   InpDateTo   = "2026.05.06 19:30";
input string   InpOutFile  = "C:\\users\\user\\Documents\\GitHub\\MQL5-Indicator-Toolbox\\Fibonacci\\FibPIP\\Test_1_260430\\USDJPY_M5_OHLC_260430.csv";

void OnStart()
{
   datetime from = StringToTime(InpDateFrom);
   datetime to   = StringToTime(InpDateTo);

   MqlRates rates[];
   int copied = CopyRates(InpSymbol, InpTF, from, to, rates);
   if(copied <= 0)
   {
      Print("CopyRates failed: ", GetLastError(), " — ensure history is loaded for ", InpSymbol);
      return;
   }

   int handle = FileOpen(InpOutFile, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
   {
      // Fallback: relative path inside MQL5/Files
      string fallback = "USDJPY_M5_OHLC_260430.csv";
      handle = FileOpen(fallback, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
      {
         Print("FileOpen failed: ", GetLastError());
         return;
      }
      Print("Writing to MQL5/Files/", fallback);
   }

   FileWrite(handle, "datetime", "open", "high", "low", "close", "volume");

   for(int i = 0; i < copied; i++)
   {
      string dt = TimeToString(rates[i].time, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
      FileWrite(handle,
                dt,
                DoubleToString(rates[i].open,  3),
                DoubleToString(rates[i].high,  3),
                DoubleToString(rates[i].low,   3),
                DoubleToString(rates[i].close, 3),
                (string)rates[i].tick_volume);
   }

   FileClose(handle);

   Print("Exported ", copied, " bars.");
   Print("First bar: ", TimeToString(rates[0].time), " O=", rates[0].open,
         " H=", rates[0].high, " L=", rates[0].low, " C=", rates[0].close);
   Print("Last bar:  ", TimeToString(rates[copied-1].time), " O=", rates[copied-1].open,
         " H=", rates[copied-1].high, " L=", rates[copied-1].low, " C=", rates[copied-1].close);
}
