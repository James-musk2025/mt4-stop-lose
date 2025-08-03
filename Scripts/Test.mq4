//+------------------------------------------------------------------+
//|                                                         Test.mq4 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
enum ENUM_CONSIDER
{
   All = -1,       // ALL ORDERS
   Buy = OP_BUY,   // BUY ONLY
   Sell = OP_SELL, // SELL ONLY
};

enum ENUM_CUSTOMTIMEFRAMES
{
   CURRENT = PERIOD_CURRENT, // CURRENT PERIOD
   M1 = PERIOD_M1,           // M1
   M5 = PERIOD_M5,           // M5
   M15 = PERIOD_M15,         // M15
   M30 = PERIOD_M30,         // M30
   H1 = PERIOD_H1,           // H1
   H4 = PERIOD_H4,           // H4
   D1 = PERIOD_D1,           // D1
   W1 = PERIOD_W1,           // W1
   MN1 = PERIOD_MN1,         // MN1
};
input string Comment_1 = "====================";  // Expert Advisor Settings
input int ATRPeriod = 14;                         // ATR Period
input int Shift = 1;                              // Shift In The ATR Value (1=Previous Candle)
input double ATRMultiplier = 1.0;                 // ATR Multiplier
input int StopLossChangeThreshold = 100;          // Minimum Points To Move Stop Loss
input string Comment_2 = "====================";  // Orders Filtering Options
input bool OnlyCurrentSymbol = true;              // Apply To Current Symbol Only
input ENUM_CONSIDER OnlyType = All;               // Apply To
input bool UseMagic = false;                      // Filter By Magic Number
input int MagicNumber = 0;                        // Magic Number (if above is true)
input bool UseComment = false;                    // Filter By Comment
input string CommentFilter = "";                  // Comment (if above is true)
input bool EnableTrailingParam = false;           // Enable Trailing Stop
input bool EnableBreakEvenParam = false;          // Enable Break Even
input double ProfitForBreakEven = 20;         // Pips Required for Break Even
input bool ConsiderCommissionInBreakEven = true;  // Consider Commission in Break Even
input string Comment_3 = "====================";  // Notification Options
input bool EnableNotify = false;                  // Enable Notifications feature
input bool SendAlert = true;                      // Send Alert Notification
input bool SendApp = true;                        // Send Notification to Mobile
input bool SendEmail = true;                      // Send Notification via Email
input string Comment_3a = "===================="; // Graphical Window
input bool ShowPanel = true;                      // Show Graphical Panel
input string ExpertName = "MQLTA-ATRTS";          // Expert Name (to name the objects)
input int Xoff = 20;                              // Horizontal spacing for the control panel
input int Yoff = 20;                              // Vertical spacing for the control panel

double GetStopLossBuy(string Instrument)
{
   double SLValue = iClose(Instrument, PERIOD_CURRENT, 0) - iATR(Instrument, PERIOD_CURRENT, ATRPeriod, Shift) * ATRMultiplier;
   return SLValue;
}

double GetStopLossSell(string Instrument)
{
   double SLValue = iClose(Instrument, PERIOD_CURRENT, 0) + iATR(Instrument, PERIOD_CURRENT, ATRPeriod, Shift) * ATRMultiplier;
   return SLValue;
}
void OnStart()
{
   //---
   string Instrument = Symbol();
   // Print("Hello, MQL4!");
   // double PointsDiff = MarketInfo(Instrument, MODE_POINT);
   // double PointsDiffOfSymbol = SymbolInfoDouble(Instrument, SYMBOL_POINT);
   // Print("Points difference for ", Instrument, " is: ", PointsDiff);
   // Print("Points difference of symbol ", Instrument, " is: ", PointsDiffOfSymbol);

   // Print("Symbol=", Symbol());
   // Print("Low day price=", MarketInfo(Symbol(), MODE_LOW));

   // // Get current symbol and lot size
   // string symbol = Symbol();
   // double lot_size = 0.1;
   // double lots = OrderLots(); // 交易量

   // // Get pip value and digits
   // double pip_value = MarketInfo(symbol, MODE_POINT);
   // double digits = MarketInfo(symbol, MODE_DIGITS);

   // // Get current ask price
   // double ask_price = MarketInfo(symbol, MODE_ASK);

   // // Calculate pip value for the given lot size
   // double pip_value_for_lot = pip_value * lot_size / ask_price;

   // // Display the results
   // Print("Symbol: ", symbol);
   // Print("Lot Size: ", lot_size);
   // Print("Pip Value: ", pip_value);
   // Print("Digits: ", digits);
   // Print("Ask Price: ", ask_price);
   // Print("Pip Value for Lot Size: ", pip_value_for_lot);

   for (int i = 0; i < OrdersTotal(); i++)
   {

      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)
      {
         int Error = GetLastError();
         Print("ERROR - Unable to select the order - ", Error);
         continue;
      }
      double NewSL = 0;
      double NewTP = 0;
      // string Instrument = OrderSymbol();
      double SLBuy = GetStopLossBuy(Instrument);
      double SLSell = GetStopLossSell(Instrument);
      if ((SLBuy == 0) || (SLSell == 0))
      {
         Print("Not enough historical data - please load more candles for the selected timeframe.");
         return;
      }

      int eDigits = (int)MarketInfo(Instrument, MODE_DIGITS);
      SLBuy = NormalizeDouble(SLBuy, eDigits);
      SLSell = NormalizeDouble(SLSell, eDigits);
      double SLPrice = NormalizeDouble(OrderStopLoss(), eDigits);
      double TPPrice = NormalizeDouble(OrderTakeProfit(), eDigits);
      double Spread = MarketInfo(Instrument, MODE_SPREAD) * MarketInfo(Instrument, MODE_POINT);
      // double Spread = MarketInfo(Instrument, MODE_SPREAD);
      double StopLevel = MarketInfo(Instrument, MODE_STOPLEVEL) * MarketInfo(Instrument, MODE_POINT);
      // double StopLevel = MarketInfo(Instrument, MODE_STOPLEVEL);
      double commission = OrderCommission();

      // Adjust for tick size granularity.
      double TickSize = SymbolInfoDouble(Instrument, SYMBOL_TRADE_TICK_SIZE);
      if (TickSize > 0)
      {
         SLBuy = NormalizeDouble(MathRound(SLBuy / TickSize) * TickSize, eDigits);
         SLSell = NormalizeDouble(MathRound(SLSell / TickSize) * TickSize, eDigits);
      }
      double openPrice = OrderOpenPrice();

      double ProfitPoints = (OrderType() == OP_BUY ? (MarketInfo(Instrument, MODE_ASK) - OrderOpenPrice()) : (OrderOpenPrice() - MarketInfo(Instrument, MODE_BID))) /
                            MarketInfo(Instrument, MODE_POINT);

      Print("DEBUG - Order ", OrderTicket(), " in ", Instrument,
            ": Type=", (OrderType() == OP_BUY ? "BUY" : "SELL"),
            " Open Price=", openPrice,
            " SL Buy=", SLBuy, " SLSell=", SLSell,
            " Commission =", commission,
            " TickSize =", TickSize,
            " ProfitPoints =", ProfitPoints,
            " SL Price=", SLPrice, " TP Price=", TPPrice,
            " Spread=", Spread, " Stop Level=", StopLevel);
   }
}
//+------------------------------------------------------------------+
