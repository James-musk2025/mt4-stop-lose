// 账户统计信息接收端 - 带止损和恢复功能
#property copyright "Account Statistics Receiver with Risk Management"
#property link      ""
#property version   "1.00"
#property strict

#include <AccountStatsDisplay.mqh>
#include <RiskManagement.mqh>
#include <RecoveryCheck.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("账户统计接收端启动，监控账户: ", SignalAccountNumber);
   
   // 初始化风险管理模块
   InitRiskManagement();
   
   EventSetMillisecondTimer(300); // 每500毫秒检查一次
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 解析统计信息字符串                                               |
//+------------------------------------------------------------------+
void ParseStatsString(string stats)
{
   string parts[];
   int count = StringSplit(stats, '|', parts);
   
   if(count == 5)
   {
      double floatingLoss = 0.0;
      double equity = 0.0;
      double maxDrawdown = 0.0;
      string updateTime = "";
      double recoveryRatio = 0.0;
      
      for(int i = 0; i < count; i++)
      {
         string keyValue[];
         StringSplit(parts[i], '=', keyValue);
         
         if(ArraySize(keyValue) == 2)
         {
            if(keyValue[0] == "position_floating_loss")
               floatingLoss = StringToDouble(keyValue[1]);
            else if(keyValue[0] == "equity")
               equity = StringToDouble(keyValue[1]);
            else if(keyValue[0] == "max_drawdown_since_profit")
               maxDrawdown = StringToDouble(keyValue[1]);
            else if(keyValue[0] == "last_updated_utc")
               updateTime = keyValue[1];
            else if(keyValue[0] == "recovery_ratio")
               recoveryRatio = StringToDouble(keyValue[1]);
         }
      }
      
      // 在图表上显示统计信息（右上角，坐标10,20）
      UpdateStatsDisplay(floatingLoss, equity, maxDrawdown, recoveryRatio, updateTime, CORNER_RIGHT_UPPER, 10, 20);
   }
   else
   {
      Print("统计信息格式错误: ", stats);
   }
}

//+------------------------------------------------------------------+
//| 检查并读取统计文件                                               |
//+------------------------------------------------------------------+
void CheckAndReadStats()
{
   AccountStats accountStats = ReadSignalAccountStats(SignalAccountNumber);
   // 在图表上显示统计信息（右上角，坐标10,20）
   UpdateStatsDisplay(accountStats.floatingLoss, accountStats.equity, accountStats.maxDrawdown, accountStats.recoveryRatio, accountStats.updateTime, CORNER_RIGHT_UPPER, 10, 20);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ClearStatsDisplay(); // 清理显示对象
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   CheckAndReadStats();
   
   // 检查止损和恢复条件
   CheckStopLoss();
   CheckRecovery();
}