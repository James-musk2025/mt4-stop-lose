//+------------------------------------------------------------------+
//|                                       TrendFollowingSignals.mq4 |
//|                        Copyright 2025, Advanced Trading Systems |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Advanced Trading Systems"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 6

// 指标缓冲区
double BuySignalBuffer[];
double SellSignalBuffer[];
double FastEMABuffer[];
double SlowEMABuffer[];
double TrendEMABuffer[];
double ATRBuffer[];

// 外部参数
input int FastEMA = 12;                     // 快线周期
input int SlowEMA = 26;                     // 慢线周期
input int TrendEMA = 50;                    // 趋势线周期
input int ATRPeriod = 14;                   // ATR周期
input int DonchianPeriod = 20;              // 唐奇安周期
input bool ShowEMALines = true;             // 显示EMA线
input bool ShowSignals = true;              // 显示信号箭头
input color FastEMAColor = clrBlue;         // 快线颜色
input color SlowEMAColor = clrRed;          // 慢线颜色
input color TrendEMAColor = clrYellow;      // 趋势线颜色

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // 设置指标缓冲区
   SetIndexBuffer(0, BuySignalBuffer);
   SetIndexBuffer(1, SellSignalBuffer);
   SetIndexBuffer(2, FastEMABuffer);
   SetIndexBuffer(3, SlowEMABuffer);
   SetIndexBuffer(4, TrendEMABuffer);
   SetIndexBuffer(5, ATRBuffer);
   
   // 设置指标样式
   if(ShowSignals)
   {
      SetIndexStyle(0, DRAW_ARROW);
      SetIndexArrow(0, 233);  // 上箭头
      SetIndexStyle(1, DRAW_ARROW);
      SetIndexArrow(1, 234);  // 下箭头
   }
   else
   {
      SetIndexStyle(0, DRAW_NONE);
      SetIndexStyle(1, DRAW_NONE);
   }
   
   if(ShowEMALines)
   {
      SetIndexStyle(2, DRAW_LINE, STYLE_SOLID, 1, FastEMAColor);
      SetIndexStyle(3, DRAW_LINE, STYLE_SOLID, 1, SlowEMAColor);
      SetIndexStyle(4, DRAW_LINE, STYLE_SOLID, 2, TrendEMAColor);
   }
   else
   {
      SetIndexStyle(2, DRAW_NONE);
      SetIndexStyle(3, DRAW_NONE);
      SetIndexStyle(4, DRAW_NONE);
   }
   
   SetIndexStyle(5, DRAW_NONE);  // ATR不显示
   
   // 设置标签
   SetIndexLabel(0, "买入信号");
   SetIndexLabel(1, "卖出信号");
   SetIndexLabel(2, "快线EMA(" + IntegerToString(FastEMA) + ")");
   SetIndexLabel(3, "慢线EMA(" + IntegerToString(SlowEMA) + ")");
   SetIndexLabel(4, "趋势EMA(" + IntegerToString(TrendEMA) + ")");
   SetIndexLabel(5, "ATR");
   
   // 设置指标名称
   IndicatorShortName("趋势跟踪信号");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   int limit = rates_total - prev_calculated;
   if(prev_calculated > 0) limit++;
   
   for(int i = limit - 1; i >= 0; i--)
   {
      // 计算EMA值
      FastEMABuffer[i] = iMA(NULL, 0, FastEMA, 0, MODE_EMA, PRICE_CLOSE, i);
      SlowEMABuffer[i] = iMA(NULL, 0, SlowEMA, 0, MODE_EMA, PRICE_CLOSE, i);
      TrendEMABuffer[i] = iMA(NULL, 0, TrendEMA, 0, MODE_EMA, PRICE_CLOSE, i);
      
      // 计算ATR值
      ATRBuffer[i] = iATR(NULL, 0, ATRPeriod, i);
      
      // 初始化信号缓冲区
      BuySignalBuffer[i] = EMPTY_VALUE;
      SellSignalBuffer[i] = EMPTY_VALUE;
      
      // 计算信号（需要至少2根K线）
      if(i < rates_total - 2)
      {
         int signal = GetTrendSignal(i);
         
         if(signal == 1)
         {
            BuySignalBuffer[i] = low[i] - ATRBuffer[i] * 0.5;
         }
         else if(signal == -1)
         {
            SellSignalBuffer[i] = high[i] + ATRBuffer[i] * 0.5;
         }
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| 获取趋势信号                                                       |
//+------------------------------------------------------------------+
int GetTrendSignal(int shift)
{
   // EMA交叉信号
   int emaSignal = GetEMASignal(shift);
   
   // 唐奇安突破信号
   int donchianSignal = GetDonchianSignal(shift);
   
   // 综合判断
   if(emaSignal == 1 && donchianSignal >= 0)
      return 1;
   else if(emaSignal == -1 && donchianSignal <= 0)
      return -1;
   
   return 0;
}

//+------------------------------------------------------------------+
//| EMA交叉信号                                                       |
//+------------------------------------------------------------------+
int GetEMASignal(int shift)
{
   double fastEMA_0 = FastEMABuffer[shift];
   double fastEMA_1 = FastEMABuffer[shift + 1];
   double slowEMA_0 = SlowEMABuffer[shift];
   double slowEMA_1 = SlowEMABuffer[shift + 1];
   double trendEMA = TrendEMABuffer[shift];
   
   // 金叉且价格在趋势线上方
   if(fastEMA_1 <= slowEMA_1 && fastEMA_0 > slowEMA_0 && Close[shift] > trendEMA)
      return 1;
   
   // 死叉且价格在趋势线下方
   if(fastEMA_1 >= slowEMA_1 && fastEMA_0 < slowEMA_0 && Close[shift] < trendEMA)
      return -1;
   
   return 0;
}

//+------------------------------------------------------------------+
//| 唐奇安突破信号                                                     |
//+------------------------------------------------------------------+
int GetDonchianSignal(int shift)
{
   double upperBand = iHighest(NULL, 0, MODE_HIGH, DonchianPeriod, shift + 1);
   double lowerBand = iLowest(NULL, 0, MODE_LOW, DonchianPeriod, shift + 1);
   
   // 突破上轨
   if(Close[shift] > upperBand)
      return 1;
   
   // 突破下轨
   if(Close[shift] < lowerBand)
      return -1;
   
   return 0;
}