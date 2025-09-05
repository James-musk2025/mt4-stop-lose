// 账户统计信息接收端 - 带止损和恢复功能
#property copyright "Account Statistics Receiver with Risk Management"
#property link ""
#property version "1.00"
#property strict

#include <AccountStatsDisplay.mqh>
#include <RiskManagement.mqh>
#include <RecoveryCheck.mqh>
#include <TemplateManager.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 检查交易权限
   if (!CheckTradingPermissions())
   {
      Print("交易权限检查失败，EA无法执行交易操作");
      return INIT_FAILED;
   }

   // 初始化模板管理模块
   InitTemplateManager();

   // 启动跟单EA - 只恢复参数指定的模板
   RestoreTemplateCharts(templates);

   Print("账户统计接收端启动，监控账户: ", SignalAccountNumber);

   // 初始化风险管理模块
   InitRiskManagement();

   EventSetMillisecondTimer(350); // 每350毫秒检查一次
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

   // 显示风险管理信息（在统计信息下方）
   double stopLossEquity = initialBalance - StopLossAmount;
   UpdateRiskManagementDisplay(SignalAccountNumber, initialBalance,
                               StopLossAmount, stopLossEquity, AccountEquity(),
                               RecoveryRatioThreshold, templates,
                               CORNER_RIGHT_UPPER, 10, 120);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ClearStatsDisplay();          // 清理统计信息显示对象
   ClearRiskManagementDisplay(); // 清理风险管理信息显示对象
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

//+------------------------------------------------------------------+
//| 处理图表事件（用于调试命令）                                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // 处理键盘事件
   if (id == CHARTEVENT_KEYDOWN)
   {
      // 按F1键显示风险管理状态
      if (lparam == 112) // F1键
      {
      }
      // 按F2键强制更新初始余额
      else if (lparam == 113) // F2键
      {
         initialBalance = AccountBalance();
         Print("强制更新初始余额: $", initialBalance);
         Comment("初始余额已更新: $", initialBalance);
      }
      // 按F3键手动恢复图表模板（调试用）
      else if (lparam == 114) // F3键
      {
         Print("手动触发图表恢复...");
         RestoreTemplateCharts(templates);
         Comment("图表恢复操作已执行");
      }
      // 按F4键保存当前图表模板（调试用）
      else if (lparam == 115) // F4键
      {
         Print("手动保存图表模板功能已移除，使用新的模板管理机制");
         Comment("请使用新的模板管理机制");
      }
   }
}
