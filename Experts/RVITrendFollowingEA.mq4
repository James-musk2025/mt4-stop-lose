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
input int       TrendTimeframe = PERIOD_H1;    // 趋势判断时间框架（H1=60）
input int       SignalLinePeriod = 9;          // 信号线平滑周期
input double    TrendThreshold = 0.0;          // 趋势强度阈值（0=禁用过滤）

// === 正向金字塔加仓参数 ===
input bool      UsePyramidAdd = true;          // 使用正向金字塔加仓
input double    Pyramid_Step_ATRMultiplier = 0.5; // 加仓步长ATR倍数（价格移动N倍ATR时加仓）
input int       MaxAddPositions = 10;          // 最大加仓次数（改为10次）
input double    AddPositionMultiplier = 1.0;   // 加仓手数乘数（改为1.0，保持相同手数）

// === ATR止损参数 ===
input int       ATRPeriod = 14;                // ATR周期
input double    ATRStopMultiplier = 3.0;       // ATR止损倍数（M15时间框架）
input bool      UseTrailingStop = false;       // 使用追踪止损（默认关闭）
input int       TrailingStartPips = 100;        // 开始追踪的最小盈利点数
input int       MinStopAdjustment = 50;         // 止损调整最小点数（大于此值才移动止损）

// === 反转平仓设置 ===
input bool      CloseOnReversal = true;        // H1反转时平仓（默认开启）
input bool      CloseAllOnReversal = true;     // 反转时平掉所有仓位

//+------------------------------------------------------------------+
//| 全局变量                                                         |
//+------------------------------------------------------------------+
datetime lastBarTime = 0;
int currentTrend = 0;                          // 当前趋势方向：1=多头，-1=空头，0=无趋势
int positionCount = 0;                         // 当前持仓数量
int buyAddCount = 0;                           // 买单加仓次数
int sellAddCount = 0;                          // 卖单加仓次数
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
   
   // 检查时间差异（仅在初始化时检查一次）
   CheckTimeDifference();
   
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
   // 获取M30时间框架的RVI值（使用当前K线和前一根K线）
   double rvi_main = iRVI(NULL, TrendTimeframe, RVIPeriod, MODE_MAIN, 0);
   double rvi_signal = iRVI(NULL, TrendTimeframe, RVIPeriod, MODE_SIGNAL, 0);
   double rvi_main_prev = iRVI(NULL, TrendTimeframe, RVIPeriod, MODE_MAIN, 1);
   double rvi_signal_prev = iRVI(NULL, TrendTimeframe, RVIPeriod, MODE_SIGNAL, 1);
   
   // 检查金叉（买入信号）
   if(rvi_main_prev < rvi_signal_prev && rvi_main >= rvi_signal)
   {
      Print("检测到买入信号: 金叉形成");

      // 打印RVI信号详细信息
      Print("RVI买入信号: 当前主线=", DoubleToString(rvi_main, 4),
            " 当前信号线=", DoubleToString(rvi_signal, 4),
            " 前主线=", DoubleToString(rvi_main_prev, 4),
            " 前信号线=", DoubleToString(rvi_signal_prev, 4),
            " 价格=", DoubleToString(Close[0], 4),
            " 时间=", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
      return 1;
   }
   
   // 检查死叉（卖出信号）
   if(rvi_main_prev > rvi_signal_prev && rvi_main <= rvi_signal)
   {
      Print("检测到卖出信号: 死叉形成");
      // 打印RVI信号详细信息
      Print("RVI卖出信号: 当前主线=", DoubleToString(rvi_main, 4),
            " 当前信号线=", DoubleToString(rvi_signal, 4),
            " 前主线=", DoubleToString(rvi_main_prev, 4),
            " 前信号线=", DoubleToString(rvi_signal_prev, 4),
            " 价格=", DoubleToString(Close[0], 4),
            " 时间=", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
      return -1;
   }
   
   // 即使没有明确的交叉，也检查趋势强度
   if(MathAbs(rvi_main - rvi_signal) > 0.15)
   {
      if(rvi_main > rvi_signal)
      {
         // Print("强势多头趋势但未形成金叉: 主线=", DoubleToString(rvi_main, 4),
         //       " 信号线=", DoubleToString(rvi_signal, 4));
         return 1;
      }
      else if(rvi_main < rvi_signal)
      {
         // Print("强势空头趋势但未形成死叉: 主线=", DoubleToString(rvi_main, 4),
         //       " 信号线=", DoubleToString(rvi_signal, 4));
         return -1;
      }
   }
   
   // Print("无明确信号: 主线=", DoubleToString(rvi_main, 4),
   //       " 信号线=", DoubleToString(rvi_signal, 4),
   //       " 差异=", DoubleToString(rvi_main - rvi_signal, 4));
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
   if(!UsePyramidAdd)
   {
      Print("正向金字塔加仓功能已禁用");
      return;
   }
   
   // 根据当前趋势方向检查对应的加仓次数
   int currentAddCount = 0;
   if(currentTrend == 1)
      currentAddCount = buyAddCount;
   else if(currentTrend == -1)
      currentAddCount = sellAddCount;
   
   if(currentAddCount >= MaxAddPositions)
   {
      Print("已达到最大加仓次数限制: ", currentAddCount, "/", MaxAddPositions,
            " (", (currentTrend == 1 ? "买单" : "卖单"), ")");
      return;
   }
   
   // 使用与趋势判断相同时间框架的ATR
   double atr = iATR(NULL, TrendTimeframe, ATRPeriod, 0);
   double atrInPips = atr / Point; // 将ATR转换为点数
   double stepDistance = atrInPips * Pyramid_Step_ATRMultiplier; // 加仓步长
   
   Print("金字塔加仓检查: ATR=", DoubleToString(atrInPips, 1), "点, 加仓步长=",
         DoubleToString(stepDistance, 1), "点, 当前持仓=", positionCount);
   
   if(currentTrend == 1 && HasBuyOrders())
   {
      // 计算从初始入场价到当前价格的移动距离
      double initialEntryPrice = GetInitialEntryPrice(OP_BUY);
      double priceMove = (Bid - initialEntryPrice) / Point;
      
      // 计算应该加仓的次数（每移动stepDistance加仓一次）
      int expectedAddCount = (int)MathFloor(priceMove / stepDistance);
      
      Print("买入持仓检查: 初始入场价=", DoubleToString(initialEntryPrice, 5),
            ", 当前价格=", DoubleToString(Bid, 5), ", 价格移动=", DoubleToString(priceMove, 1), "点",
            ", 应加仓次数=", expectedAddCount);
      
      // 如果应该加仓的次数大于当前已加仓次数，则执行加仓
      if(expectedAddCount > buyAddCount)
      {
         Print("满足金字塔加仓条件-买入: 价格移动=", DoubleToString(priceMove, 0),
               "点, 步长=", DoubleToString(stepDistance, 0), "点, 应加仓=", expectedAddCount,
               "次, 已加仓=", buyAddCount, "次");
         AddBuyPosition();
      }
      else
      {
         Print("加仓检查-买入: 还需移动",
               DoubleToString(((buyAddCount + 1) * stepDistance) - priceMove, 0),
               "点才能下次加仓");
      }
   }
   else if(currentTrend == -1 && HasSellOrders())
   {
      // 计算从初始入场价到当前价格的移动距离
      double initialEntryPrice = GetInitialEntryPrice(OP_SELL);
      double priceMove = (initialEntryPrice - Ask) / Point;
      
      // 计算应该加仓的次数（每移动stepDistance加仓一次）
      int expectedAddCount = (int)MathFloor(priceMove / stepDistance);
      
      Print("卖出持仓检查: 初始入场价=", DoubleToString(initialEntryPrice, 5),
            ", 当前价格=", DoubleToString(Ask, 5), ", 价格移动=", DoubleToString(priceMove, 1), "点",
            ", 应加仓次数=", expectedAddCount);
      
      // 如果应该加仓的次数大于当前已加仓次数，则执行加仓
      if(expectedAddCount > sellAddCount)
      {
         Print("满足金字塔加仓条件-卖出: 价格移动=", DoubleToString(priceMove, 0),
               "点, 步长=", DoubleToString(stepDistance, 0), "点, 应加仓=", expectedAddCount,
               "次, 已加仓=", sellAddCount, "次");
         AddSellPosition();
      }
      else
      {
         Print("加仓检查-卖出: 还需移动",
               DoubleToString(((sellAddCount + 1) * stepDistance) - priceMove, 0),
               "点才能下次加仓");
      }
   }
   else
   {
      Print("加仓检查: 无持仓或趋势不匹配, 趋势=", currentTrend,
            ", 有买单=", HasBuyOrders(), ", 有卖单=", HasSellOrders());
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
      buyAddCount++;
      lastAddPrice = entry;
      Print("买单加仓次数更新: ", buyAddCount, "/", MaxAddPositions);
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
      sellAddCount++;
      lastAddPrice = entry;
      Print("卖单加仓次数更新: ", sellAddCount, "/", MaxAddPositions);
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
   
   double trailDistance = atr * ATRStopMultiplier;
   
   // 计算新的止损位置
   
   if(OrderType() == OP_BUY)
   {
      // 检查是否达到开始追踪的条件
      double profit = (Bid - OrderOpenPrice()) / Point;
      if(profit < TrailingStartPips)
         return;
      
      double newStop = Bid - trailDistance;
      
      // 只有当新止损更有利且调整幅度大于最小要求时才修改
      if(newStop > OrderStopLoss() + MinStopAdjustment * Point || OrderStopLoss() == 0)
      {
         bool result = OrderModify(ticket, OrderOpenPrice(), newStop,
                                  OrderTakeProfit(), 0, clrBlue);
         if(result)
         {
            // Print("买单追踪止损更新: 票号=", ticket, " 新止损=", newStop,
            //       " 调整=", DoubleToString((newStop - OrderStopLoss()) / Point, 0), "点");
         }
         else
         {
            Print("买单追踪止损修改失败: 错误=", GetLastError());
         }
      }
      else if(newStop > OrderStopLoss() + Point)
      {
         // Print("止损需要调整但幅度不足: 当前止损=", OrderStopLoss(),
         //       " 新止损=", newStop, " 调整=", DoubleToString((newStop - OrderStopLoss()) / Point, 0), "点");
      }
   }
   else if(OrderType() == OP_SELL)
   {
      // 检查是否达到开始追踪的条件
      double profit = (OrderOpenPrice() - Ask) / Point;
      if(profit < TrailingStartPips)
         return;
      
      double newStop = Ask + trailDistance;
      
      // 只有当新止损更有利且调整幅度大于最小要求时才修改
      if(newStop < OrderStopLoss() - MinStopAdjustment * Point || OrderStopLoss() == 0)
      {
         bool result = OrderModify(ticket, OrderOpenPrice(), newStop,
                                  OrderTakeProfit(), 0, clrBlue);
         if(result)
         {
            // Print("卖单追踪止损更新: 票号=", ticket, " 新止损=", newStop,
            //       " 调整=", DoubleToString((OrderStopLoss() - newStop) / Point, 0), "点");
         }
         else
         {
            Print("卖单追踪止损修改失败: 错误=", GetLastError());
         }
      }
      else if(newStop < OrderStopLoss() - Point)
      {
         // Print("止损需要调整但幅度不足: 当前止损=", OrderStopLoss(),
         //       " 新止损=", newStop, " 调整=", DoubleToString((OrderStopLoss() - newStop) / Point, 0), "点");
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
                  // 重置买单加仓次数
                  if(positionCount == 0)
                  {
                     buyAddCount = 0;
                     Print("买单加仓次数重置为0");
                  }
               }
            }
            else if(OrderType() == OP_SELL)
            {
               bool result = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrWhite);
               if(result)
               {
                  Print("卖单平仓成功: 票号=", OrderTicket());
                  positionCount--;
                  // 重置卖单加仓次数
                  if(positionCount == 0)
                  {
                     sellAddCount = 0;
                     Print("卖单加仓次数重置为0");
                  }
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
//| 获取初始入场价格                                                 |
//+------------------------------------------------------------------+
double GetInitialEntryPrice(int orderType)
{
   double initialPrice = 0;
   int count = 0;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == orderType)
         {
            if(count == 0)
            {
               initialPrice = OrderOpenPrice();
            }
            else
            {
               // 找到最早的订单价格
               if(OrderOpenTime() < initialPrice)
               {
                  initialPrice = OrderOpenPrice();
               }
            }
            count++;
         }
      }
   }
   
   if(count > 0)
   {
      Print("找到", count, "个", (orderType == OP_BUY ? "买单" : "卖单"),
            ", 初始入场价格=", DoubleToString(initialPrice, 5));
   }
   
   return initialPrice;
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
//| 检查时间差异                                                     |
//+------------------------------------------------------------------+
void CheckTimeDifference()
{
   datetime serverTime = TimeCurrent();
   datetime localTime = TimeLocal();
   datetime gmtTime = TimeGMT();
   
   Print("时间检查: 服务器时间=", TimeToString(serverTime, TIME_DATE|TIME_SECONDS),
         " 本地时间=", TimeToString(localTime, TIME_DATE|TIME_SECONDS),
         " GMT时间=", TimeToString(gmtTime, TIME_DATE|TIME_SECONDS),
         " 服务器-本地差异=", serverTime - localTime, "秒",
         " 服务器-GMT差异=", serverTime - gmtTime, "秒");
}