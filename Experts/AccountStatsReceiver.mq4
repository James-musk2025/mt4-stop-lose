// 账户统计信息接收端 - 带止损和恢复功能
#property copyright "Account Statistics Receiver with Risk Management"
#property link ""
#property version "1.00"
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
   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 检查并读取统计文件                                               |
//+------------------------------------------------------------------+
void CheckAndReadStats()
{
   AccountStats accountStats = ReadSignalAccountStats(SignalAccountNumber);
   // 在图表上显示统计信息（右上角，坐标10,20）
   UpdateStatsDisplay(accountStats.floatingLoss, accountStats.equity,
                      accountStats.maxDrawdown, accountStats.recoveryRatio,
                      accountStats.updateTime, CORNER_RIGHT_UPPER, 10, 20);
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