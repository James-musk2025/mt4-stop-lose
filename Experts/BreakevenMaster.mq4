//+------------------------------------------------------------------+
//|                                                 BreakevenMaster.mq4 |
//|                                     Copyright 2025, Your Name Here |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property strict

// --- 用户可配置参数 ---
input int      ActivationPips = 200;    // 激活平推的盈利点数 (如盈利10点)
input bool     AdjustForSpread = true; // 是否考虑点差(将SL移动到开仓价+点差)
input string   SymbolFilter = "";      // 监控的品种(空=全部)，如"EURUSD"
input int      MagicFilter  = -1;       // 监控的魔术码(-1=全部)，如12345

// --- 全局变量 ---
int timerId; // 用于管理定时器

//+------------------------------------------------------------------+
//| EA初始化函数                                                      |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 设置低频定时器 (如15秒)
   timerId = EventSetTimer(15); // 单位：秒！这个频率足够了
   if(timerId == -1)
     {
      Print("Error creating timer! Err=", GetLastError());
      return(INIT_FAILED);
     }
   Print("BreakevenMaster initialized. Using OnTrade() + Timer (", timerId, ").");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| EA反初始化函数                                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // 删除定时器
   EventKillTimer();
   Print("BreakevenMaster deinitialized.");
  }

//+------------------------------------------------------------------+
//| 核心事件: 交易状态改变                                           |
//+------------------------------------------------------------------+
void OnTrade()
  {
   // 有交易事件发生(开仓、平仓、改单)，立即检查是否需要平推保本
   Print("OnTrade() triggered. Checking positions...");
   CheckBreakeven();
  }

//+------------------------------------------------------------------+
//| 核心事件: 定时器触发 (低频轮询备份)                               |
//+------------------------------------------------------------------+
void OnTimer()
  {
   // 定时器触发，低频检查一次 (即使没交易事件，防止市场缓慢移动达到保本点)
   Print("Timer (ID:", timerId, ") triggered. Backup position check...");
   CheckBreakeven();
  }

//+------------------------------------------------------------------+
//| 核心逻辑：检查并执行平推保本                                      |
//+------------------------------------------------------------------+
void CheckBreakeven()
  {
   // 1. 遍历所有当前持仓
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue; // 选中失败，跳过

      // 2. 检查是否符合筛选条件 (品种 & 魔术码)
      if((SymbolFilter != "" && OrderSymbol() != SymbolFilter) ||
         (MagicFilter != -1 && OrderMagicNumber() != MagicFilter))
        {
         continue; // 不符合过滤条件，跳过此订单
        }

      // 3. 仅处理持仓单(OP_BUY/OP_SELL)
      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
        {
         // 4. 计算该订单的浮动盈利点数
         double currentProfitPips;
         if(OrderType() == OP_BUY)
            currentProfitPips = (Bid - OrderOpenPrice()) / Point; // 计算浮动盈利点数
         else if(OrderType() == OP_SELL)
            currentProfitPips = (OrderOpenPrice() - Ask) / Point; // 计算浮动盈利点数

         // 5. 检查是否达到激活点数
         if(currentProfitPips >= ActivationPips)
           {
            // 6. 计算新的保本止损价
            double newStopLoss;
            if(OrderType() == OP_BUY)
              {
               newStopLoss = OrderOpenPrice();
               if(AdjustForSpread) newStopLoss += MarketInfo(OrderSymbol(), MODE_SPREAD) * Point; // 加点多单点差成本
              }
            else // OP_SELL
              {
               newStopLoss = OrderOpenPrice();
               if(AdjustForSpread) newStopLoss -= MarketInfo(OrderSymbol(), MODE_SPREAD) * Point; // 减少空单点差成本
               // 注意：空单开仓价较高，要向下移动止损
              }

            // 7. 检查当前止损是否已经是保本价或更优 (避免无意义修改)
            // 多单：当前止损 >= 计算出的保本价？ (已经设了或设的更保守了)
            // 空单：当前止损 <= 计算出的保本价？
            bool needModify;
            if(OrderType() == OP_BUY)
              {
               needModify = (OrderStopLoss() == 0) || (OrderStopLoss() < newStopLoss);
              }
            else // OP_SELL
              {
               needModify = (OrderStopLoss() == 0) || (OrderStopLoss() > newStopLoss);
              }

            // 8. 确实需要修改止损吗？
            if(needModify)
              {
               // 打印日志信息
               Print("Moving ", OrderSymbol(), " #", OrderTicket(), " to Breakeven SL=", newStopLoss,
                     " (OpenPrice=", OrderOpenPrice(), ", ProfitPips=", currentProfitPips, ")");

               // 9. 调用修改函数 (处理可能的忙错误)
               if(!ModifyPosition(OrderTicket(), newStopLoss, 3)) // 最多尝试3次
                 {
                  Print("!!! Failed to modify ", OrderTicket(), " after retries. Err=", GetLastError());
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| 安全修改订单函数 (带指数退避重试)                                 |
//+------------------------------------------------------------------+
bool ModifyPosition(int ticket, double newSl, int maxRetries = 3)
  {
   int retryCount = 0;
   int sleepMs = 100; // 初始等待时间(毫秒)
   bool result = false;

   while(retryCount < maxRetries && !IsStopped())
     {
      // 选中订单 (重要！每次重试都要确保选中)
      if(OrderSelect(ticket, SELECT_BY_TICKET))
        {
         // 尝试修改止损
         double currentSl = OrderStopLoss();
         double currentTp = OrderTakeProfit();
         datetime expiry = OrderExpiration();
         color arrow = clrNONE;
         result = OrderModify(ticket, OrderOpenPrice(), newSl, currentTp, expiry, arrow);

         if(result)
           {
            Print("Successfully modified ticket ", ticket, ". New SL=", newSl);
            return true; // 成功，退出
           }
         else
           {
            int errCode = GetLastError();
            Print("OrderModify failed (", ticket, "). Err=", errCode, " Attempt ", retryCount + 1, "/", maxRetries);

            // 重点处理交易环境繁忙错误(146)，其他错误通常重试无意义
            if(errCode == ERR_TRADE_CONTEXT_BUSY)
              {
               retryCount++;
               Print("Server busy. Waiting ", sleepMs, "ms before retry...");
               Sleep(sleepMs); // 等待一段时间再试
               sleepMs *= 2;   // 指数退避：下次等待时间加倍 (100ms -> 200ms -> 400ms)
              }
            else
              {
               // 其他错误 (如无效价格、订单已关闭等)，重试通常没用，跳出
               Print("Unrecoverable error. Aborting modification.");
               break;
              }
           }
        }
      else
        {
         Print("Failed to select ticket ", ticket, " during modification. Aborting.");
         break;
        }
     }
   return false; // 所有重试失败或出现不可恢复错误
  }
//+------------------------------------------------------------------+