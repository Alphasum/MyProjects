//+------------------------------------------------------------------+
//| GoldRetest.mq5                                                    |
//| Break-and-retest of higher-timeframe swing levels, XAUUSD M5.     |
//|                                                                   |
//| Levels : swing highs/lows (fractals) on LevelTF + previous day    |
//|          high/low.                                                |
//| Break  : M5 close crosses a level (up through a high = long       |
//|          setup, down through a low = short setup).                |
//| Retest : within RetestBars, an M5 bar touches the level again     |
//|          (+/- RetestTol) and closes back on the break side with   |
//|          a candle in the break direction. Enter at next bar open. |
//| Target : next swing high above (long) / swing low below (short)   |
//|          that is at least MinRR x risk away. All orders share it. |
//| Exit   : all orders close together at target (or stop).           |
//| Size   : one LotsPerOrder order per BalancePerOrder of balance,   |
//|          limited by free margin and MaxOrders.                    |
//+------------------------------------------------------------------+
#property copyright "GoldRetest"
#property version   "1.00"

#include <Trade/Trade.mqh>

#define ENTRY_TF PERIOD_M5

input group "Levels (higher timeframe)"
input ENUM_TIMEFRAMES LevelTF       = PERIOD_H1; // Timeframe for swing highs/lows
input int             SwingStrength = 2;         // Bars each side for a swing (2 = Williams fractal)
input int             LevelLookback = 120;       // LevelTF bars to scan (120 x H1 = about one week)
input bool            UsePrevDay    = true;      // Add previous day high/low as levels

input group "Entry"
input double RetestTol       = 1.0;    // Retest tolerance around the level, price units
input int    RetestBars      = 12;     // M5 bars allowed for the retest after the break
input double StopBuffer      = 1.0;    // Stop distance beyond the retest low/high, price units
input double MinRR           = 1.0;    // Skip when the next level is closer than MinRR x risk
input bool   UseStopLoss     = true;   // Put the structure stop on every order
input int    MaxTradesPerDay = 3;      // Signals (baskets) per server day
input double MaxSpread       = 0.5;    // Skip signals when the spread is wider, price units

input group "Money management"
input double LotsPerOrder    = 0.1;    // Volume of each order
input double BalancePerOrder = 100.0;  // One order per this much balance
input int    MaxOrders       = 50;     // Hard cap on orders per signal
input int    Magic           = 20261015;

CTrade   g_trade;
datetime g_lastBar      = 0;
int      g_setupDir     = 0;     // +1 waiting for retest after up-break, -1 after down-break
double   g_setupLevel   = 0.0;
int      g_setupBarsLeft = 0;
int      g_day          = -1;
int      g_tradesToday  = 0;
int      g_basketSize   = 0;     // orders opened for the current signal
int      g_basketDir    = 0;
double   g_basketTarget = 0.0;
double   g_highs[];
double   g_lows[];

//+------------------------------------------------------------------+
int OnInit()
{
   g_trade.SetExpertMagicNumber(Magic);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetDeviationInPoints(50);

   // pick up a basket left open by a previous run
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || !IsOurs())
         continue;
      g_basketSize++;
      g_basketTarget = PositionGetDouble(POSITION_TP);
      g_basketDir    = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
   }
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
bool IsOurs()   // call after the position is selected
{
   return PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == Magic;
}

int CountBasket()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetTicket(i) != 0 && IsOurs())
         n++;
   return n;
}

void CloseBasket()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && IsOurs())
         g_trade.PositionClose(ticket);
   }
}

//+------------------------------------------------------------------+
void Push(double &arr[], double v)
{
   int s = ArraySize(arr);
   ArrayResize(arr, s + 1);
   arr[s] = v;
}

void CollectLevels()
{
   ArrayResize(g_highs, 0);
   ArrayResize(g_lows, 0);

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(_Symbol, LevelTF, 0, LevelLookback, r);

   // r[0] is still forming; a swing at i needs SwingStrength closed bars on each side
   for(int i = SwingStrength + 1; i < n - SwingStrength; i++)
   {
      bool isHigh = true, isLow = true;
      for(int k = 1; k <= SwingStrength; k++)
      {
         if(r[i].high <= r[i - k].high || r[i].high < r[i + k].high) isHigh = false;
         if(r[i].low  >= r[i - k].low  || r[i].low  > r[i + k].low)  isLow  = false;
      }
      if(isHigh) Push(g_highs, r[i].high);
      if(isLow)  Push(g_lows,  r[i].low);
   }

   if(UsePrevDay)
   {
      double pdh = iHigh(_Symbol, PERIOD_D1, 1);
      double pdl = iLow(_Symbol, PERIOD_D1, 1);
      if(pdh > 0.0) Push(g_highs, pdh);
      if(pdl > 0.0) Push(g_lows,  pdl);
   }
}

//+------------------------------------------------------------------+
//| Nearest level beyond entry that is at least MinRR x risk away     |
//+------------------------------------------------------------------+
double FindTarget(int dir, double entry, double risk)
{
   double best = 0.0;
   if(dir > 0)
   {
      for(int i = 0; i < ArraySize(g_highs); i++)
         if(g_highs[i] - entry >= MinRR * risk && (best == 0.0 || g_highs[i] < best))
            best = g_highs[i];
   }
   else
   {
      for(int i = 0; i < ArraySize(g_lows); i++)
         if(entry - g_lows[i] >= MinRR * risk && (best == 0.0 || g_lows[i] > best))
            best = g_lows[i];
   }
   return best;
}

int OrdersToOpen(int dir, double price)
{
   int n = (int)MathFloor(AccountInfoDouble(ACCOUNT_BALANCE) / BalancePerOrder);

   double margin = 0.0;
   if(OrderCalcMargin(dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, LotsPerOrder, price, margin) && margin > 0.0)
   {
      int byMargin = (int)MathFloor(AccountInfoDouble(ACCOUNT_MARGIN_FREE) / margin);
      if(byMargin < n)
         n = byMargin;
   }
   return (n < MaxOrders) ? n : MaxOrders;
}

//+------------------------------------------------------------------+
void TryEnter(int dir, double stop)
{
   if(g_tradesToday >= MaxTradesPerDay || CountBasket() > 0)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask - bid > MaxSpread)
      return;

   double entry = (dir > 0) ? ask : bid;
   double risk  = (dir > 0) ? entry - stop : stop - entry;
   if(risk <= 0.0)
      return;

   double target = FindTarget(dir, entry, risk);
   if(target <= 0.0)
   {
      PrintFormat("Retest at %.2f: no level %.1fR away, skipped", g_setupLevel, MinRR);
      return;
   }

   int n = OrdersToOpen(dir, entry);
   if(n <= 0)
   {
      Print("Not enough balance/margin for one order, skipped");
      return;
   }

   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double sl     = UseStopLoss ? NormalizeDouble(stop, digits) : 0.0;
   double tp     = NormalizeDouble(target, digits);

   int opened = 0;
   for(int i = 0; i < n; i++)
   {
      bool ok = (dir > 0) ? g_trade.Buy(LotsPerOrder, _Symbol, 0.0, sl, tp)
                          : g_trade.Sell(LotsPerOrder, _Symbol, 0.0, sl, tp);
      if(!ok)
         break;
      opened++;
   }

   if(opened > 0)
   {
      g_tradesToday++;
      g_basketSize   = opened;
      g_basketDir    = dir;
      g_basketTarget = target;
      PrintFormat("%s x%d @%.2f level %.2f stop %.2f target %.2f (%.1fR)",
                  dir > 0 ? "BUY" : "SELL", opened, entry, g_setupLevel, stop, target,
                  MathAbs(target - entry) / risk);
   }
}

//+------------------------------------------------------------------+
void ManageBasket()
{
   if(g_basketSize == 0)
      return;

   int n = CountBasket();
   if(n == 0)
   {
      g_basketSize = 0;              // all closed by TP/SL
      return;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bool targetHit = g_basketTarget > 0.0 &&
                    ((g_basketDir > 0) ? (bid >= g_basketTarget) : (ask <= g_basketTarget));

   if(n < g_basketSize || targetHit)  // some orders already closed, or target reached
      CloseBasket();
}

//+------------------------------------------------------------------+
void OnNewBar()
{
   MqlDateTime now;
   TimeCurrent(now);
   if(now.day_of_year != g_day)
   {
      g_day         = now.day_of_year;
      g_tradesToday = 0;
   }

   CollectLevels();

   double o1 = iOpen(_Symbol, ENTRY_TF, 1);
   double h1 = iHigh(_Symbol, ENTRY_TF, 1);
   double l1 = iLow(_Symbol, ENTRY_TF, 1);
   double c1 = iClose(_Symbol, ENTRY_TF, 1);
   double c2 = iClose(_Symbol, ENTRY_TF, 2);

   // 1) pending setup: look for the retest on the bar that just closed
   if(g_setupDir != 0)
   {
      g_setupBarsLeft--;
      if(g_setupDir > 0)
      {
         if(c1 < g_setupLevel - RetestTol)
            g_setupDir = 0;                                         // break failed
         else if(l1 <= g_setupLevel + RetestTol && c1 > g_setupLevel && c1 > o1)
         {
            TryEnter(1, MathMin(l1, g_setupLevel) - StopBuffer);
            g_setupDir = 0;
         }
      }
      else
      {
         if(c1 > g_setupLevel + RetestTol)
            g_setupDir = 0;
         else if(h1 >= g_setupLevel - RetestTol && c1 < g_setupLevel && c1 < o1)
         {
            TryEnter(-1, MathMax(h1, g_setupLevel) + StopBuffer);
            g_setupDir = 0;
         }
      }
      if(g_setupBarsLeft <= 0)
         g_setupDir = 0;
   }

   // 2) new break: the closed bar crossed a level (highest high / lowest low wins)
   double upLevel = 0.0, downLevel = 0.0;
   for(int i = 0; i < ArraySize(g_highs); i++)
      if(c2 <= g_highs[i] && c1 > g_highs[i] && g_highs[i] > upLevel)
         upLevel = g_highs[i];
   for(int i = 0; i < ArraySize(g_lows); i++)
      if(c2 >= g_lows[i] && c1 < g_lows[i] && (downLevel == 0.0 || g_lows[i] < downLevel))
         downLevel = g_lows[i];

   if(upLevel > 0.0)
   {
      g_setupDir = 1;
      g_setupLevel = upLevel;
      g_setupBarsLeft = RetestBars;
   }
   else if(downLevel > 0.0)
   {
      g_setupDir = -1;
      g_setupLevel = downLevel;
      g_setupBarsLeft = RetestBars;
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   ManageBasket();

   datetime barTime = iTime(_Symbol, ENTRY_TF, 0);
   if(barTime == 0 || barTime == g_lastBar)
      return;
   g_lastBar = barTime;
   OnNewBar();
}
//+------------------------------------------------------------------+
