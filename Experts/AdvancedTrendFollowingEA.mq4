//+------------------------------------------------------------------+
//|                                    AdvancedTrendFollowingEA.mq4 |
//|                        Copyright 2025, Advanced Trading Systems |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Advanced Trading Systems"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| 外部参数设置                                                      |
//+------------------------------------------------------------------+
// === 基础设置 ===
input string    BasicSettings = "=== 基础设置 ===";
input double    LotSize = 0.1;                    // 固定手数
input bool      UseAutoLot = true;                // 使用自动手数
input double    RiskPercent = 2.0;                // 风险百分比
input int       MagicNumber = 12345;              // 魔术数字
input int       Slippage = 3;                     // 滑点

// === 趋势识别策略选择 ===
input string    TrendStrategy = "=== 趋势策略 ===";
input bool      UseEMACross = true;               // 使用EMA交叉
input bool      UseDonchianBreakout = true;       // 使用唐奇安突破
input bool      UseMACDTrend = false;             // 使用MACD趋势
input bool      UseADXFilter = true;              // 使用ADX过滤

// === EMA交叉参数 ===
input string    EMASettings = "=== EMA设置 ===";
input int       FastEMA = 12;                     // 快线周期
input int       SlowEMA = 26;                     // 慢线周期
input int       TrendEMA = 50;                    // 趋势线周期

// === 唐奇安通道参数 ===
input string    DonchianSettings = "=== 唐奇安设置 ===";
input int       DonchianPeriod = 20;              // 唐奇安周期

// === MACD参数 ===
input string    MACDSettings = "=== MACD设置 ===";
input int       MACD_Fast = 12;                   // MACD快线
input int       MACD_Slow = 26;                   // MACD慢线
input int       MACD_Signal = 9;                  // MACD信号线

// === ADX过滤参数 ===
input string    ADXSettings = "=== ADX设置 ===";
input int       ADXPeriod = 14;                   // ADX周期
input double    ADXThreshold = 25.0;              // ADX阈值

// === ATR止损参数 ===
input string    ATRSettings = "=== ATR止损设置 ===";
input int       ATRPeriod = 14;                   // ATR周期
input double    ATRMultiplier = 2.0;              // ATR乘数
input bool      UseTrailingStop = true;           // 使用追踪止损
input double    TrailingStep = 0.5;               // 追踪步长倍数

// === 止盈设置 ===
input string    TPSettings = "=== 止盈设置 ===";
input bool      UseFixedTP = false;               // 使用固定止盈
input double    FixedTPPips = 100;                // 固定止盈点数
input bool      UseATRTP = true;                  // 使用ATR止盈
input double    ATRTPMultiplier = 3.0;            // ATR止盈乘数

// === 时间过滤 ===
input string    TimeFilter = "=== 时间过滤 ===";
input bool      UseTimeFilter = false;            // 使用时间过滤
input int       StartHour = 8;                    // 开始小时
input int       EndHour = 18;                     // 结束小时

// === 风险管理 ===
input string    RiskManagement = "=== 风险管理 ===";
input int       MaxPositions = 1;                 // 最大持仓数
input double    MaxDailyLoss = 5.0;               // 最大日损失百分比
input bool      UseBreakEven = true;              // 使用保本
input double    BreakEvenPips = 20;               // 保本触发点数

//+------------------------------------------------------------------+
//| 全局变量                                                          |
//+------------------------------------------------------------------+
double g_dailyStartBalance = 0;
datetime g_lastBarTime = 0;
bool g_newBar = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 初始化日开始余额
   g_dailyStartBalance = AccountBalance();
   g_lastBarTime = Time[0];
   
   Print("高级趋势跟踪EA启动成功");
   Print("策略组合: EMA交叉=", UseEMACross, " 唐奇安突破=", UseDonchianBreakout, 
         " MACD趋势=", UseMACDTrend, " ADX过滤=", UseADXFilter);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("高级趋势跟踪EA停止运行");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 检查新K线
   CheckNewBar();
   
   // 风险管理检查
   if(!RiskManagementCheck()) return;
   
   // 时间过滤
   if(UseTimeFilter && !IsTimeToTrade()) return;
   
   // 只在新K线时执行交易逻辑
   if(!g_newBar) 
   {
      // 管理现有订单
      ManageOrders();
      return;
   }
   
   // 获取趋势信号
   int trendSignal = GetTrendSignal();
   
   // 执行交易
   if(trendSignal == 1 && CountOrders(OP_BUY) < MaxPositions)
   {
      OpenBuyOrder();
   }
   else if(trendSignal == -1 && CountOrders(OP_SELL) < MaxPositions)
   {
      OpenSellOrder();
   }
   
   // 管理现有订单
   ManageOrders();
}

//+------------------------------------------------------------------+
//| 检查新K线                                                         |
//+------------------------------------------------------------------+
void CheckNewBar()
{
   if(Time[0] != g_lastBarTime)
   {
      g_newBar = true;
      g_lastBarTime = Time[0];
      
      // 每日重置
      if(TimeHour(Time[0]) == 0 && TimeMinute(Time[0]) == 0)
      {
         g_dailyStartBalance = AccountBalance();
      }
   }
   else
   {
      g_newBar = false;
   }
}

//+------------------------------------------------------------------+
//| 获取综合趋势信号                                                   |
//+------------------------------------------------------------------+
int GetTrendSignal()
{
   int signals = 0;
   int totalStrategies = 0;
   
   // EMA交叉信号
   if(UseEMACross)
   {
      signals += GetEMASignal();
      totalStrategies++;
   }
   
   // 唐奇安突破信号
   if(UseDonchianBreakout)
   {
      signals += GetDonchianSignal();
      totalStrategies++;
   }
   
   // MACD趋势信号
   if(UseMACDTrend)
   {
      signals += GetMACDSignal();
      totalStrategies++;
   }
   
   // ADX过滤
   if(UseADXFilter)
   {
      double adx = iADX(NULL, 0, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
      if(adx < ADXThreshold)
      {
         return 0; // 趋势不够强，不交易
      }
   }
   
   // 需要至少一半的策略同意
   if(totalStrategies > 0)
   {
      if(signals >= totalStrategies * 0.5) return 1;      // 买入
      if(signals <= -totalStrategies * 0.5) return -1;    // 卖出
   }
   
   return 0; // 无信号
}

//+------------------------------------------------------------------+
//| EMA交叉信号                                                       |
//+------------------------------------------------------------------+
int GetEMASignal()
{
   double fastEMA_0 = iMA(NULL, 0, FastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double fastEMA_1 = iMA(NULL, 0, FastEMA, 0, MODE_EMA, PRICE_CLOSE, 2);
   double slowEMA_0 = iMA(NULL, 0, SlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double slowEMA_1 = iMA(NULL, 0, SlowEMA, 0, MODE_EMA, PRICE_CLOSE, 2);
   double trendEMA = iMA(NULL, 0, TrendEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   
   // 金叉且价格在趋势线上方
   if(fastEMA_1 <= slowEMA_1 && fastEMA_0 > slowEMA_0 && Close[1] > trendEMA)
      return 1;
   
   // 死叉且价格在趋势线下方
   if(fastEMA_1 >= slowEMA_1 && fastEMA_0 < slowEMA_0 && Close[1] < trendEMA)
      return -1;
   
   return 0;
}

//+------------------------------------------------------------------+
//| 唐奇安突破信号                                                     |
//+------------------------------------------------------------------+
int GetDonchianSignal()
{
   double upperBand = iHighest(NULL, 0, MODE_HIGH, DonchianPeriod, 1);
   double lowerBand = iLowest(NULL, 0, MODE_LOW, DonchianPeriod, 1);
   
   // 突破上轨
   if(Close[1] > upperBand)
      return 1;
   
   // 突破下轨
   if(Close[1] < lowerBand)
      return -1;
   
   return 0;
}

//+------------------------------------------------------------------+
//| MACD趋势信号                                                      |
//+------------------------------------------------------------------+
int GetMACDSignal()
{
   double macd_0 = iMACD(NULL, 0, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE, MODE_MAIN, 1);
   double macd_1 = iMACD(NULL, 0, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE, MODE_MAIN, 2);
   double signal_0 = iMACD(NULL, 0, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE, MODE_SIGNAL, 1);
   double signal_1 = iMACD(NULL, 0, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE, MODE_SIGNAL, 2);
   
   // MACD金叉
   if(macd_1 <= signal_1 && macd_0 > signal_0 && macd_0 > 0)
      return 1;
   
   // MACD死叉
   if(macd_1 >= signal_1 && macd_0 < signal_0 && macd_0 < 0)
      return -1;
   
   return 0;
}

//+------------------------------------------------------------------+
//| 开多单                                                            |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
   double lots = CalculateLotSize();
   double atr = iATR(NULL, 0, ATRPeriod, 1);
   double stopLoss = Ask - atr * ATRMultiplier;
   double takeProfit = 0;
   
   if(UseFixedTP)
      takeProfit = Ask + FixedTPPips * Point;
   else if(UseATRTP)
      takeProfit = Ask + atr * ATRTPMultiplier;
   
   int ticket = OrderSend(Symbol(), OP_BUY, lots, Ask, Slippage, stopLoss, takeProfit, 
                         "趋势跟踪买入", MagicNumber, 0, clrGreen);
   
   if(ticket > 0)
   {
      Print("买入订单成功: 票号=", ticket, " 手数=", lots, " 价格=", Ask);
   }
   else
   {
      Print("买入订单失败: 错误=", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| 开空单                                                            |
//+------------------------------------------------------------------+
void OpenSellOrder()
{
   double lots = CalculateLotSize();
   double atr = iATR(NULL, 0, ATRPeriod, 1);
   double stopLoss = Bid + atr * ATRMultiplier;
   double takeProfit = 0;
   
   if(UseFixedTP)
      takeProfit = Bid - FixedTPPips * Point;
   else if(UseATRTP)
      takeProfit = Bid - atr * ATRTPMultiplier;
   
   int ticket = OrderSend(Symbol(), OP_SELL, lots, Bid, Slippage, stopLoss, takeProfit, 
                         "趋势跟踪卖出", MagicNumber, 0, clrRed);
   
   if(ticket > 0)
   {
      Print("卖出订单成功: 票号=", ticket, " 手数=", lots, " 价格=", Bid);
   }
   else
   {
      Print("卖出订单失败: 错误=", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| 计算手数                                                          |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   if(!UseAutoLot)
      return LotSize;
   
   double atr = iATR(NULL, 0, ATRPeriod, 1);
   double riskAmount = AccountBalance() * RiskPercent / 100.0;
   double stopLossDistance = atr * ATRMultiplier;
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   
   double lots = riskAmount / (stopLossDistance / tickSize * tickValue);
   
   // 限制手数范围
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   
   lots = MathMax(minLot, MathMin(maxLot, lots));
   
   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| 管理订单                                                          |
//+------------------------------------------------------------------+
void ManageOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            // 追踪止损
            if(UseTrailingStop)
               TrailingStop(OrderTicket());
            
            // 保本
            if(UseBreakEven)
               BreakEven(OrderTicket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 追踪止损                                                          |
//+------------------------------------------------------------------+
void TrailingStop(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return;
   
   double atr = iATR(NULL, 0, ATRPeriod, 1);
   double trailDistance = atr * ATRMultiplier * TrailingStep;
   
   if(OrderType() == OP_BUY)
   {
      double newStop = Bid - trailDistance;
      if(newStop > OrderStopLoss() + Point || OrderStopLoss() == 0)
      {
         bool result = OrderModify(ticket, OrderOpenPrice(), newStop, OrderTakeProfit(), 0, clrBlue);
         if(!result)
         {
            Print("买单追踪止损修改失败: 错误=", GetLastError());
         }
      }
   }
   else if(OrderType() == OP_SELL)
   {
      double newStop = Ask + trailDistance;
      if(newStop < OrderStopLoss() - Point || OrderStopLoss() == 0)
      {
         bool result = OrderModify(ticket, OrderOpenPrice(), newStop, OrderTakeProfit(), 0, clrBlue);
         if(!result)
         {
            Print("卖单追踪止损修改失败: 错误=", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 保本功能                                                          |
//+------------------------------------------------------------------+
void BreakEven(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return;
   
   double breakEvenDistance = BreakEvenPips * Point;
   
   if(OrderType() == OP_BUY)
   {
      if(Bid >= OrderOpenPrice() + breakEvenDistance && OrderStopLoss() < OrderOpenPrice())
      {
         bool result = OrderModify(ticket, OrderOpenPrice(), OrderOpenPrice(), OrderTakeProfit(), 0, clrYellow);
         if(!result)
         {
            Print("买单保本修改失败: 错误=", GetLastError());
         }
      }
   }
   else if(OrderType() == OP_SELL)
   {
      if(Ask <= OrderOpenPrice() - breakEvenDistance && OrderStopLoss() > OrderOpenPrice())
      {
         bool result = OrderModify(ticket, OrderOpenPrice(), OrderOpenPrice(), OrderTakeProfit(), 0, clrYellow);
         if(!result)
         {
            Print("卖单保本修改失败: 错误=", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 统计订单数量                                                       |
//+------------------------------------------------------------------+
int CountOrders(int orderType)
{
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == orderType)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| 风险管理检查                                                       |
//+------------------------------------------------------------------+
bool RiskManagementCheck()
{
   // 检查最大日损失
   double currentBalance = AccountBalance();
   double dailyLoss = (g_dailyStartBalance - currentBalance) / g_dailyStartBalance * 100.0;
   
   if(dailyLoss > MaxDailyLoss)
   {
      Print("达到最大日损失限制: ", dailyLoss, "%");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| 时间过滤                                                          |
//+------------------------------------------------------------------+
bool IsTimeToTrade()
{
   int currentHour = TimeHour(TimeCurrent());
   return (currentHour >= StartHour && currentHour < EndHour);
}