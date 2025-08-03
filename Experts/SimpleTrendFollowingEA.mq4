//+------------------------------------------------------------------+
//|                                      SimpleTrendFollowingEA.mq4 |
//|                        Copyright 2025, Simple Trading Solutions |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Simple Trading Solutions"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| 外部参数 - 简化版本，专注核心功能                                    |
//+------------------------------------------------------------------+
// === 基础交易设置 ===
input double    Lots = 0.1;                    // 交易手数
input bool      UseAutoLot = false;            // 使用自动手数
input double    RiskPercent = 2.0;             // 风险百分比（自动手数时）
input int       MagicNumber = 888;             // 魔术数字
input int       Slippage = 3;                  // 滑点

// === 趋势识别参数 ===
input int       FastMA = 12;                   // 快速移动平均线
input int       SlowMA = 26;                   // 慢速移动平均线
input int       TrendMA = 50;                  // 趋势过滤线
input ENUM_MA_METHOD MAMethod = MODE_EMA;      // 移动平均方法

// === ATR止损参数 ===
input int       ATRPeriod = 14;                // ATR周期
input double    ATRStopMultiplier = 2.0;       // ATR止损倍数
input double    ATRTakeMultiplier = 3.0;       // ATR止盈倍数（0=不设止盈）

// === 追踪止损设置 ===
input bool      UseTrailingStop = true;        // 使用追踪止损
input double    TrailingATRMultiplier = 1.5;   // 追踪止损ATR倍数
input int       TrailingStartPips = 20;        // 开始追踪的最小盈利点数

// === 风险控制 ===
input int       MaxOrders = 1;                 // 最大同时订单数
input bool      OnlyOneDirection = true;       // 只允许单方向持仓

//+------------------------------------------------------------------+
//| 全局变量                                                          |
//+------------------------------------------------------------------+
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("简化趋势跟踪EA启动 - 版本1.0");
   Print("策略: ", FastMA, "/", SlowMA, "MA交叉 + ATR(", ATRPeriod, ")止损");
   
   lastBarTime = Time[0];
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 只在新K线时检查信号
   if(Time[0] == lastBarTime) 
   {
      ManageOpenOrders();  // 管理现有订单
      return;
   }
   lastBarTime = Time[0];
   
   // 检查是否已有订单
   if(CountMyOrders() >= MaxOrders) 
   {
      ManageOpenOrders();
      return;
   }
   
   // 获取趋势信号
   int signal = GetTrendSignal();
   
   // 检查单方向限制
   if(OnlyOneDirection && CountMyOrders() > 0)
   {
      if((signal == 1 && HasSellOrders()) || (signal == -1 && HasBuyOrders()))
      {
         ManageOpenOrders();
         return;
      }
   }
   
   // 执行交易
   if(signal == 1)
   {
      OpenBuyOrder();
   }
   else if(signal == -1)
   {
      OpenSellOrder();
   }
   
   // 管理现有订单
   ManageOpenOrders();
}

//+------------------------------------------------------------------+
//| 获取趋势信号                                                       |
//+------------------------------------------------------------------+
int GetTrendSignal()
{
   // 获取移动平均线值
   double fastMA_0 = iMA(NULL, 0, FastMA, 0, MAMethod, PRICE_CLOSE, 1);
   double fastMA_1 = iMA(NULL, 0, FastMA, 0, MAMethod, PRICE_CLOSE, 2);
   double slowMA_0 = iMA(NULL, 0, SlowMA, 0, MAMethod, PRICE_CLOSE, 1);
   double slowMA_1 = iMA(NULL, 0, SlowMA, 0, MAMethod, PRICE_CLOSE, 2);
   double trendMA = iMA(NULL, 0, TrendMA, 0, MAMethod, PRICE_CLOSE, 1);
   
   // 检查金叉（买入信号）
   if(fastMA_1 <= slowMA_1 && fastMA_0 > slowMA_0)
   {
      // 确保价格在趋势线上方
      if(Close[1] > trendMA)
         return 1;
   }
   
   // 检查死叉（卖出信号）
   if(fastMA_1 >= slowMA_1 && fastMA_0 < slowMA_0)
   {
      // 确保价格在趋势线下方
      if(Close[1] < trendMA)
         return -1;
   }
   
   return 0;  // 无信号
}

//+------------------------------------------------------------------+
//| 开买单                                                            |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
   double lotSize = CalculateLotSize();
   double atr = iATR(NULL, 0, ATRPeriod, 1);
   
   double entry = Ask;
   double stopLoss = entry - (atr * ATRStopMultiplier);
   double takeProfit = 0;
   
   if(ATRTakeMultiplier > 0)
      takeProfit = entry + (atr * ATRTakeMultiplier);
   
   int ticket = OrderSend(Symbol(), OP_BUY, lotSize, entry, Slippage, 
                         stopLoss, takeProfit, "趋势买入", MagicNumber, 0, clrGreen);
   
   if(ticket > 0)
   {
      Print("买入成功: 票号=", ticket, " 手数=", lotSize, " 入场=", entry, 
            " 止损=", stopLoss, " ATR=", DoubleToString(atr, 5));
   }
   else
   {
      Print("买入失败: 错误代码=", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| 开卖单                                                            |
//+------------------------------------------------------------------+
void OpenSellOrder()
{
   double lotSize = CalculateLotSize();
   double atr = iATR(NULL, 0, ATRPeriod, 1);
   
   double entry = Bid;
   double stopLoss = entry + (atr * ATRStopMultiplier);
   double takeProfit = 0;
   
   if(ATRTakeMultiplier > 0)
      takeProfit = entry - (atr * ATRTakeMultiplier);
   
   int ticket = OrderSend(Symbol(), OP_SELL, lotSize, entry, Slippage, 
                         stopLoss, takeProfit, "趋势卖出", MagicNumber, 0, clrRed);
   
   if(ticket > 0)
   {
      Print("卖出成功: 票号=", ticket, " 手数=", lotSize, " 入场=", entry, 
            " 止损=", stopLoss, " ATR=", DoubleToString(atr, 5));
   }
   else
   {
      Print("卖出失败: 错误代码=", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| 计算手数                                                          |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   if(!UseAutoLot)
      return Lots;
   
   // 基于风险百分比计算手数
   double atr = iATR(NULL, 0, ATRPeriod, 1);
   double riskAmount = AccountBalance() * RiskPercent / 100.0;
   double stopDistance = atr * ATRStopMultiplier;
   
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   
   double lotSize = riskAmount / (stopDistance / tickSize * tickValue);
   
   // 限制在允许范围内
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| 管理现有订单                                                       |
//+------------------------------------------------------------------+
void ManageOpenOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(UseTrailingStop)
               UpdateTrailingStop(OrderTicket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 更新追踪止损                                                       |
//+------------------------------------------------------------------+
void UpdateTrailingStop(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return;
   
   double atr = iATR(NULL, 0, ATRPeriod, 1);
   double trailDistance = atr * TrailingATRMultiplier;
   
   if(OrderType() == OP_BUY)
   {
      // 检查是否达到开始追踪的条件
      double profit = (Bid - OrderOpenPrice()) / Point;
      if(profit < TrailingStartPips)
         return;
      
      double newStop = Bid - trailDistance;
      
      // 只有当新止损更有利时才修改
      if(newStop > OrderStopLoss() + Point || OrderStopLoss() == 0)
      {
         bool result = OrderModify(ticket, OrderOpenPrice(), newStop,
                                  OrderTakeProfit(), 0, clrBlue);
         if(result)
         {
            Print("买单追踪止损更新: 票号=", ticket, " 新止损=", newStop);
         }
         else
         {
            Print("买单追踪止损修改失败: 错误=", GetLastError());
         }
      }
   }
   else if(OrderType() == OP_SELL)
   {
      // 检查是否达到开始追踪的条件
      double profit = (OrderOpenPrice() - Ask) / Point;
      if(profit < TrailingStartPips)
         return;
      
      double newStop = Ask + trailDistance;
      
      // 只有当新止损更有利时才修改
      if(newStop < OrderStopLoss() - Point || OrderStopLoss() == 0)
      {
         bool result = OrderModify(ticket, OrderOpenPrice(), newStop,
                                  OrderTakeProfit(), 0, clrBlue);
         if(result)
         {
            Print("卖单追踪止损更新: 票号=", ticket, " 新止损=", newStop);
         }
         else
         {
            Print("卖单追踪止损修改失败: 错误=", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 统计我的订单数量                                                   |
//+------------------------------------------------------------------+
int CountMyOrders()
{
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| 检查是否有买单                                                     |
//+------------------------------------------------------------------+
bool HasBuyOrders()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_BUY)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| 检查是否有卖单                                                     |
//+------------------------------------------------------------------+
bool HasSellOrders()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_SELL)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("简化趋势跟踪EA停止运行");
}