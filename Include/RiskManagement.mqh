// 风险管理模块 - 止损和恢复功能
#property strict

// 包含恢复检查模块
#include <RecoveryCheck.mqh>
#include <TemplateManager.mqh>

// 使用input参数（在EA中定义）
input double StopLossAmount = 1000.0;                       // 止损金额
input string templates = "XAUUSD-90784-Pendding-Order.tpl"; // 要恢复的EA模板，逗分隔

// 全局变量
double initialBalance = 0.0;                   // 初始余额
bool isStoppedOut = false;                     // 是否已止损
// 模板列表文件变量已移除，使用新的模板管理机制
int closeAttempts = 0;                         // 全局变量用于跟踪递归次数
int maxCloseAttempts = 3;                      // 最大递归次数

//+------------------------------------------------------------------+
//| 初始化风险管理模块                                               |
//+------------------------------------------------------------------+
void InitRiskManagement()
{
   initialBalance = AccountBalance();
   Print("风险管理模块初始化，初始余额: $", initialBalance, ", 止损金额: $", StopLossAmount);
}

//+------------------------------------------------------------------+
//| 检查是否需要止损                                                 |
//+------------------------------------------------------------------+
bool CheckStopLoss()
{
   if (isStoppedOut)
      return false; // 已经止损过了

   double currentEquity = AccountEquity();
   double stopLossLevel = initialBalance - StopLossAmount;

   if (currentEquity <= stopLossLevel)
   {
      Print("触发止损! 当前净值: $", currentEquity, ", 止损水平: $", stopLossLevel);
      ExecuteStopLoss();
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| 检查是否需要恢复交易                                             |
//+------------------------------------------------------------------+
bool CheckRecovery()
{
   if (!isStoppedOut)
      return false; // 没有止损，不需要恢复

   // 使用新的恢复检查模块
   string currentSymbol = Symbol();
   int currentTimeframe = Period();
   double currentEquity = AccountEquity();

   bool shouldRecover = CheckRecoveryConditions(isStoppedOut, currentEquity,
                                                initialBalance, StopLossAmount,
                                                currentSymbol, currentTimeframe);

   if (shouldRecover)
   {
      Print("达到恢复条件! 执行恢复操作");
      ExecuteRecovery();
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| 执行止损操作                                                     |
//+------------------------------------------------------------------+
void ExecuteStopLoss()
{
   Print("开始执行止损操作...");

   // 1. 关闭参数指定模板的图表（使用新的模板管理机制）
   CloseAllTemplateCharts(templates);

   // 3. 平仓所有交易
   CloseAllTradesWithRetry();

   isStoppedOut = true;
   // 止损后更新初始余额为当前余额
   initialBalance = AccountBalance();
   Print("止损操作完成，更新初始余额为: $", initialBalance);
}



//+------------------------------------------------------------------+
//| 平仓所有交易                                                     |
//+------------------------------------------------------------------+
void CloseAllTrades(int maxAttempts = -1)
{
   // 如果指定了最大尝试次数，则更新
   if (maxAttempts != -1)
   {
      maxCloseAttempts = maxAttempts;
      Print("设置最大平仓尝试次数为: ", maxCloseAttempts);
   }

   closeAttempts++;
   Print("开始平仓所有交易... 尝试次数: ", closeAttempts, "/", maxCloseAttempts);

   int closedCount = 0;
   int remainingOrders = OrdersTotal();

   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if (OrderType() == OP_BUY)
         {
            if (OrderClose(OrderTicket(), OrderLots(), Bid, 3, Red))
               closedCount++;
         }
         else if (OrderType() == OP_SELL)
         {
            if (OrderClose(OrderTicket(), OrderLots(), Ask, 3, Red))
               closedCount++;
         }
         else
         {
            // 挂单直接删除
            if (OrderDelete(OrderTicket()))
               closedCount++;
         }
      }
   }

   Print("平仓完成，共处理 ", closedCount, " 个订单，剩余订单: ", OrdersTotal());

   // 检查是否还有剩余订单
   if (OrdersTotal() > 0)
   {
      if (closeAttempts < maxCloseAttempts)
      {
         Print("还有未平仓订单，等待1秒后重试...");
         Sleep(1000);        // 等待1秒
         CloseAllTrades(-1); // 递归调用，保持当前最大尝试次数
      }
      else
      {
         // 超过最大尝试次数，弹窗警告
         string warning = "警告: 无法完全平仓所有订单!\n";
         warning += "尝试次数: " + IntegerToString(closeAttempts) + "/" + IntegerToString(maxCloseAttempts) + "\n";
         warning += "剩余订单: " + IntegerToString(OrdersTotal()) + "\n";
         warning += "请手动检查并处理剩余订单。";

         Alert(warning);
         // MessageBox(warning, "平仓警告", MB_ICONWARNING | MB_OK);

         // 重置计数器
         closeAttempts = 0;
      }
   }
   else
   {
      Print("所有订单已成功平仓");
      closeAttempts = 0; // 重置计数器
   }
}

// 包装函数，可以指定最大尝试次数
void CloseAllTradesWithRetry(int maxAttempts = 3)
{
   closeAttempts = 0; // 重置计数器
   CloseAllTrades(maxAttempts);
}

//+------------------------------------------------------------------+
//| 执行恢复操作                                                     |
//+------------------------------------------------------------------+
void ExecuteRecovery()
{
   Print("开始执行恢复操作...");

   // 恢复参数指定模板的图表（使用新的模板管理机制）
   RestoreTemplateCharts(templates);

   isStoppedOut = false;
   Print("恢复操作完成");
}


//+------------------------------------------------------------------+
//| 检查交易权限（通用函数）                                         |
//+------------------------------------------------------------------+
bool CheckTradingPermissions(string eaName = "")
{
   string warningMessage = "";
   string title = (eaName != "") ? eaName + " - 权限警告" : "交易权限警告";

   if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      warningMessage = "自动交易未启用!\n\n请确保：\n• 工具->选项->EA交易->允许自动交易\n• 图表右上角启用自动交易按钮";
   }
   else if (!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      warningMessage = "账户交易权限受限!\n\n可能原因：\n• 账户被禁止交易\n• 账户类型不支持交易\n• 账户状态异常";
   }
   else if (!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      warningMessage = "EA交易功能被禁用!\n\n解决方法：\n• 在EA属性中启用交易权限\n• 检查EA的初始化参数";
   }
   else if (!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      warningMessage = "终端未连接到交易服务器!\n\n请检查：\n• 网络连接状态\n• 交易服务器状态";
   }

   if (warningMessage != "")
   {
      MessageBox(warningMessage, title, MB_ICONWARNING | MB_OK);
      return false;
   }

   return true;
}
