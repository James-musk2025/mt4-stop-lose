//+------------------------------------------------------------------+
//|                                              RVITrendFollowingEA.mq4 |
//|                        Copyright 2025, Trend Following Solutions |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Trend Following Solutions"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| 输入参数                                                         |
//+------------------------------------------------------------------+

// === 基础交易设置 ===
input double    BaseLots = 0.1;                // 基础交易手数
input int       MagicNumber = 8888;            // 魔术数字
input int       Slippage = 3;                  // 滑点
input bool      UseAutoLot = false;            // 使用自动手数
input double    RiskPercent = 2.0;             // 风险百分比（自动手数时）

// === RVI趋势判断参数 ===
input int       RVIPeriod = 14;                // RVI指标周期
input int       TrendTimeframe = PERIOD_H1;   // 趋势判断时间框架（M30=30，H1=60）
input int       SignalLinePeriod = 9;          // 信号线平滑周期
input double    TrendThreshold = 0.0;          // 趋势强度阈值（0=禁用过滤）

// === 反马丁加仓参数 ===
input bool      UseAntiMartingale = true;      // 使用反马丁加仓
input double    ProfitATRMultiple = 0.5;       // 盈利ATR倍数（N值，默认0.5倍ATR点数）
input int       MaxAddPositions = 5;           // 最大加仓次数
input double    AddPositionMultiplier = 2;   // 加仓手数乘数

// === ATR止损参数 ===
input int       ATRPeriod = 14;                // ATR周期
input double    ATRStopMultiplier = 3.0;       // ATR止损倍数（M15时间框架）
input bool      UseTrailingStop = true;        // 使用追踪止损
input int       TrailingStartPips = 100;        // 开始追踪的最小盈利点数
input int       MinATRForTrailing = 50;         // ATR止损最小点数（大于此值才更新止损）

// === 反转平仓设置 ===
input bool      CloseOnReversal = true;        // H1反转时平仓
input bool      CloseAllOnReversal = true;     // 反转时平掉所有仓位

//+------------------------------------------------------------------+
//| 全局变量                                                         |
//+------------------------------------------------------------------+
datetime lastBarTime = 0;
int currentTrend = 0;                          // 当前趋势方向：1=多头，-1=空头，0=无趋势
int positionCount = 0;                         // 当前持仓数量
double lastAddPrice = 0;                       // 上次加仓价格

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("RVI趋势跟踪EA启动 - 版本1.0");
   Print("策略配置: RVI(", RVIPeriod, ") + 反马丁加仓 + ATR(", ATRPeriod, ")止损");
   Print("趋势时间框架: ", TimeframeToString(TrendTimeframe));
   
   lastBarTime = Time[0];
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("RVI趋势跟踪EA停止运行");
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
   
   // 检查趋势信号
   CheckTrendSignal();
   
   // 管理现有订单
   ManageOpenOrders();
   
   // 检查加仓机会
   CheckAddPosition();
   
   // 检查反转平仓
   CheckReversalClose();
}

//+------------------------------------------------------------------+
//| 检查趋势信号                                                     |
//+------------------------------------------------------------------+
void CheckTrendSignal()
{
   int newTrend = GetRVITrendSignal();
   
   if(newTrend != currentTrend)
   {
      Print("趋势变化: ", currentTrend, " -> ", newTrend);
      currentTrend = newTrend;
      
      // 如果趋势改变且不允许多方向持仓，关闭反向订单
      if(CountMyOrders() > 0 && currentTrend != 0)
      {
         if((currentTrend == 1 && HasSellOrders()) || 
            (currentTrend == -1 && HasBuyOrders()))
         {
            CloseAllOrders();
         }
      }
      
      // 开新仓
      if(currentTrend == 1 && CountMyOrders() == 0)
      {
         OpenBuyOrder();
      }
      else if(currentTrend == -1 && CountMyOrders() == 0)
      {
         OpenSellOrder();
      }
   }
}

//+------------------------------------------------------------------+
//| 获取RVI趋势信号                                                  |
//+------------------------------------------------------------------+
int GetRVITrendSignal()
{
   // 获取H1时间框架的RVI值
   double rvi_main = iRVI(NULL, TrendTimeframe, RVIPeriod, MODE_MAIN, 1);
   double rvi_signal = iRVI(NULL, TrendTimeframe, RVIPeriod, MODE_SIGNAL, 1);
   double rvi_main_prev = iRVI(NULL, TrendTimeframe, RVIPeriod, MODE_MAIN, 2);
   double rvi_signal_prev = iRVI(NULL, TrendTimeframe, RVIPeriod, MODE_SIGNAL, 2);
   
   // 检查金叉（买入信号）
   if(rvi_main_prev <= rvi_signal_prev && rvi_main > rvi_signal && 
      MathAbs(rvi_main) > TrendThreshold)
   {
      return 1;
   }
   
   // 检查死叉（卖出信号）
   if(rvi_main_prev >= rvi_signal_prev && rvi_main < rvi_signal && 
      MathAbs(rvi_main) > TrendThreshold)
   {
      return -1;
   }
   
   return 0;  // 无明确信号
}

//+------------------------------------------------------------------+
//| 开买单                                                           |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
   double lotSize = CalculateLotSize();
   double atr = GetM15ATR();
   
   double entry = Ask;
   double stopLoss = entry - (atr * ATRStopMultiplier);
   
   int ticket = OrderSend(Symbol(), OP_BUY, lotSize, entry, Slippage, 
                         stopLoss, 0, "RVI趋势买入", MagicNumber, 0, clrGreen);
   
   if(ticket > 0)
   {
      Print("买入开仓成功: 票号=", ticket, " 手数=", lotSize, 
            " 入场=", entry, " 止损=", stopLoss);
      positionCount++;
      lastAddPrice = entry;
   }
   else
   {
      Print("买入开仓失败: 错误代码=", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| 开卖单                                                           |
//+------------------------------------------------------------------+
void OpenSellOrder()
{
   double lotSize = CalculateLotSize();
   double atr = GetM15ATR();
   
   double entry = Bid;
   double stopLoss = entry + (atr * ATRStopMultiplier);
   
   int ticket = OrderSend(Symbol(), OP_SELL, lotSize, entry, Slippage, 
                         stopLoss, 0, "RVI趋势卖出", MagicNumber, 0, clrRed);
   
   if(ticket > 0)
   {
      Print("卖出开仓成功: 票号=", ticket, " 手数=", lotSize, 
            " 入场=", entry, " 止损=", stopLoss);
      positionCount++;
      lastAddPrice = entry;
   }
   else
   {
      Print("卖出开仓失败: 错误代码=", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| 检查加仓机会                                                     |
//+------------------------------------------------------------------+
void CheckAddPosition()
{
   if(!UseAntiMartingale || positionCount >= MaxAddPositions)
      return;
   
   double atr = GetM15ATR();
   double atrInPips = atr / Point; // 将ATR转换为点数
   double profitThreshold = atrInPips * ProfitATRMultiple; // 基于ATR点数计算盈利阈值
   
   if(currentTrend == 1 && HasBuyOrders())
   {
      double currentProfit = (Bid - lastAddPrice) / Point;
      if(currentProfit >= profitThreshold)
      {
         Print("满足加仓条件: 当前盈利=", DoubleToString(currentProfit, 0),
               "点, 阈值=", DoubleToString(profitThreshold, 0), "点, ATR=", DoubleToString(atrInPips, 0), "点");
         AddBuyPosition();
      }
   }
   else if(currentTrend == -1 && HasSellOrders())
   {
      double currentProfit = (lastAddPrice - Ask) / Point;
      if(currentProfit >= profitThreshold)
      {
         Print("满足加仓条件: 当前盈利=", DoubleToString(currentProfit, 0),
               "点, 阈值=", DoubleToString(profitThreshold, 0), "点, ATR=", DoubleToString(atrInPips, 0), "点");
         AddSellPosition();
      }
   }
}

//+------------------------------------------------------------------+
//| 加仓买单                                                         |
//+------------------------------------------------------------------+
void AddBuyPosition()
{
   double lotSize = CalculateLotSize() * AddPositionMultiplier;
   double atr = GetM15ATR();
   
   double entry = Ask;
   double stopLoss = entry - (atr * ATRStopMultiplier);
   
   int ticket = OrderSend(Symbol(), OP_BUY, lotSize, entry, Slippage, 
                         stopLoss, 0, "RVI加仓买入", MagicNumber, 0, clrBlue);
   
   if(ticket > 0)
   {
      Print("加仓买入成功: 票号=", ticket, " 手数=", lotSize, 
            " 入场=", entry, " 止损=", stopLoss);
      positionCount++;
      lastAddPrice = entry;
   }
   else
   {
      Print("加仓买入失败: 错误代码=", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| 加仓卖单                                                         |
//+------------------------------------------------------------------+
void AddSellPosition()
{
   double lotSize = CalculateLotSize() * AddPositionMultiplier;
   double atr = GetM15ATR();
   
   double entry = Bid;
   double stopLoss = entry + (atr * ATRStopMultiplier);
   
   int ticket = OrderSend(Symbol(), OP_SELL, lotSize, entry, Slippage, 
                         stopLoss, 0, "RVI加仓卖出", MagicNumber, 0, clrOrange);
   
   if(ticket > 0)
   {
      Print("加仓卖出成功: 票号=", ticket, " 手数=", lotSize, 
            " 入场=", entry, " 止损=", stopLoss);
      positionCount++;
      lastAddPrice = entry;
   }
   else
   {
      Print("加仓卖出失败: 错误代码=", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| 检查反转平仓                                                     |
//+------------------------------------------------------------------+
void CheckReversalClose()
{
   if(!CloseOnReversal)
      return;
   
   int reversalSignal = GetRVIReversalSignal();
   
   if(reversalSignal != 0 && reversalSignal != currentTrend)
   {
      Print("检测到趋势反转信号: ", reversalSignal);
      if(CloseAllOnReversal)
      {
         CloseAllOrders();
      }
      else
      {
         // 只关闭反向订单
         if(reversalSignal == 1 && HasSellOrders())
         {
            CloseSellOrders();
         }
         else if(reversalSignal == -1 && HasBuyOrders())
         {
            CloseBuyOrders();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 获取RVI反转信号                                                  |
//+------------------------------------------------------------------+
int GetRVIReversalSignal()
{
   // 获取H1时间框架的RVI值
   double rvi_main = iRVI(NULL, TrendTimeframe, RVIPeriod, MODE_MAIN, 0);
   double rvi_signal = iRVI(NULL, TrendTimeframe, RVIPeriod, MODE_SIGNAL, 0);
   double rvi_main_prev = iRVI(NULL, TrendTimeframe, RVIPeriod, MODE_MAIN, 1);
   double rvi_signal_prev = iRVI(NULL, TrendTimeframe, RVIPeriod, MODE_SIGNAL, 1);
   
   // 检查金叉（买入反转信号）
   if(rvi_main_prev <= rvi_signal_prev && rvi_main > rvi_signal)
   {
      return 1;
   }
   
   // 检查死叉（卖出反转信号）
   if(rvi_main_prev >= rvi_signal_prev && rvi_main < rvi_signal)
   {
      return -1;
   }
   
   return 0;  // 无反转信号
}

//+------------------------------------------------------------------+
//| 获取M15 ATR值                                                   |
//+------------------------------------------------------------------+
double GetM15ATR()
{
   return iATR(NULL, PERIOD_M15, ATRPeriod, 0);
}

//+------------------------------------------------------------------+
//| 计算手数                                                         |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   if(!UseAutoLot)
      return BaseLots;
   
   // 基于风险百分比计算手数
   double atr = GetM15ATR();
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
//| 管理现有订单                                                     |
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
//| 更新追踪止损                                                     |
//+------------------------------------------------------------------+
void UpdateTrailingStop(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return;
   
   double atr = GetM15ATR();
   double atrInPips = atr / Point; // 将ATR转换为点数
   
   // 检查ATR是否大于最小要求点数
   if(atrInPips < MinATRForTrailing)
   {
      Print("ATR值(", DoubleToString(atrInPips, 0), "点)小于最小要求(", MinATRForTrailing, "点)，跳过止损更新");
      return;
   }
   
   double trailDistance = atr * ATRStopMultiplier;
   
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
            Print("买单追踪止损更新: 票号=", ticket, " 新止损=", newStop, " ATR=", DoubleToString(atrInPips, 0), "点");
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
            Print("卖单追踪止损更新: 票号=", ticket, " 新止损=", newStop, " ATR=", DoubleToString(atrInPips, 0), "点");
         }
         else
         {
            Print("卖单追踪止损修改失败: 错误=", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 关闭所有订单                                                     |
//+------------------------------------------------------------------+
void CloseAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderType() == OP_BUY)
            {
               bool result = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrWhite);
               if(result)
               {
                  Print("买单平仓成功: 票号=", OrderTicket());
                  positionCount--;
               }
            }
            else if(OrderType() == OP_SELL)
            {
               bool result = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrWhite);
               if(result)
               {
                  Print("卖单平仓成功: 票号=", OrderTicket());
                  positionCount--;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 关闭所有买单                                                     |
//+------------------------------------------------------------------+
void CloseBuyOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_BUY)
         {
            bool result = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrWhite);
            if(result)
            {
               Print("买单平仓成功: 票号=", OrderTicket());
               positionCount--;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 关闭所有卖单                                                     |
//+------------------------------------------------------------------+
void CloseSellOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_SELL)
         {
            bool result = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrWhite);
            if(result)
            {
               Print("卖单平仓成功: 票号=", OrderTicket());
               positionCount--;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 统计我的订单数量                                                 |
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
//| 检查是否有买单                                                   |
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
//| 检查是否有卖单                                                   |
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
//| 时间框架转字符串                                                 |
//+------------------------------------------------------------------+
string TimeframeToString(int tf)
{
   switch(tf)
   {
      case PERIOD_M1: return "M1";
      case PERIOD_M5: return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1";
      case PERIOD_H4: return "H4";
      case PERIOD_D1: return "D1";
      case PERIOD_W1: return "W1";
      case PERIOD_MN1: return "MN1";
      default: return "Unknown";
   }
}
//+------------------------------------------------------------------+