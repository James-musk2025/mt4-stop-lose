#property link "https://www.earnforex.com/metatrader-expert-advisors/atr-trailing-stop/"
#property version "1.08"
#property strict
#property copyright "EarnForex.com - 2019-2024"
#property description "This expert advisor will trail the stop-loss using ATR as a distance from the price."
#property description " "
#property description "WARNING: Use this software at your own risk."
#property description "The creator of this EA cannot be held responsible for any damage or loss."
#property description " "
#property description "Find More on www.EarnForex.com"
#property icon "\\Files\\EF-Icon-64x64px.ico"

#include <MQLTA ErrorHandling.mqh>
#include <MQLTA Utils.mqh>

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
input bool EnableBreakEvenParam = true;           // Enable Break Even
input bool EnableATRAfterBreakEvenParam = false;  // Enable ATR After Break Even
input double ProfitForBreakEven = 5.25;           // Pips Required for Break Even
input bool ConsiderCommissionInBreakEven = false; // Consider Commission in Break Even
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

int OrderOpRetry = 5;
bool EnableTrailing = EnableTrailingParam;
bool EnableBreakEven = EnableBreakEvenParam;
double DPIScale; // Scaling parameter for the panel based on the screen DPI.
int PanelMovX, PanelMovY, PanelLabX, PanelLabY, PanelRecX;
bool EnableATRAfterBreakEven = EnableATRAfterBreakEvenParam;
string PanelATRAfterBreakEven = ExpertName + "-P-ATRBE";

int OnInit()
{
    EnableTrailing = EnableTrailingParam;
    EnableBreakEven = EnableBreakEvenParam;
    EnableATRAfterBreakEven = EnableATRAfterBreakEvenParam;

    DPIScale = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI) / 96.0;

    PanelMovX = (int)MathRound(50 * DPIScale);
    PanelMovY = (int)MathRound(20 * DPIScale);
    PanelLabX = (int)MathRound(150 * DPIScale);
    PanelLabY = PanelMovY;
    PanelRecX = PanelLabX + 4;

    if (ShowPanel)
        DrawPanel();

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    CleanPanel();
}

void OnTick()
{
    if (EnableTrailing || EnableBreakEven) // 检查是否启用了任一功能
        TrailingStop();
    if (ShowPanel)
        DrawPanel();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if (id == CHARTEVENT_OBJECT_CLICK)
    {
        if (sparam == PanelEnableDisable)
        {
            ChangeTrailingEnabled();
        }
        else if (sparam == PanelBreakEven)
        {
            ChangeBreakEvenEnabled();
        }
        else if (sparam == PanelBreakEven)
        {
            ChangeBreakEvenEnabled();
            // 如果关闭保本功能，同时关闭ATR After Break Even
            if (!EnableBreakEven)
                EnableATRAfterBreakEven = false;
        }
        else if (sparam == PanelATRAfterBreakEven)
        {
            ChangeATRAfterBreakEvenEnabled();
        }
    }
    else if (id == CHARTEVENT_KEYDOWN)
    {
        if (lparam == 27)
        {
            if (MessageBox("Are you sure you want to close the EA?", "EXIT ?", MB_YESNO) == IDYES)
            {
                ExpertRemove();
            }
        }
    }
}

// 统一计算止损价格函数
double CalculateStopLossPrice(string Instrument, int orderType)
{
    double closePrice = iClose(Instrument, PERIOD_CURRENT, 0);
    double atrValue = iATR(Instrument, PERIOD_CURRENT, ATRPeriod, Shift) * ATRMultiplier;
    
    if (orderType == OP_BUY)
        return closePrice - atrValue;
    else if (orderType == OP_SELL)
        return closePrice + atrValue;
    
    return 0;
}

// 检查订单是否符合处理条件
bool ShouldProcessOrder()
{
    if ((OnlyCurrentSymbol) && (OrderSymbol() != Symbol()))
        return false;
    if ((UseMagic) && (OrderMagicNumber() != MagicNumber))
        return false;
    if ((UseComment) && (StringFind(OrderComment(), CommentFilter) < 0))
        return false;
    if ((OnlyType != All) && (OrderType() != OnlyType))
        return false;
    
    return true;
}

// 计算并规范化止损价格
double CalculateAndNormalizeSL(string Instrument, int orderType)
{
    double sl = CalculateStopLossPrice(Instrument, orderType);
    int eDigits = (int)MarketInfo(Instrument, MODE_DIGITS);
    sl = NormalizeDouble(sl, eDigits);
    
    // 根据TickSize调整
    double TickSize = SymbolInfoDouble(Instrument, SYMBOL_TRADE_TICK_SIZE);
    if (TickSize > 0)
    {
        sl = NormalizeDouble(MathRound(sl / TickSize) * TickSize, eDigits);
    }
    
    return sl;
}

void TrailingStop()
{
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            int error = GetLastError();
            Print("ERROR - Unable to select order - ", error, ": ", GetLastErrorText(error));
            continue;
        }
        
        if (!ShouldProcessOrder()) continue;
        
        string Instrument = OrderSymbol();
        double buySL = CalculateAndNormalizeSL(Instrument, OP_BUY);
        double sellSL = CalculateAndNormalizeSL(Instrument, OP_SELL);
        
        if (buySL == 0 || sellSL == 0)
        {
            Print("Not enough historical data - please load more candles");
            return;
        }
        
        int eDigits = (int)MarketInfo(Instrument, MODE_DIGITS);
        double currentSL = NormalizeDouble(OrderStopLoss(), eDigits);
        double spread = MarketInfo(Instrument, MODE_SPREAD) * MarketInfo(Instrument, MODE_POINT);
        double stopLevel = MarketInfo(Instrument, MODE_STOPLEVEL) * MarketInfo(Instrument, MODE_POINT);
        double openPrice = OrderOpenPrice();
        
        // 先处理保本逻辑
        if (CheckBreakEvenCondition())
        {
            double bePrice = GetBreakEvenPrice(OrderType(), openPrice, spread);
            double TickSize = SymbolInfoDouble(Instrument, SYMBOL_TRADE_TICK_SIZE);
            if (TickSize > 0)
            {
                bePrice = NormalizeDouble(MathRound(bePrice / TickSize) * TickSize, eDigits);
            }

            // 检查是否需要更新止损
            if ((currentSL == 0) ||
                (OrderType() == OP_BUY && bePrice > currentSL) ||
                (OrderType() == OP_SELL && bePrice < currentSL))
            {
                ModifyOrder(OrderTicket(), openPrice, bePrice, OrderTakeProfit());
                continue;
            }
        }
        
        // 再处理常规追踪
        if (EnableTrailing)
        {
            if (EnableATRAfterBreakEven && !CheckBreakEvenCondition())
                continue;

            double newSL = 0;
            double tpPrice = NormalizeDouble(OrderTakeProfit(), eDigits);
            
            if (OrderType() == OP_BUY && buySL < MarketInfo(Instrument, MODE_BID) - stopLevel)
            {
                newSL = NormalizeDouble(buySL, eDigits);
                double pointsDiff = MathAbs(newSL - currentSL) / SymbolInfoDouble(Instrument, SYMBOL_POINT);
                if (currentSL == 0 || (newSL > currentSL && pointsDiff >= StopLossChangeThreshold))
                {
                    ModifyOrder(OrderTicket(), openPrice, newSL, tpPrice);
                }
            }
            else if (OrderType() == OP_SELL && sellSL > MarketInfo(Instrument, MODE_ASK) + stopLevel)
            {
                newSL = NormalizeDouble(sellSL + spread, eDigits);
                double pointsDiff = MathAbs(newSL - currentSL) / SymbolInfoDouble(Instrument, SYMBOL_POINT);
                if (currentSL == 0 || (newSL < currentSL && pointsDiff >= StopLossChangeThreshold))
                {
                    ModifyOrder(OrderTicket(), openPrice, newSL, tpPrice);
                }
            }
        }
    }
}

// 封装订单修改错误处理
bool TryModifyOrder(int ticket, double openPrice, double slPrice, double tpPrice)
{
    if (!OrderSelect(ticket, SELECT_BY_TICKET))
    {
        int error = GetLastError();
        Print("ERROR - SELECT TICKET - error selecting order ", ticket, ": ", error, " - ", GetLastErrorText(error));
        return false;
    }
    
    string symbol = OrderSymbol();
    int eDigits = (int)MarketInfo(symbol, MODE_DIGITS);
    slPrice = NormalizeDouble(slPrice, eDigits);
    tpPrice = NormalizeDouble(tpPrice, eDigits);
    
    for (int i = 1; i <= OrderOpRetry; i++)
    {
        if (OrderModify(ticket, openPrice, slPrice, tpPrice, 0, clrBlue))
        {
            Print("TRADE - UPDATE SUCCESS - Order ", ticket, " in ", symbol, ": new stop-loss ", slPrice, " new take-profit ", tpPrice);
            NotifyStopLossUpdate(ticket, slPrice, symbol);
            return true;
        }
        else
        {
            int error = GetLastError();
            string errorText = GetLastErrorText(error);
            Print("ERROR - UPDATE FAILED - error modifying order ", ticket, " in ", symbol, ": ", error,
                  " Open=", openPrice, " Old SL=", OrderStopLoss(), " Old TP=", OrderTakeProfit(),
                  " New SL=", slPrice, " New TP=", tpPrice,
                  " Bid=", MarketInfo(symbol, MODE_BID), " Ask=", MarketInfo(symbol, MODE_ASK));
            Print("ERROR - ", errorText);
        }
    }
    return false;
}

void ModifyOrder(int Ticket, double OpenPrice, double SLPrice, double TPPrice)
{
    TryModifyOrder(Ticket, OpenPrice, SLPrice, TPPrice);
}

void NotifyStopLossUpdate(int OrderNumber, double SLPrice, string symbol)
{
    if (!EnableNotify)
        return;
    if ((!SendAlert) && (!SendApp) && (!SendEmail))
        return;
    string EmailSubject = ExpertName + " " + symbol + " Notification ";
    string EmailBody = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + "\r\n" + ExpertName + " Notification for " + symbol + "\r\n";
    EmailBody += "Stop-loss for order " + IntegerToString(OrderNumber) + " moved to " + DoubleToString(SLPrice, (int)MarketInfo(symbol, MODE_DIGITS));
    string AlertText = ExpertName + " - " + symbol + " - stop-loss for order " + IntegerToString(OrderNumber) + " was moved to " + DoubleToString(SLPrice, (int)MarketInfo(symbol, MODE_DIGITS));
    string AppText = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + " - " + ExpertName + " - " + symbol + " - ";
    AppText += "stop-loss for order: " + IntegerToString(OrderNumber) + " was moved to " + DoubleToString(SLPrice, (int)MarketInfo(symbol, MODE_DIGITS)) + "";
    if (SendAlert)
        Alert(AlertText);
    if (SendEmail)
    {
        if (!SendMail(EmailSubject, EmailBody))
            Print("Error sending email " + IntegerToString(GetLastError()));
    }
    if (SendApp)
    {
        if (!SendNotification(AppText))
            Print("Error sending notification " + IntegerToString(GetLastError()));
    }
}

string PanelBase = ExpertName + "-P-BAS";
string PanelLabel = ExpertName + "-P-LAB";
string PanelEnableDisable = ExpertName + "-P-ENADIS";
string PanelBreakEven = ExpertName + "-P-BEVEN";
// 绘制面板按钮的通用函数
void DrawPanelButton(string objName, int &row, string text, string tooltip, bool enabled, bool locked = false)
{
    string buttonText = "";
    color textColor = clrNavy;
    color bgColor = clrKhaki;
    
    if (locked) {
        buttonText = text + " LOCKED";
        textColor = clrGray;
        bgColor = clrLightGray;
    }
    else if (enabled) {
        buttonText = text + " ENABLED";
        textColor = clrWhite;
        bgColor = clrDarkGreen;
    }
    else {
        buttonText = text + " DISABLED";
        textColor = clrWhite;
        bgColor = clrDarkRed;
    }
    
    DrawEdit(objName,
             Xoff + 2,
             Yoff + (PanelMovY + 1) * row + 2,
             PanelLabX,
             PanelLabY,
             true,
             8,
             tooltip,
             ALIGN_CENTER,
             "Consolas",
             buttonText,
             false,
             textColor,
             bgColor,
             clrBlack);
             
    row++;
}

void DrawPanel()
{
    string PanelText = "MQLTA ATRTS";
    string PanelToolTip = "ATR Trailing Stop-Loss By EarnForex.com";

    int Rows = 1;
    if (ObjectFind(0, PanelBase) < 0)
        ObjectCreate(0, PanelBase, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, PanelBase, OBJPROP_XDISTANCE, Xoff);
    ObjectSetInteger(0, PanelBase, OBJPROP_YDISTANCE, Yoff);
    ObjectSetInteger(0, PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 2) * 1 + 2);
    ObjectSetInteger(0, PanelBase, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetInteger(0, PanelBase, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, PanelBase, OBJPROP_STATE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, PanelBase, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, PanelBase, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_COLOR, clrBlack);

    DrawEdit(PanelLabel,
             Xoff + 2,
             Yoff + 2,
             PanelLabX,
             PanelLabY,
             true,
             10,
             PanelToolTip,
             ALIGN_CENTER,
             "Consolas",
             PanelText,
             false,
             clrNavy,
             clrKhaki,
             clrBlack);

    // 使用通用函数绘制各个按钮
    DrawPanelButton(PanelEnableDisable, Rows, "TRAILING", "Click to Enable or Disable the Trailing Stop Feature", EnableTrailing);
    DrawPanelButton(PanelBreakEven, Rows, "BREAK EVEN", "Click to Enable or Disable the Break Even Feature", EnableBreakEven);
    DrawPanelButton(PanelATRAfterBreakEven, Rows, "ATR AFTER BE", "只有在达到保本条件后才启用ATR追踪止损", EnableATRAfterBreakEven, !EnableBreakEven);

    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 1) * Rows + 3);
}

void CleanPanel()
{
    ObjectsDeleteAll(0, ExpertName + "-P-");
}

void ChangeTrailingEnabled()
{
    if (EnableTrailing == false)
    {
        if (IsTradeAllowed())
            EnableTrailing = true;
        else
        {
            MessageBox("You need to first enable Live Trading in the EA options.", "WARNING", MB_OK);
        }
    }
    else
        EnableTrailing = false;
    DrawPanel();
}

void ChangeBreakEvenEnabled()
{
    if (EnableBreakEven == false)
    {
        if (IsTradeAllowed())
            EnableBreakEven = true;
        else
        {
            MessageBox("You need to first enable Live Trading in the EA options.", "WARNING", MB_OK);
        }
    }
    else
        EnableBreakEven = false;
    DrawPanel();
}

void ChangeATRAfterBreakEvenEnabled()
{
    if (!EnableBreakEven)
    {
        MessageBox("请先启用Break Even功能。", "警告", MB_OK);
        return;
    }

    if (EnableATRAfterBreakEven == false)
    {
        if (IsTradeAllowed())
            EnableATRAfterBreakEven = true;
        else
        {
            MessageBox("You need to first enable Live Trading in the EA options.", "WARNING", MB_OK);
        }
    }
    else
        EnableATRAfterBreakEven = false;
    DrawPanel();
}

// 合并保本条件检查和价格计算
bool CheckBreakEvenCondition()
{
    if (!EnableBreakEven) return false;
    
    string symbol = OrderSymbol();
    double commission = ConsiderCommissionInBreakEven ? MathAbs(OrderCommission()) : 0;
    double orderProfit = OrderProfit();
    double spread = MarketInfo(symbol, MODE_SPREAD) * MarketInfo(symbol, MODE_POINT);
    
    double profit = orderProfit - spread;
    if (ConsiderCommissionInBreakEven)
        profit -= commission;
    
    return (profit >= ProfitForBreakEven);
}

double GetBreakEvenPrice(int type, double openPrice, double spread)
{
    double commission = ConsiderCommissionInBreakEven ? MathAbs(OrderCommission()) : 0;
    
    if (type == OP_BUY)
        return openPrice + commission + spread;
    else if (type == OP_SELL)
        return openPrice - commission - spread;
    
    return openPrice;
}
//+------------------------------------------------------------------+