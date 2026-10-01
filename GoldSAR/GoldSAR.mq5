//+------------------------------------------------------------------+
//| GoldSAR.mq5                                                       |
//| Minimal stop-and-reverse trailing scalper for XAUUSD (M1).        |
//|                                                                   |
//| Always holds exactly one position. The "stop" is virtual:         |
//|   - starts StopDist away from entry                               |
//|   - once (best price - TrailDist) is at/above breakeven, it       |
//|     trails TrailDist behind the best price (ratchet, never back)  |
//| When price touches the stop the position is closed and the       |
//| opposite one is opened at market (the exit IS the next entry).    |
//| Lot size = RiskPercent of balance / loss-if-initial-stop-is-hit.  |
//+------------------------------------------------------------------+
#property copyright "GoldSAR"
#property version   "1.00"

#include <Trade/Trade.mqh>

input double RiskPercent  = 0.5;       // Risk per trade, % of balance (loss if initial stop is hit)
input double StopDist     = 1.5;       // Initial stop distance, price units (USD/oz on XAUUSD)
input double TrailDist    = 0.6;       // Trailing distance behind best price
input double MaxSpread    = 0.5;       // Do not open when spread (price units) is wider than this
input double DailyLossPct = 3.0;       // Close and halt for the day at this % equity loss (0 = off)
input int    Magic        = 20260401;  // Magic number

#define HARD_STOP_MULT 3.0             // broker-side safety SL = HARD_STOP_MULT * StopDist

CTrade g_trade;
int    g_dir          = 0;             // direction to hold: +1 long, -1 short, 0 = undecided
double g_extreme      = 0.0;           // best price since entry (high bid for long, low ask for short)
int    g_day          = -1;            // day_of_year of last tick, for the daily guard
double g_dayStartBal  = 0.0;
bool   g_halted       = false;

//+------------------------------------------------------------------+
int OnInit()
{
   g_trade.SetExpertMagicNumber(Magic);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetDeviationInPoints(50);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Lots so that hitting the initial stop loses RiskPercent of balance|
//+------------------------------------------------------------------+
double CalcLots()
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double step      = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin      = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax      = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(tickValue <= 0.0 || tickSize <= 0.0 || step <= 0.0)
      return vmin;

   double lossPerLot = StopDist / tickSize * tickValue;   // account currency
   double lots = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0 / lossPerLot;
   lots = MathFloor(lots / step) * step;
   lots = MathMax(vmin, MathMin(vmax, lots));
   return NormalizeDouble(lots, (int)MathRound(-MathLog10(step)));
}

//+------------------------------------------------------------------+
bool GetPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, double &entry)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != Magic)
         continue;
      ticket = t;
      ptype  = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      entry  = PositionGetDouble(POSITION_PRICE_OPEN);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void OpenPosition(double bid, double ask)
{
   if(ask - bid > MaxSpread)
      return;

   if(g_dir == 0)   // first trade of the day / after restart: follow the last closed M1 bar
      g_dir = (iClose(_Symbol, PERIOD_M1, 1) >= iOpen(_Symbol, PERIOD_M1, 1)) ? 1 : -1;

   double lots   = CalcLots();
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   bool   ok;
   if(g_dir > 0)
      ok = g_trade.Buy(lots, _Symbol, 0.0, NormalizeDouble(ask - HARD_STOP_MULT * StopDist, digits), 0.0);
   else
      ok = g_trade.Sell(lots, _Symbol, 0.0, NormalizeDouble(bid + HARD_STOP_MULT * StopDist, digits), 0.0);

   if(ok)
      g_extreme = (g_dir > 0) ? bid : ask;
}

//+------------------------------------------------------------------+
void OnTick()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   // daily guard
   MqlDateTime now;
   TimeCurrent(now);
   if(now.day_of_year != g_day)
   {
      g_day         = now.day_of_year;
      g_dayStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
      g_halted      = false;
   }

   ulong              ticket = 0;
   ENUM_POSITION_TYPE ptype  = POSITION_TYPE_BUY;
   double             entry  = 0.0;
   bool hasPos = GetPosition(ticket, ptype, entry);

   if(!g_halted && DailyLossPct > 0.0 &&
      AccountInfoDouble(ACCOUNT_EQUITY) < g_dayStartBal * (1.0 - DailyLossPct / 100.0))
      g_halted = true;

   if(g_halted)
   {
      if(hasPos)
         g_trade.PositionClose(ticket);
      g_dir = 0;
      return;
   }

   if(hasPos)
   {
      if(g_extreme <= 0.0)   // EA restarted with a position open
         g_extreme = (ptype == POSITION_TYPE_BUY) ? bid : ask;

      if(ptype == POSITION_TYPE_BUY)
      {
         g_extreme = MathMax(g_extreme, bid);
         double stop = (g_extreme - TrailDist >= entry) ? g_extreme - TrailDist : entry - StopDist;
         if(bid <= stop && g_trade.PositionClose(ticket))
         {
            g_dir  = -1;
            hasPos = false;
         }
      }
      else
      {
         g_extreme = MathMin(g_extreme, ask);
         double stop = (g_extreme + TrailDist <= entry) ? g_extreme + TrailDist : entry + StopDist;
         if(ask >= stop && g_trade.PositionClose(ticket))
         {
            g_dir  = 1;
            hasPos = false;
         }
      }
   }

   if(!hasPos)
      OpenPosition(bid, ask);
}
//+------------------------------------------------------------------+
