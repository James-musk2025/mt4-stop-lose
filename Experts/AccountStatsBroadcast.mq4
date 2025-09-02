// 账户统计信息广播端
#property copyright "Account Statistics Broadcast"
#property link      ""
#property version   "1.00"
#property strict

#include <AccountStatsDisplay.mqh>

// 全局变量
double maxDrawdown = 0.0;          // 最大回撤纪录
double lastProfitEquity = 0.0;     // 上次盈利时的净值
datetime lastUpdateTime = 0;       // 最后更新时间

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("账户统计广播端启动");
   lastProfitEquity = AccountEquity(); // 初始化时设置为当前净值
   EventSetMillisecondTimer(300); // 每500毫秒更新一次
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| 计算当前持仓浮亏                                                 |
//+------------------------------------------------------------------+
double CalculateFloatingLoss()
{
   double totalFloatingLoss = 0.0;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         {
            totalFloatingLoss += OrderProfit() + OrderSwap() + OrderCommission();
         }
      }
   }
   
   return totalFloatingLoss;
}

//+------------------------------------------------------------------+
//| 更新最大回撤纪录                                                 |
//+------------------------------------------------------------------+
void UpdateMaxDrawdown()
{
   double currentEquity = AccountEquity();
   double floatingLoss = CalculateFloatingLoss();
   
   // 如果全部平仓（无持仓）或者盈亏为正值，重置回撤纪录
   if(OrdersTotal() == 0 || floatingLoss >= 0)
   {
      maxDrawdown = 0.0;
      lastProfitEquity = currentEquity;
      return;
   }
   
   // 计算当前回撤（负值表示亏损）
   double currentDrawdown = floatingLoss;
   
   // 更新最大回撤（取绝对值更大的负值）
   if(currentDrawdown < maxDrawdown)
   {
      maxDrawdown = currentDrawdown;
   }
}

//+------------------------------------------------------------------+
//| 计算恢复比率                                                     |
//+------------------------------------------------------------------+
double CalculateRecoveryRatio()
{
   if(maxDrawdown == 0.0) return 1.0; // 没有回撤，完全恢复
   
   double currentFloatingLoss = CalculateFloatingLoss();
   
   // 恢复比率 = 1 - (当前浮亏 / 最大回撤)
   // 注意：maxDrawdown和currentFloatingLoss都是负值
   double ratio = 1.0 - (currentFloatingLoss / maxDrawdown);
   
   // 限制在0-1范围内
   return MathMax(0.0, MathMin(1.0, ratio));
}

//+------------------------------------------------------------------+
//| 生成统计信息JSON字符串                                           |
//+------------------------------------------------------------------+
string GenerateStatsJSON()
{
   string json = "";
   
   double floatingLoss = CalculateFloatingLoss();
   double equity = AccountEquity();
   double recoveryRatio = CalculateRecoveryRatio();
   
   // 使用简单键值对格式，MQL4对JSON支持有限
   json = StringFormat(
      "position_floating_loss=%.2f|equity=%.2f|max_drawdown_since_profit=%.2f|last_updated_utc=%s|recovery_ratio=%.3f",
      floatingLoss,
      equity,
      maxDrawdown,
      TimeToStr(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
      recoveryRatio
   );
   
   return json;
}

//+------------------------------------------------------------------+
//| 写入统计信息到文件                                               |
//+------------------------------------------------------------------+
void WriteStatsToFile()
{
   string stats = GenerateStatsJSON();
   string filename = IntegerToString(AccountNumber()) + "_stats.dat";
   
   int handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(handle != INVALID_HANDLE)
   {
      FileWrite(handle, stats);
      FileClose(handle);
      // Print("账户统计信息已更新: ", stats);
   }
   else
   {
      Print("写入统计文件失败!");
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // 更新最大回撤纪录
   UpdateMaxDrawdown();
   
   // 写入统计信息到文件
   WriteStatsToFile();
   
   // 在图表上显示统计信息（左下角，坐标10,20）
   double floatingLoss = CalculateFloatingLoss();
   double equity = AccountEquity();
   double recoveryRatio = CalculateRecoveryRatio();
   string updateTime = TimeToStr(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   
   UpdateStatsDisplay(floatingLoss, equity, maxDrawdown, recoveryRatio, updateTime, 1, 10, 20);
   
   lastUpdateTime = TimeCurrent();
}