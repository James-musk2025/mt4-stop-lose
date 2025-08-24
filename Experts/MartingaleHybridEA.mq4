//+------------------------------------------------------------------+
//|                                         MartingaleHybridEA.mq4 |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

// 引入自定义库文件
#include <MartingaleSignals.mqh>
#include <MartingaleRiskManagement.mqh>

//+------------------------------------------------------------------+
//| 输入参数                                                         |
//+------------------------------------------------------------------+
//=== 策略模式设置 ===
input string MartingaleMode = "HYBRID"; // 马丁模式: SINGLE|CONTINUOUS|HYBRID
input bool EnableReversalBoost = true;  // 启用反转增强
input int MaxConsecutiveLosses = 5;     // 最大连续亏损次数

//=== 风险控制参数 ===
input double RiskPercent = 1.0;            // 单笔风险百分比
input double GlobalStopLossPercent = 20.0; // 全局止损百分比
input int StopLossPoints = 100;            // 止损点数
input int TakeProfitPoints = 200;          // 止盈点数
input int TrailingStopPoints = 50;         // 移动止损点数

//=== 信号参数 ===
input int SignalTimeframe = PERIOD_M30; // 信号时间周期
input int EMAPeriod = 20;               // EMA周期
input int RSIPeriod = 14;               // RSI周期
input double RSIThreshold = 50.0;       // RSI阈值

//=== 其他设置 ===
input int MagicNumber = 12345; // 魔术数字
input int Slippage = 3;        // 滑点

//+------------------------------------------------------------------+
//| 全局变量                                                         |
//+------------------------------------------------------------------+
MartingaleSignals *signalManager = NULL;
MartingaleRiskManagement *riskManager = NULL;

int consecutiveLosses = 0;
datetime lastTradeTime = 0;

//+------------------------------------------------------------------+
//| 专家初始化函数                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // 初始化信号管理器
    signalManager = new MartingaleSignals(Symbol(), SignalTimeframe);

    // 初始化风险管理器
    riskManager = new MartingaleRiskManagement(Symbol());

    // 参数验证
    if (RiskPercent <= 0 || RiskPercent > 5)
    {
        Print("风险百分比必须在0-5之间");
        return INIT_PARAMETERS_INCORRECT;
    }

    if (GlobalStopLossPercent <= 0 || GlobalStopLossPercent > 50)
    {
        Print("全局止损百分比必须在0-50之间");
        return INIT_PARAMETERS_INCORRECT;
    }

    Print("马丁混合策略EA初始化成功");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| 专家逆初始化函数                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // 清理对象
    if (signalManager != NULL)
        delete signalManager;

    if (riskManager != NULL)
        delete riskManager;
}

//+------------------------------------------------------------------+
//| 专家订单函数                                                     |
//+------------------------------------------------------------------+
void OnTick()
{
    // 检查全局止损条件
    if (riskManager.CheckGlobalStopLoss(GlobalStopLossPercent))
    {
        Print("触发全局止损，停止交易");
        CloseAllPositions();
        return;
    }

    // 管理现有仓位
    ManageExistingPositions();

    // 检查新交易机会
    CheckForNewTrades();
}

//+------------------------------------------------------------------+
//| 管理现有仓位                                                     |
//+------------------------------------------------------------------+
void ManageExistingPositions()
{
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            {
                // 应用移动止损
                riskManager.ApplyTrailingStop(OrderTicket(), TrailingStopPoints);

                // 检查是否需要部分平仓
                CheckPartialClose(OrderTicket());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 检查部分平仓条件                                                 |
//+------------------------------------------------------------------+
void CheckPartialClose(int ticket)
{
    if (OrderSelect(ticket, SELECT_BY_TICKET))
    {
        double profit = OrderProfit();
        double openPrice = OrderOpenPrice();
        double currentPrice = MarketInfo(Symbol(), OrderType() == OP_BUY ? MODE_BID : MODE_ASK);

        // 盈利达到50%时平一半仓位
        double profitPercent = MathAbs(profit) / (AccountBalance() * RiskPercent / 100.0);

        if (profitPercent >= 0.5)
        {
            double closeLots = OrderLots() / 2;
            if (closeLots >= MarketInfo(Symbol(), MODE_MINLOT))
            {
                if (!OrderClose(OrderTicket(), closeLots, currentPrice, Slippage))
                {
                    Print("部分平仓失败，错误代码: ", GetLastError());
                }
                else
                {
                    Print("部分平仓成功，盈利: ", profit);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 检查新交易机会                                                   |
//+------------------------------------------------------------------+
void CheckForNewTrades()
{
    // 避免频繁交易
    if (TimeCurrent() - lastTradeTime < 60)
        return;

    // 检查是否有未平仓订单
    if (HasOpenPositions())
    {
        HandleExistingPositions();
        return;
    }

    // 检查新信号
    CheckNewSignals();
}

//+------------------------------------------------------------------+
//| 处理现有仓位逻辑                                                 |
//+------------------------------------------------------------------+
void HandleExistingPositions()
{
    int lossCount = riskManager.GetLossPositionCount();

    if (lossCount > 0)
    {
        // 处理亏损仓位
        if (MartingaleMode == "CONTINUOUS")
        {
            // 连续加仓模式
            ExecuteMartingaleTrade();
        }
        else if (MartingaleMode == "HYBRID" && EnableReversalBoost)
        {
            // 混合模式：检查反转信号
            if (CheckReversalForMartingale())
            {
                ExecuteMartingaleTrade();
            }
        }
        // SINGLE模式不处理，等待新信号
    }
}

//+------------------------------------------------------------------+
//| 检查反转加仓条件                                                 |
//+------------------------------------------------------------------+
bool CheckReversalForMartingale()
{
    int trendDirection = signalManager.GetTrendDirection();

    // 获取亏损单的方向
    int lossDirection = GetLossPositionDirection();

    // 反转信号：当前趋势与亏损单方向相反
    if (trendDirection != -1 && trendDirection != lossDirection)
    {
        return signalManager.CheckReversalSignal(trendDirection);
    }

    return false;
}

//+------------------------------------------------------------------+
//| 获取亏损单方向                                                   |
//+------------------------------------------------------------------+
int GetLossPositionDirection()
{
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderProfit() < 0)
            {
                return OrderType();
            }
        }
    }
    return -1;
}

//+------------------------------------------------------------------+
//| 检查新信号                                                       |
//+------------------------------------------------------------------+
void CheckNewSignals()
{
    // 检查买入信号
    if (signalManager.CheckTripleFilterSignal(OP_BUY))
    {
        ExecuteTrade(OP_BUY, 1);
        return;
    }

    // 检查卖出信号
    if (signalManager.CheckTripleFilterSignal(OP_SELL))
    {
        ExecuteTrade(OP_SELL, 1);
        return;
    }
}

//+------------------------------------------------------------------+
//| 执行马丁加仓交易                                                 |
//+------------------------------------------------------------------+
void ExecuteMartingaleTrade()
{
    int lossDirection = GetLossPositionDirection();
    if (lossDirection == -1)
        return;

    // 计算加仓倍数（基于连续亏损次数）
    int multiplier = MathMin(consecutiveLosses + 1, MaxConsecutiveLosses);

    ExecuteTrade(lossDirection, multiplier);
}

//+------------------------------------------------------------------+
//| 执行交易                                                         |
//+------------------------------------------------------------------+
void ExecuteTrade(int orderType, int martingaleMultiplier)
{
    // 计算手数
    double lotSize = riskManager.CalculateLotSize(RiskPercent, martingaleMultiplier);

    // 检查保证金安全
    if (!riskManager.CheckMarginSafety(lotSize))
    {
        Print("保证金不足，无法开仓");
        return;
    }

    // 计算价格
    double price = (orderType == OP_BUY) ? MarketInfo(Symbol(), MODE_ASK) : MarketInfo(Symbol(), MODE_BID);
    double sl = riskManager.CalculateStopLossPrice(orderType, StopLossPoints);
    double tp = riskManager.CalculateTakeProfitPrice(orderType, TakeProfitPoints);

    // 发送订单 (MQL4参数顺序: symbol, cmd, volume, price, slippage, stoploss, takeprofit, comment, magic, expiration, arrow_color)
    int ticket = OrderSend(Symbol(), orderType, lotSize, price, Slippage, sl, tp,
                           "Martingale Hybrid", MagicNumber, 0, orderType == OP_BUY ? clrGreen : clrRed);

    if (ticket > 0)
    {
        lastTradeTime = TimeCurrent();
        Print("订单执行成功，票号: ", ticket, ", 手数: ", lotSize, ", 类型: ", orderType);

        // 更新连续亏损计数
        if (martingaleMultiplier > 1)
            consecutiveLosses++;
        else
            consecutiveLosses = 0;
    }
    else
    {
        Print("订单执行失败，错误代码: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| 检查是否有未平仓订单                                             |
//+------------------------------------------------------------------+
bool HasOpenPositions()
{
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
                return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| 关闭所有仓位                                                     |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            {
                double closePrice = MarketInfo(Symbol(), OrderType() == OP_BUY ? MODE_BID : MODE_ASK);
                if (!OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage))
                {
                    Print("OrderClose failed for ticket ", OrderTicket(), ", error: ", GetLastError());
                }
            }
        }
    }
}
//+------------------------------------------------------------------+