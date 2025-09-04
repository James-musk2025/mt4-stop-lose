// 恢复检查模块使用示例
#property copyright "Recovery Check Module Example"
#property link      ""
#property version   "1.00"
#property strict

#include <RecoveryCheck.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("恢复检查模块示例启动");
   
   // 示例1: 检查喊单账户统计信息是否有效
   bool isValid = IsSignalAccountStatsValid(SignalAccountNumber);
   Print("喊单账户统计信息有效: ", isValid);
   
   if(isValid)
   {
      // 示例2: 获取喊单账户的恢复比例
      double recoveryRatio = GetSignalAccountRecoveryRatio(SignalAccountNumber);
      Print("喊单账户恢复比例: ", recoveryRatio * 100, "%");
      
      // 示例3: 获取喊单账户的浮亏信息
      double floatingLoss = GetSignalAccountFloatingLoss(SignalAccountNumber);
      Print("喊单账户浮亏: $", floatingLoss);
      
      // 示例4: 综合检查恢复条件
      bool shouldRecover = CheckRecoveryConditions(false, 0, 0, 0, Symbol(), Period());
      Print("综合恢复检查结果: ", shouldRecover);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("恢复检查模块示例停止");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 每tick检查一次恢复条件（实际使用中可以根据需要调整频率）
   static datetime lastCheck = 0;
   if(TimeCurrent() - lastCheck >= 60) // 每分钟检查一次
   {
      bool shouldRecover = CheckRecoveryConditions(false, 0, 0, 0, Symbol(), Period());
      if(shouldRecover)
      {
         Print("检测到恢复条件，可以执行恢复操作");
         // 这里可以添加实际的恢复逻辑
      }
      lastCheck = TimeCurrent();
   }
}