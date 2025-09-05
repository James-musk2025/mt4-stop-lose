// 账户统计信息广播端
#property copyright "Account Statistics Broadcast"
#property link      ""
#property version   "1.00"
#property strict

#include <AccountStatsDisplay.mqh>

// 添加两个输入参数
input bool SaveTickData = true;    // 是否保存Tick级别数据
input bool SaveMinuteData = true;  // 是否保存分钟级别数据

// 全局变量
double maxDrawdown = 0.0;          // 最大回撤纪录
double lastProfitEquity = 0.0;     // 上次盈利时的净值
datetime lastUpdateTime = 0;       // 最后更新时间
datetime lastMinuteSave = 0;       // 最后分钟数据保存时间

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
//| 保存Tick级别数据到CSV                                            |
//+------------------------------------------------------------------+
void SaveTickDataToCSV()
{
   if(!SaveTickData) return;
   
   string filename = "AccountStats_Tick_" + IntegerToString(AccountNumber()) + ".csv";
   int handle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
   
   if(handle != INVALID_HANDLE)
   {
      FileSeek(handle, 0, SEEK_END); // 移动到文件末尾
      
      if(FileSize(handle) == 0)
      {
         FileWrite(handle, "Timestamp", "Equity", "Balance", "FloatingPL", 
                  "Drawdown", "RecoveryRatio", "PositionCount");
      }

      // 构建精确格式的数据行
      string dataLine = StringFormat("%s,%.2f,%.2f,%.2f,%.2f,%.3f,%d",
                                     GetTimestampWithMilliseconds(),
                                     AccountEquity(),
                                     AccountBalance(),
                                     AccountProfit(),
                                     maxDrawdown,
                                     CalculateRecoveryRatio(),
                                     OrdersTotal());

      FileWrite(handle, dataLine);
      FileClose(handle);
   }
   else
   {
      Print("Error: Can't create file", GetLastError());
   }
}

// 获取带毫秒的完整时间戳
string GetTimestampWithMilliseconds()
{
    datetime currentTime = TimeCurrent();
    double milliseconds = GetTickCount() % 1000; // 获取毫秒数
    
    return StringFormat("%s.%03d", TimeToString(currentTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS), milliseconds);
}

//+------------------------------------------------------------------+
//| 保存分钟级别数据到CSV                                            |
//+------------------------------------------------------------------+
void SaveMinuteDataToCSV()
{
   if(!SaveMinuteData) return;
   
   datetime currentTime = TimeCurrent();
   if(currentTime - lastMinuteSave >= 60 || lastMinuteSave == 0)
   {
      string filename = "AccountStats_Minute_" + IntegerToString(AccountNumber()) + ".csv";
      int handle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
      
      if(handle != INVALID_HANDLE)
      {
         FileSeek(handle, 0, SEEK_END); // 移动到文件末尾

         if(FileSize(handle) == 0)
         {
            FileWrite(handle, "Timestamp", "Equity", "Balance", "FloatingPL", 
                     "Drawdown", "RecoveryRatio", "PositionCount");
         }
         
          // 构建精确格式的数据行
         string dataLine = StringFormat("%s,%.2f,%.2f,%.2f,%.2f,%.3f,%d",
                                        GetTimestampWithMilliseconds(),
                                        AccountEquity(),
                                        AccountBalance(),
                                        AccountProfit(),
                                        maxDrawdown,
                                        CalculateRecoveryRatio(),
                                        OrdersTotal());

         FileWrite(handle, dataLine);
         FileClose(handle);
         lastMinuteSave = currentTime;
      }
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

   // 保存数据到CSV
   SaveTickDataToCSV();
   SaveMinuteDataToCSV();
   
   // 在图表上显示统计信息（左下角，坐标10,20）
   double floatingLoss = CalculateFloatingLoss();
   double equity = AccountEquity();
   double recoveryRatio = CalculateRecoveryRatio();
   string updateTime = TimeToStr(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   
   UpdateStatsDisplay(floatingLoss, equity, maxDrawdown, recoveryRatio, updateTime, 1, 10, 20, Green);
   
   lastUpdateTime = TimeCurrent();
}