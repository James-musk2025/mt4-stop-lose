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
#define ESC_KEY_CODE 27
#define DPI_BASE_VALUE 96.0
#define DEFAULT_RETRY_COUNT 5
#define PANEL_FONT_SIZE 8
#define PANEL_TITLE_FONT_SIZE 10

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
input double ATRMultiplier = 3.0;                 // ATR Multiplier
input int StopLossChangeThreshold = 50;           // Minimum Points To Move Stop Loss
input string Comment_2 = "====================";  // Orders Filtering Options
input bool OnlyCurrentSymbol = true;              // Apply To Current Symbol Only
input ENUM_CONSIDER OnlyType = All;               // Apply To
input bool UseMagic = false;                      // Filter By Magic Number
input int MagicNumber = 0;                        // Magic Number (if above is true)
input bool UseComment = false;                    // Filter By Comment
input string CommentFilter = "";                  // Comment (if above is true)
input bool EnableTrailingParam = true;            // Enable Trailing Stop
input bool EnableBreakEvenParam = true;           // Enable Break Even
input bool EnableATRAfterBreakEvenParam = false;  // Enable ATR After Break Even
input int pipsForBreakEven = 500;                 // Pips Required for Break Even
input bool ConsiderCommissionInBreakEven = false; // Consider Commission in Break Even
input string Comment_3 = "====================";  // Take Profit Options
input bool EnableTakeProfitParam = true;         // Enable Take Profit
input int TakeProfitPips = 2000;                   // Take Profit Pips
input string Comment_3a = "====================";  // Notification Options
input bool EnableNotify = false;                  // Enable Notifications feature
input bool SendAlert = true;                      // Send Alert Notification
input bool SendApp = true;                        // Send Notification to Mobile
input bool SendEmail = true;                      // Send Notification via Email
input string Comment_3b = "===================="; // Graphical Window
input bool ShowPanel = true;                      // Show Graphical Panel
input string ExpertName = "MQLTA-ATRTS";          // Expert Name (to name the objects)
input int Xoff = 20;                              // Horizontal spacing for the control panel
input int Yoff = 20;                              // Vertical spacing for the control panel

int OrderOpRetry = DEFAULT_RETRY_COUNT;
bool EnableTrailing = EnableTrailingParam;
bool EnableBreakEven = EnableBreakEvenParam;
double DPIScale; // Scaling parameter for the panel based on the screen DPI.
int PanelMovX, PanelMovY, PanelLabX, PanelLabY, PanelRecX;
bool EnableATRAfterBreakEven = EnableATRAfterBreakEvenParam;
bool EnableTakeProfit = EnableTakeProfitParam;
string PanelATRAfterBreakEven = ExpertName + "-P-ATRBE";
string PanelTakeProfit = ExpertName + "-P-TP";

struct mMarketInfo
{
    string symbol;
    double bid, ask, point, spread, stopLevel;
    int digits;
    double tickSize;

    void Update(string sym)
    {
        symbol = sym;
        bid = MarketInfo(symbol, MODE_BID);
        ask = MarketInfo(symbol, MODE_ASK);
        point = MarketInfo(symbol, MODE_POINT);
        spread = MarketInfo(symbol, MODE_SPREAD) * point;
        stopLevel = MarketInfo(symbol, MODE_STOPLEVEL) * point;
        digits = (int)MarketInfo(symbol, MODE_DIGITS);
        tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    }
};

int OnInit()
{
    EnableTrailing = EnableTrailingParam;
    EnableBreakEven = EnableBreakEvenParam;
    EnableATRAfterBreakEven = EnableATRAfterBreakEvenParam;

    DPIScale = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI) / DPI_BASE_VALUE;

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
    if (EnableTrailing || EnableBreakEven || EnableTakeProfit) // 检查是否启用了任一功能
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
        HandlePanelClick(sparam);
    }
    else if (id == CHARTEVENT_KEYDOWN)
    {
        HandleKeyPress(lparam);
    }
}

void HandlePanelClick(const string &objectName)
{
    if (objectName == PanelEnableDisable)
    {
        ChangeTrailingEnabled();
    }
    else if (objectName == PanelBreakEven)
    {
        ChangeBreakEvenEnabled();
        // 如果关闭保本功能，同时关闭ATR After Break Even
        if (!EnableBreakEven)
            EnableATRAfterBreakEven = false;
    }
    else if (objectName == PanelATRAfterBreakEven)
    {
        ChangeATRAfterBreakEvenEnabled();
    }
    else if (objectName == PanelTakeProfit)
    {
        ChangeTakeProfitEnabled();
    }
}

void HandleKeyPress(const long keyCode)
{
    if (keyCode == ESC_KEY_CODE)
    {
        if (MessageBox("Are you sure you want to close the EA?", "EXIT ?", MB_YESNO) == IDYES)
        {
            ExpertRemove();
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

bool SelectAndValidateOrder(int index)
{
    if (!OrderSelect(index, SELECT_BY_POS, MODE_TRADES))
    {
        int error = GetLastError();
        Print("ERROR - Unable to select order - ", error, ": ", GetLastErrorText(error));
        return false;
    }
    return ShouldProcessOrder();
}

void TrailingStop()
{
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (SelectAndValidateOrder(i))
        {
            // 处理单个订单
            ProcessSingleOrder();
        }
    }
}

// 处理保本逻辑
void ProcessBreakEven(mMarketInfo &market)
{
    double openPrice = OrderOpenPrice();
    double breakEvenPrice = GetBreakEvenPrice(OrderType(), openPrice, market.spread);

    // 根据TickSize调整价格
    if (market.tickSize > 0)
    {
        breakEvenPrice = NormalizeDouble(MathRound(breakEvenPrice / market.tickSize) * market.tickSize, market.digits);
    }

    double currentSL = NormalizeDouble(OrderStopLoss(), market.digits);

    // 检查是否需要更新止损
    if ((currentSL == 0) ||
        (OrderType() == OP_BUY && breakEvenPrice > currentSL) ||
        (OrderType() == OP_SELL && breakEvenPrice < currentSL))
    {
        ModifyOrder(OrderTicket(), openPrice, breakEvenPrice, OrderTakeProfit());
    }
}

// 处理ATR追踪止损逻辑
void ProcessTrailing(mMarketInfo &market)
{
    if (EnableATRAfterBreakEven && !CheckBreakEvenCondition())
        return;

    double currentSL = NormalizeDouble(OrderStopLoss(), market.digits);
    double openPrice = OrderOpenPrice();
    double tpPrice = NormalizeDouble(OrderTakeProfit(), market.digits);

    if (OrderType() == OP_BUY)
    {
        TryUpdateBuyStopLoss(market, currentSL, openPrice, tpPrice);
    }
    else if (OrderType() == OP_SELL)
    {
        TryUpdateSellStopLoss(market, currentSL, openPrice, tpPrice);
    }
}

void TryUpdateBuyStopLoss(mMarketInfo &market, double currentSL, double openPrice, double tpPrice)
{
    double buySL = CalculateAndNormalizeSL(market.symbol, OP_BUY);
    if (buySL >= market.bid - market.stopLevel)
        return;

    double pointsDiff = MathAbs(buySL - currentSL) / market.point;
    if (currentSL == 0 || (buySL > currentSL && pointsDiff >= StopLossChangeThreshold))
    {
        ModifyOrder(OrderTicket(), openPrice, buySL, tpPrice);
    }
}

void TryUpdateSellStopLoss(mMarketInfo &market, double currentSL, double openPrice, double tpPrice)
{
    double sellSL = CalculateAndNormalizeSL(market.symbol, OP_SELL) + market.spread;
    if (sellSL <= market.ask + market.stopLevel)
        return;

    double pointsDiff = MathAbs(sellSL - currentSL) / market.point;
    if (currentSL == 0 || (sellSL < currentSL && pointsDiff >= StopLossChangeThreshold))
    {
        ModifyOrder(OrderTicket(), openPrice, sellSL, tpPrice);
    }
}

// 重构后的主要处理函数
void ProcessSingleOrder()
{
    mMarketInfo market;
    market.Update(OrderSymbol());

    // 验证市场数据
    double buySL = CalculateAndNormalizeSL(market.symbol, OP_BUY);
    double sellSL = CalculateAndNormalizeSL(market.symbol, OP_SELL);

    if (buySL == 0 || sellSL == 0)
    {
        Print("Not enough historical data - please load more candles");
        return;
    }

    // 优先处理保本逻辑
    if (EnableBreakEven && CheckBreakEvenCondition())
    {
        ProcessBreakEven(market);
    }

    // 处理ATR追踪止损
    if (EnableTrailing)
    {
        ProcessTrailing(market);
    }
    
    // 处理止盈
    if (EnableTakeProfit)
    {
        ProcessTakeProfit(market);
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

    if (locked)
    {
        buttonText = text + " LOCKED";
        textColor = clrGray;
        bgColor = clrLightGray;
    }
    else if (enabled)
    {
        buttonText = text + " ENABLED";
        textColor = clrWhite;
        bgColor = clrDarkGreen;
    }
    else
    {
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
             PANEL_FONT_SIZE,
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
             PANEL_TITLE_FONT_SIZE,
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
    DrawPanelButton(PanelATRAfterBreakEven, Rows, "ATR AFTER BE", "只有在达到保本条件后才启用ATR追踪止损", EnableATRAfterBreakEven, !EnableBreakEven || !EnableTrailing);
    DrawPanelButton(PanelTakeProfit, Rows, "TAKE PROFIT", "Click to Enable or Disable Take Profit Feature", EnableTakeProfit);

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

    if (!EnableTrailing)
    {
        MessageBox("请先启用TRAILING功能。", "警告", MB_OK);
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

void ChangeTakeProfitEnabled()
{
    if (EnableTakeProfit == false)
    {
        if (IsTradeAllowed())
            EnableTakeProfit = true;
        else
        {
            MessageBox("You need to first enable Live Trading in the EA options.", "WARNING", MB_OK);
        }
    }
    else
        EnableTakeProfit = false;
    DrawPanel();
}

/*
 * CheckBreakEvenCondition: 检查当前订单是否达到保本条件
 * 正确计算利润和佣金对应的点数
 */
bool CheckBreakEvenCondition()
{
    if (!EnableBreakEven)
        return false;

    string symbol = OrderSymbol();
    double point = MarketInfo(symbol, MODE_POINT);
    double tickValue = MarketInfo(symbol, MODE_TICKVALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double lots = OrderLots();
    int digits = (int)MarketInfo(OrderSymbol(), MODE_DIGITS);

    // 计算每点价值（账户货币/点）
    double valuePerPoint = (tickSize > 0) ? tickValue * (point / tickSize) : tickValue;

    // 计算利润点数
    double profitPoints = (valuePerPoint > 0 && lots > 0) ? OrderProfit() / (valuePerPoint * lots) : 0;

    // 计算佣金点数
    double commissionPoints = 0;
    if (ConsiderCommissionInBreakEven && valuePerPoint > 0 && lots > 0)
    {
        commissionPoints = MathAbs(OrderCommission()) / (valuePerPoint * lots);
    }

    // 点差本身就是点数
    double spreadPoints = MarketInfo(symbol, MODE_SPREAD);

    // 计算净利润点数
    double netProfitPoints = NormalizeDouble((profitPoints - spreadPoints - commissionPoints), digits);

    return (netProfitPoints >= pipsForBreakEven);
}

/*
 * GetBreakEvenPrice: 计算保本价格（Break Even Price）
 *
 * 保本价格是订单达到盈亏平衡点（不赚不赔）的价格水平：
 * - 对于买单：开仓价 + 点差 + 佣金对应的价格调整量
 * - 对于卖单：开仓价 - 点差 - 佣金对应的价格调整量
 *
 * 佣金调整量 = (总佣金 / (TickValue * 手数)) * Point
 *
 * 参数：
 *   type: 订单类型 (OP_BUY/OP_SELL)
 *   openPrice: 开仓价格
 *   spread: 点差成本（价格值）
 *
 * 返回：计算出的保本价格
 */
double GetBreakEvenPrice(int type, double openPrice, double spread)
{
    double commission = ConsiderCommissionInBreakEven ? MathAbs(OrderCommission()) : 0;
    double commissionAdjustment = 0;
    int digits = (int)MarketInfo(OrderSymbol(), MODE_DIGITS);

    if (commission > 0)
    {
        string symbol = OrderSymbol();
        double tickValue = MarketInfo(symbol, MODE_TICKVALUE);
        double point = MarketInfo(symbol, MODE_POINT);
        double lots = OrderLots();

        if (tickValue > 0 && lots > 0)
        {
            // 计算佣金对应的点数
            double commissionPoints = commission / (tickValue * lots);
            // 转换为价格调整量
            commissionAdjustment = commissionPoints * point;
        }
    }

    if (type == OP_BUY)
        return NormalizeDouble((openPrice + spread + commissionAdjustment), digits); // 买单需要覆盖点差和佣金
    else if (type == OP_SELL)
        return NormalizeDouble((openPrice - spread - commissionAdjustment), digits); // 卖单需要覆盖点差和佣金

    return openPrice; // 未知订单类型返回开仓价
}
// 处理止盈逻辑
void ProcessTakeProfit(mMarketInfo &market)
{
    double currentTP = NormalizeDouble(OrderTakeProfit(), market.digits);
    double newTP = CalculateTakeProfitPrice(OrderType(), OrderOpenPrice(), market);
    
    // 规范化价格
    newTP = NormalizeDouble(newTP, market.digits);
    
    // 验证止盈价有效性
    bool validTP = false;
    if (OrderType() == OP_BUY)
    {
        validTP = (newTP > market.ask + market.stopLevel);
    }
    else if (OrderType() == OP_SELL)
    {
        validTP = (newTP < market.bid - market.stopLevel);
    }
    
    // 检查是否需要更新止盈
    if (validTP && (currentTP == 0 || MathAbs(newTP - currentTP) / market.point >= StopLossChangeThreshold))
    {
        ModifyOrder(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), newTP);
    }
    else if (!validTP)
    {
        Print("WARNING: Invalid TakeProfit price ", newTP, " for ", OrderTypeToString(OrderType()),
              " order. Ask=", market.ask, " Bid=", market.bid, " StopLevel=", market.stopLevel);
    }
}

// 计算止盈价格
double CalculateTakeProfitPrice(int orderType, double openPrice, mMarketInfo &market)
{
    if (orderType == OP_BUY)
        return openPrice + TakeProfitPips * market.point;
    else if (orderType == OP_SELL)
        return openPrice - TakeProfitPips * market.point;
    return 0;
}

string OrderTypeToString(int type)
{
    switch(type)
    {
        case OP_BUY: return "BUY";
        case OP_SELL: return "SELL";
        case OP_BUYLIMIT: return "BUY LIMIT";
        case OP_SELLLIMIT: return "SELL LIMIT";
        case OP_BUYSTOP: return "BUY STOP";
        case OP_SELLSTOP: return "SELL STOP";
        default: return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+