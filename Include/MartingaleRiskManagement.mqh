//+------------------------------------------------------------------+
//|                                                RiskManagement.mqh |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property strict

//+------------------------------------------------------------------+
//| 风险管理类                                                       |
//+------------------------------------------------------------------+
class MartingaleRiskManagement
{
private:
    string m_symbol;
    double m_point;
    int m_digits;

public:
    MartingaleRiskManagement(string symbol);
    ~MartingaleRiskManagement();

    // 计算动态手数基于风险百分比
    double CalculateLotSize(double riskPercent, int martingaleMultiplier = 1);

    // 检查保证金安全
    bool CheckMarginSafety(double lotSize);

    // 获取当前亏损单数量
    int GetLossPositionCount();

    // 获取最大连续亏损次数
    int GetMaxConsecutiveLosses();

    // 计算止损价格
    double CalculateStopLossPrice(int orderType, double stopLossPoints);

    // 计算止盈价格
    double CalculateTakeProfitPrice(int orderType, double takeProfitPoints);

    // 应用移动止损
    void ApplyTrailingStop(int ticket, double trailingStopPoints);

    // 检查全局止损条件
    bool CheckGlobalStopLoss(double maxDrawdownPercent);
};

//+------------------------------------------------------------------+
//| 构造函数                                                         |
//+------------------------------------------------------------------+
MartingaleRiskManagement::MartingaleRiskManagement(string symbol)
{
    m_symbol = symbol;
    m_point = MarketInfo(symbol, MODE_POINT);
    m_digits = (int)MarketInfo(symbol, MODE_DIGITS);
}

//+------------------------------------------------------------------+
//| 析构函数                                                         |
//+------------------------------------------------------------------+
MartingaleRiskManagement::~MartingaleRiskManagement()
{
}

//+------------------------------------------------------------------+
//| 计算动态手数基于风险百分比                                       |
//+------------------------------------------------------------------+
double MartingaleRiskManagement::CalculateLotSize(double riskPercent, int martingaleMultiplier)
{
    double accountEquity = AccountEquity();
    double riskAmount = accountEquity * riskPercent / 100.0;

    // 获取当前价格和止损点数（假设固定止损点数）
    double stopLossPoints = 100; // 默认100点止损
    double tickValue = MarketInfo(m_symbol, MODE_TICKVALUE);

    if (tickValue == 0)
        return 0.01;

    // 计算手数
    double lotSize = riskAmount / (stopLossPoints * tickValue);

    // 应用马丁格尔乘数
    lotSize *= martingaleMultiplier;

    // 调整到允许的最小/最大手数
    double minLot = MarketInfo(m_symbol, MODE_MINLOT);
    double maxLot = MarketInfo(m_symbol, MODE_MAXLOT);
    double lotStep = MarketInfo(m_symbol, MODE_LOTSTEP);

    lotSize = MathMax(lotSize, minLot);
    lotSize = MathMin(lotSize, maxLot);
    lotSize = MathRound(lotSize / lotStep) * lotStep;

    return lotSize;
}

//+------------------------------------------------------------------+
//| 检查保证金安全                                                   |
//+------------------------------------------------------------------+
bool MartingaleRiskManagement::CheckMarginSafety(double lotSize)
{
    double marginRequired = MarketInfo(m_symbol, MODE_MARGINREQUIRED) * lotSize;
    double freeMargin = AccountFreeMargin();

    // 保证金使用率不超过80%
    return freeMargin >= marginRequired * 0.8;
}

//+------------------------------------------------------------------+
//| 获取当前亏损单数量                                               |
//+------------------------------------------------------------------+
int MartingaleRiskManagement::GetLossPositionCount()
{
    int lossCount = 0;
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if (OrderSymbol() == m_symbol && OrderProfit() < 0)
                lossCount++;
        }
    }
    return lossCount;
}

//+------------------------------------------------------------------+
//| 获取最大连续亏损次数                                             |
//+------------------------------------------------------------------+
int MartingaleRiskManagement::GetMaxConsecutiveLosses()
{
    // 简化版本：返回当前亏损单数量
    return GetLossPositionCount();
}

//+------------------------------------------------------------------+
//| 计算止损价格                                                     |
//+------------------------------------------------------------------+
double MartingaleRiskManagement::CalculateStopLossPrice(int orderType, double stopLossPoints)
{
    double currentPrice = (orderType == OP_BUY) ? MarketInfo(m_symbol, MODE_ASK) : MarketInfo(m_symbol, MODE_BID);

    if (orderType == OP_BUY)
        return currentPrice - stopLossPoints * m_point;
    else
        return currentPrice + stopLossPoints * m_point;
}

//+------------------------------------------------------------------+
//| 计算止盈价格                                                     |
//+------------------------------------------------------------------+
double MartingaleRiskManagement::CalculateTakeProfitPrice(int orderType, double takeProfitPoints)
{
    double currentPrice = (orderType == OP_BUY) ? MarketInfo(m_symbol, MODE_ASK) : MarketInfo(m_symbol, MODE_BID);

    if (orderType == OP_BUY)
        return currentPrice + takeProfitPoints * m_point;
    else
        return currentPrice - takeProfitPoints * m_point;
}

//+------------------------------------------------------------------+
//| 应用移动止损                                                     |
//+------------------------------------------------------------------+
void MartingaleRiskManagement::ApplyTrailingStop(int ticket, double trailingStopPoints)
{
    if (OrderSelect(ticket, SELECT_BY_TICKET))
    {
        double currentPrice = MarketInfo(m_symbol, MODE_BID); // 对于多单使用BID，空单使用ASK
        if (OrderType() == OP_SELL)
            currentPrice = MarketInfo(m_symbol, MODE_ASK);

        double profit = OrderProfit();
        int orderType = OrderType();

        double newStopLoss = 0;

        if (orderType == OP_BUY && profit > 0)
        {
            newStopLoss = currentPrice - trailingStopPoints * m_point;
            double currentStop = OrderStopLoss();
            if (newStopLoss > currentStop || currentStop == 0)
            {
                if (!OrderModify(ticket, OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0))
                {
                    Print("OrderModify failed for ticket ", ticket, ", error: ", GetLastError());
                }
            }
        }
        else if (orderType == OP_SELL && profit > 0)
        {
            newStopLoss = currentPrice + trailingStopPoints * m_point;
            double currentStop = OrderStopLoss();
            if (newStopLoss < currentStop || currentStop == 0)
            {
                if (!OrderModify(ticket, OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0))
                {
                    Print("OrderModify failed for ticket ", ticket, ", error: ", GetLastError());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 检查全局止损条件                                                 |
//+------------------------------------------------------------------+
bool MartingaleRiskManagement::CheckGlobalStopLoss(double maxDrawdownPercent)
{
    double equity = AccountEquity();
    double balance = AccountBalance();

    double drawdown = (balance - equity) / balance * 100.0;

    return drawdown >= maxDrawdownPercent;
}
//+------------------------------------------------------------------+