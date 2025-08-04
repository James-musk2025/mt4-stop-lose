#property copyright "Copyright 2025, AI Generated EA"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// 外部参数
input double Lots = 0.1;           // 交易手数
input int    FastMAPeriod = 12;    // 快线周期
input int    SlowMAPeriod = 26;    // 慢线周期
input int    ATRPeriod = 14;       // ATR周期
input double ATRMultiplier = 2.0;  // ATR乘数
input int    Slippage = 3;         // 允许滑点

// 全局变量
double prevFast, prevSlow;

// 初始化函数
int OnInit()
{
   // 初始化前值
   prevFast = iMA(NULL, 0, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   prevSlow = iMA(NULL, 0, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   
   return(INIT_SUCCEEDED);
}

// 主交易逻辑
void OnTick()
{
   // 获取当前指标值
   double currentFast = iMA(NULL, 0, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double currentSlow = iMA(NULL, 0, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   
   // 获取ATR值
   double atrValue = iATR(NULL, 0, ATRPeriod, 0);
   
   // 计算止损距离
   double stopLossDistance = atrValue * ATRMultiplier;
   
   // 检查交叉信号
   bool buySignal = false;
   bool sellSignal = false;
   
   if(prevFast <= prevSlow && currentFast > currentSlow)
      buySignal = true;
   
   if(prevFast >= prevSlow && currentFast < currentSlow)
      sellSignal = true;
   
   // 更新前值
   prevFast = currentFast;
   prevSlow = currentSlow;
   
   // 交易执行逻辑
   if(buySignal)
   {
      double entry = Ask;
      double stopLoss = entry - stopLossDistance;
      double takeProfit = 0; // 可根据策略添加止盈
      
      OrderSend(Symbol(), OP_BUY, Lots, entry, Slippage, stopLoss, takeProfit, "", 0, 0, Green);
   }
   else if(sellSignal)
   {
      double entry = Bid;
      double stopLoss = entry + stopLossDistance;
      double takeProfit = 0; // 可根据策略添加止盈
      
      OrderSend(Symbol(), OP_SELL, Lots, entry, Slippage, stopLoss, takeProfit, "", 0, 0, Red);
   }
   
   // 追踪止损逻辑
   TrailingStop(stopLossDistance);
}

// 追踪止损函数
void TrailingStop(double distance)
{
   for(int i = OrdersTotal()-1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol())
         {
            if(OrderType() == OP_BUY)
            {
               double newStop = Bid - distance;
               if(newStop > OrderStopLoss() || OrderStopLoss() == 0)
               {
                  OrderModify(OrderTicket(), OrderOpenPrice(), newStop, OrderTakeProfit(), 0, Blue);
               }
            }
            else if(OrderType() == OP_SELL)
            {
               double newStop = Ask + distance;
               if(newStop < OrderStopLoss() || OrderStopLoss() == 0)
               {
                  OrderModify(OrderTicket(), OrderOpenPrice(), newStop, OrderTakeProfit(), 0, Blue);
               }
            }
         }
      }
   }
}