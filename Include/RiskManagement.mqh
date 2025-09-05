// 风险管理模块 - 止损和恢复功能
#property strict

// 包含恢复检查模块
#include <RecoveryCheck.mqh>

// 使用input参数（在EA中定义）
input double StopLossAmount = 1000.0;                       // 止损金额
input string templates = "XAUUSD-90784-Pendding-Order.tpl"; // 要恢复的EA模板，逗分隔

// 全局变量
double initialBalance = 0.0;                   // 初始余额
bool isStoppedOut = false;                     // 是否已止损
string templateListFile = "template_list.txt"; // 模板列表文件
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

   // 1. 保存所有其他图表模板
   SaveAllChartTemplates();

   // 2. 关闭其他图表
   CloseOtherCharts();

   // 3. 平仓所有交易
   CloseAllTradesWithRetry();

   isStoppedOut = true;
   // 止损后更新初始余额为当前余额
   initialBalance = AccountBalance();
   Print("止损操作完成，更新初始余额为: $", initialBalance);
}

//+------------------------------------------------------------------+
//| 保存所有图表模板                                                 |
//+------------------------------------------------------------------+
void SaveAllChartTemplates()
{
   Print("开始保存所有图表模板...");

   int handle = FileOpen(templateListFile, FILE_WRITE | FILE_TXT);
   if (handle == INVALID_HANDLE)
   {
      Print("创建模板列表文件失败!");
      return;
   }

   long chartId = ChartFirst();
   while (chartId != -1)
   {
      // 跳过当前图表（风险管理EA所在的图表）
      if (chartId != ChartID())
      {
         string symbol = ChartSymbol(chartId);
         int timeframe = ChartPeriod(chartId);
         string templateName = StringFormat("%s-%d-%s", symbol, timeframe, IntegerToString(chartId));

         // 保存模板
         if (ChartSaveTemplate(chartId, templateName))
         {
            FileWrite(handle, templateName);
            Print("保存模板: ", templateName);
         }
         else
         {
            Print("保存模板失败: ", templateName);
         }
      }

      chartId = ChartNext(chartId);
   }

   FileClose(handle);
   Print("所有图表模板保存完成");
}

//+------------------------------------------------------------------+
//| 关闭其他图表                                                     |
//+------------------------------------------------------------------+
void CloseOtherCharts()
{
   Print("开始关闭其他图表...");

   long chartId = ChartFirst();
   while (chartId != -1)
   {
      long nextChart = ChartNext(chartId); // 先获取下一个图表ID

      // 跳过当前图表
      if (chartId != ChartID())
      {
         Print("关闭图表: ", chartId);
         ChartClose(chartId);
      }

      chartId = nextChart;
   }

   Print("其他图表关闭完成");
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
         MessageBox(warning, "平仓警告", MB_ICONWARNING | MB_OK);

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

   // 从模板列表文件恢复图表
   RestoreChartsFromTemplates();

   isStoppedOut = false;
   Print("恢复操作完成");
}

void RestoreChartsFromTemplates()
{
   string savedTemplates[];
   StringSplit(templates, ',', savedTemplates);

   for (int i = 0; i < ArraySize(savedTemplates); i++)
   {
      string templateName = savedTemplates[i];

      // 查找是否有图表已经使用了这个模板
      long chartId = FindChartByTemplateComment(templateName);

      if (chartId != -1)
      {
         Print("图表已存在，跳过创建: ", templateName, " chartId: ", chartId);
         continue; // 关键：找到后立即跳过，不执行后面的创建代码
      }

      // 创建新图表
      long newChartId = ChartOpen(Symbol(), PERIOD_M5);
      if (newChartId == 0)
      {
         int error = GetLastError();
         Print("创建图表失败 - 错误: ", error);
         continue;
      }

      if (ChartApplyTemplate(newChartId, templateName))
      {
         // 设置图表注释来标记使用的模板
         ChartSetString(newChartId, CHART_COMMENT, "Template:" + templateName);
         Print("模板应用成功，已设置注释: Template:", templateName);
      }
      else
      {
         int error = GetLastError();
         Print("应用模板失败 - 错误: ", error);
      }
   }
}

// 通过图表注释查找使用特定模板的图表
long FindChartByTemplateComment(string templateName)
{
   long currentChartId = ChartID();
   long chartId = ChartFirst();
   string searchPattern = "Template:" + templateName;

   while (chartId != -1)
   {
      if (chartId == currentChartId)
      {
         chartId = ChartNext(chartId);
         continue;
      }

      // 获取图表注释
      string comment = ChartGetString(chartId, CHART_COMMENT);
      Print("检查图表 ", chartId, " 注释: '", comment, "'");

      if (StringFind(comment, searchPattern) != -1)
      {
         return chartId;
      }

      chartId = ChartNext(chartId);
   }
   return -1;
}

//+------------------------------------------------------------------+
//| 从模板恢复图表                                                   |
//+------------------------------------------------------------------+
void RestoreChartsFromTemplatesFile()
{
   Print("开始从模板恢复图表...");

   int handle = FileOpen(templateListFile, FILE_READ | FILE_TXT);
   if (handle == INVALID_HANDLE)
   {
      Print("模板列表文件不存在!");
      return;
   }

   while (!FileIsEnding(handle))
   {
      string templateName = FileReadString(handle);
      string parts[];
      StringSplit(templateName, '-', parts);

      if (ArraySize(parts) == 3)
      {
         string symbol = parts[0];
         int timeframe = (int)StringToInteger(parts[1]);

         // 检查是否已经存在该品种的图表
         bool chartExists = false;
         long chartId = ChartFirst();
         while (chartId != -1)
         {
            if (ChartSymbol(chartId) == symbol && ChartPeriod(chartId) == timeframe)
            {
               // 应用模板到现有图表
               if (ChartApplyTemplate(chartId, templateName))
               {
                  Print("应用模板到现有图表: ", templateName);
               }
               else
               {
                  Print("应用模板失败: ", templateName);
               }
               chartExists = true;
               break;
            }
            chartId = ChartNext(chartId);
         }

         // 如果没有现有图表，创建新图表并应用模板
         if (!chartExists)
         {
            long newChartId = ChartOpen(symbol, timeframe);
            if (newChartId != -1)
            {
               if (ChartApplyTemplate(newChartId, templateName))
               {
                  Print("创建新图表并应用模板: ", templateName);
               }
               else
               {
                  Print("应用模板失败: ", templateName);
               }
            }
            else
            {
               Print("创建图表失败: ", symbol, " ", timeframe);
            }
         }
      }
   }

   FileClose(handle);
   Print("图表恢复完成");
}