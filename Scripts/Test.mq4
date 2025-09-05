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
   long chartId = ChartID();
   string eaName = ChartIndicatorName(chartId, 0, 0);
   Print("EA Name: ", eaName);
}
//+------------------------------------------------------------------+
