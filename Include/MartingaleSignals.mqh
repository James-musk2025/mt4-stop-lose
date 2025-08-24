//+------------------------------------------------------------------+
//|                                                        Signals.mqh |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property strict

#include <MovingAverages.mqh>

//+------------------------------------------------------------------+
//| 信号检测类                                                       |
//+------------------------------------------------------------------+
class MartingaleSignals
{
private:
   string m_symbol;
   int m_timeframe;

public:
   MartingaleSignals(string symbol, int timeframe);
   ~MartingaleSignals();

   // 三重过滤信号检测
   bool CheckTripleFilterSignal(int direction);

   // 反转增强信号检测
   bool CheckReversalSignal(int direction);

   // 吞没K线模式检测
   bool CheckEngulfingPattern(int direction);

   // RSI极端值检测
   bool CheckRSIExtreme(int direction);

   // 获取当前趋势方向
   int GetTrendDirection();
};

//+------------------------------------------------------------------+
//| 构造函数                                                         |
//+------------------------------------------------------------------+
MartingaleSignals::MartingaleSignals(string symbol, int timeframe)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
}

//+------------------------------------------------------------------+
//| 析构函数                                                         |
//+------------------------------------------------------------------+
MartingaleSignals::~MartingaleSignals()
{
}

//+------------------------------------------------------------------+
//| 三重过滤信号检测                                                 |
//+------------------------------------------------------------------+
bool MartingaleSignals::CheckTripleFilterSignal(int direction)
{
   // 第一重过滤：趋势方向 (20EMA)
   int trend = GetTrendDirection();
   if (trend != direction)
      return false;

   // 第二重过滤：动量指标 (RSI)
   double rsi = iRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE, 0);
   if (direction == OP_BUY && rsi < 50)
      return false;
   if (direction == OP_SELL && rsi > 50)
      return false;

   // 第三重过滤：价格行为 (突破前高/前低)
   double high1 = iHigh(m_symbol, m_timeframe, 1);
   double high2 = iHigh(m_symbol, m_timeframe, 2);
   double low1 = iLow(m_symbol, m_timeframe, 1);
   double low2 = iLow(m_symbol, m_timeframe, 2);

   if (direction == OP_BUY)
   {
      // 突破前高
      if (high1 < high2)
         return false;
   }
   else if (direction == OP_SELL)
   {
      // 突破前低
      if (low1 > low2)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| 反转增强信号检测                                                 |
//+------------------------------------------------------------------+
bool MartingaleSignals::CheckReversalSignal(int direction)
{
   // 检查RSI极端值
   if (!CheckRSIExtreme(direction))
      return false;

   // 检查吞没K线模式
   if (!CheckEngulfingPattern(direction))
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| 吞没K线模式检测                                                  |
//+------------------------------------------------------------------+
bool MartingaleSignals::CheckEngulfingPattern(int direction)
{
   double open1 = iOpen(m_symbol, m_timeframe, 1);
   double close1 = iClose(m_symbol, m_timeframe, 1);
   double open0 = iOpen(m_symbol, m_timeframe, 0);
   double close0 = iClose(m_symbol, m_timeframe, 0);

   if (direction == OP_BUY)
   {
      // 看涨吞没：前根阴线，当前阳线完全吞没前实体
      bool isBearishPrev = close1 < open1;
      bool isBullishCurrent = close0 > open0;
      bool isEngulfing = close0 > open1 && open0 < close1;

      return isBearishPrev && isBullishCurrent && isEngulfing;
   }
   else if (direction == OP_SELL)
   {
      // 看跌吞没：前根阳线，当前阴线完全吞没前实体
      bool isBullishPrev = close1 > open1;
      bool isBearishCurrent = close0 < open0;
      bool isEngulfing = close0 < open1 && open0 > close1;

      return isBullishPrev && isBearishCurrent && isEngulfing;
   }

   return false;
}

//+------------------------------------------------------------------+
//| RSI极端值检测                                                    |
//+------------------------------------------------------------------+
bool MartingaleSignals::CheckRSIExtreme(int direction)
{
   double rsi = iRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE, 0);

   if (direction == OP_BUY)
   {
      // 超卖区域：RSI ≤ 30
      return rsi <= 30;
   }
   else if (direction == OP_SELL)
   {
      // 超买区域：RSI ≥ 70
      return rsi >= 70;
   }

   return false;
}

//+------------------------------------------------------------------+
//| 获取当前趋势方向                                                 |
//+------------------------------------------------------------------+
int MartingaleSignals::GetTrendDirection()
{
   double ema = iMA(m_symbol, m_timeframe, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
   double currentClose = iClose(m_symbol, m_timeframe, 0);

   if (currentClose > ema)
      return OP_BUY;
   if (currentClose < ema)
      return OP_SELL;

   return -1;
}
//+------------------------------------------------------------------+