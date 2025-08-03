//+------------------------------------------------------------------+
//|                                      StopLossTakeProfitSetter.mq4 |
//|                                  Copyright 2025, Kilo Code       |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Kilo Code"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property description "设置订单的止损和止盈（基于点数）"
#property description "支持批量处理当前货币对的所有订单"
#property description "提供完整的价格验证和错误处理机制"
#property show_inputs

//+------------------------------------------------------------------+
//| 输入参数                                                          |
//+------------------------------------------------------------------+
input string Comment_1 = "==================";  // 止损止盈设置
input int StopLossPoints = 0;                  // 止损点数 (0=保持原有, -1=清空)
input int TakeProfitPoints = 5000;               // 止盈点数 (0=保持原有, -1=清空)
input string Comment_2 = "==================";  // 订单过滤选项
input bool OnlyCurrentSymbol = true;             // 仅应用于当前货币对
input bool OnlyBuyOrders = false;                // 仅应用于买单
input bool OnlySellOrders = false;               // 仅应用于卖单
input bool UseMagicFilter = false;               // 使用魔术数字过滤
input int MagicNumber = 0;                       // 魔术数字
input bool UseCommentFilter = false;             // 使用注释过滤
input string CommentFilter = "";                 // 注释过滤文本
input string Comment_3 = "==================";  // 执行选项
input bool ConfirmBeforeExecution = true;        // 执行前确认
input int MaxRetries = 3;                        // 最大重试次数
input bool ShowDetailedLog = true;               // 显示详细日志

//+------------------------------------------------------------------+
//| 全局变量                                                          |
//+------------------------------------------------------------------+
struct ExecutionStats
{
    int totalOrders;        // 总订单数
    int processedOrders;    // 已处理订单数
    int successfulOrders;   // 成功修改订单数
    int failedOrders;       // 失败订单数
    int skippedOrders;      // 跳过订单数
};

ExecutionStats stats;

//+------------------------------------------------------------------+
//| 脚本程序开始函数                                                  |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("=== 止损止盈设置脚本启动 ===");
    Print("版本: 1.00");
    Print("当前货币对: ", Symbol());
    Print("止损点数: ", StopLossPoints);
    Print("止盈点数: ", TakeProfitPoints);
    
    // 初始化统计数据
    InitializeStats();
    
    // 验证输入参数
    if (!ValidateInputParameters())
    {
        Print("错误: 输入参数验证失败，脚本终止");
        return;
    }
    
    // 扫描并分析订单
    if (!ScanOrders())
    {
        Print("没有找到符合条件的订单");
        return;
    }
    
    // 生成执行预览
    string preview = GeneratePreview();
    Print(preview);
    
    // 执行前确认
    if (ConfirmBeforeExecution)
    {
        int result = MessageBox(preview + "\n确认执行吗？", "止损止盈设置确认", MB_YESNO | MB_ICONQUESTION);
        if (result != IDYES)
        {
            Print("用户取消执行");
            return;
        }
    }
    
    // 执行订单修改
    ExecuteOrderModifications();
    
    // 显示最终报告
    ShowFinalReport();
    
    Print("=== 脚本执行完成 ===");
}

//+------------------------------------------------------------------+
//| 初始化统计数据                                                    |
//+------------------------------------------------------------------+
void InitializeStats()
{
    stats.totalOrders = 0;
    stats.processedOrders = 0;
    stats.successfulOrders = 0;
    stats.failedOrders = 0;
    stats.skippedOrders = 0;
}

//+------------------------------------------------------------------+
//| 验证输入参数                                                      |
//+------------------------------------------------------------------+
bool ValidateInputParameters()
{
    // 检查点数参数
    if (StopLossPoints < -1 || TakeProfitPoints < -1)
    {
        Print("错误: 止损和止盈点数不能小于-1");
        return false;
    }
    
    if (StopLossPoints == 0 && TakeProfitPoints == 0)
    {
        Print("错误: 止损和止盈点数不能同时为0");
        return false;
    }
    
    // 检查买单卖单过滤冲突
    if (OnlyBuyOrders && OnlySellOrders)
    {
        Print("错误: 不能同时选择仅买单和仅卖单");
        return false;
    }
    
    // 检查重试次数
    if (MaxRetries < 1 || MaxRetries > 10)
    {
        Print("错误: 最大重试次数必须在1-10之间");
        return false;
    }
    
    // 检查市场状态
    if (!IsTradeAllowed())
    {
        Print("错误: 当前不允许交易");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| 扫描订单                                                          |
//+------------------------------------------------------------------+
bool ScanOrders()
{
    stats.totalOrders = OrdersTotal();
    int validOrders = 0;
    
    for (int i = 0; i < stats.totalOrders; i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if (ShouldProcessOrder())
            {
                validOrders++;
            }
        }
    }
    
    stats.processedOrders = validOrders;
    return (validOrders > 0);
}

//+------------------------------------------------------------------+
//| 检查订单是否应该被处理                                            |
//+------------------------------------------------------------------+
bool ShouldProcessOrder()
{
    // 检查货币对过滤
    if (OnlyCurrentSymbol && OrderSymbol() != Symbol())
        return false;
    
    // 检查买单/卖单过滤
    if (OnlyBuyOrders && OrderType() != OP_BUY)
        return false;
    if (OnlySellOrders && OrderType() != OP_SELL)
        return false;
    
    // 检查魔术数字过滤
    if (UseMagicFilter && OrderMagicNumber() != MagicNumber)
        return false;
    
    // 检查注释过滤
    if (UseCommentFilter && StringFind(OrderComment(), CommentFilter) < 0)
        return false;
    
    // 只处理市价订单 (OP_BUY, OP_SELL)
    if (OrderType() != OP_BUY && OrderType() != OP_SELL)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| 计算新的止损价格                                                  |
//+------------------------------------------------------------------+
double CalculateStopLoss(int orderType, double openPrice, string symbol, double currentSL)
{
    if (StopLossPoints == 0) return currentSL; // 保持原有止损
    if (StopLossPoints == -1) return 0; // 清空止损
    
    double pointValue = MarketInfo(symbol, MODE_POINT);
    
    if (orderType == OP_BUY)
        return openPrice - (StopLossPoints * pointValue);
    else if (orderType == OP_SELL)
        return openPrice + (StopLossPoints * pointValue);
    
    return currentSL;
}

//+------------------------------------------------------------------+
//| 计算新的止盈价格                                                  |
//+------------------------------------------------------------------+
double CalculateTakeProfit(int orderType, double openPrice, string symbol, double currentTP)
{
    if (TakeProfitPoints == 0) return currentTP; // 保持原有止盈
    if (TakeProfitPoints == -1) return 0; // 清空止盈
    
    double pointValue = MarketInfo(symbol, MODE_POINT);
    
    if (orderType == OP_BUY)
        return openPrice + (TakeProfitPoints * pointValue);
    else if (orderType == OP_SELL)
        return openPrice - (TakeProfitPoints * pointValue);
    
    return currentTP;
}

//+------------------------------------------------------------------+
//| 标准化价格（考虑Tick Size和精度）                                 |
//+------------------------------------------------------------------+
double NormalizePrice(string symbol, double price)
{
    if (price <= 0) return 0;
    
    int digits = (int)MarketInfo(symbol, MODE_DIGITS);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    
    // 先按精度标准化
    price = NormalizeDouble(price, digits);
    
    // 再按Tick Size调整
    if (tickSize > 0)
    {
        price = NormalizeDouble(MathRound(price / tickSize) * tickSize, digits);
    }
    
    return price;
}

//+------------------------------------------------------------------+
//| 验证价格是否符合市场限制                                          |
//+------------------------------------------------------------------+
bool IsValidPrice(string symbol, int orderType, double price, bool isStopLoss)
{
    if (price <= 0) return true; // 0表示不设置，总是有效
    
    double bid = MarketInfo(symbol, MODE_BID);
    double ask = MarketInfo(symbol, MODE_ASK);
    double stopLevel = MarketInfo(symbol, MODE_STOPLEVEL) * MarketInfo(symbol, MODE_POINT);
    
    if (orderType == OP_BUY)
    {
        if (isStopLoss)
        {
            if (price > bid - stopLevel)
            {
                if (ShowDetailedLog)
                    Print("警告: 买单止损价格 ", price, " 太接近当前价格 ", bid, " (最小距离: ", stopLevel, ")");
                return false;
            }
        }
        else
        {
            if (price < ask + stopLevel)
            {
                if (ShowDetailedLog)
                    Print("警告: 买单止盈价格 ", price, " 太接近当前价格 ", ask, " (最小距离: ", stopLevel, ")");
                return false;
            }
        }
    }
    else if (orderType == OP_SELL)
    {
        if (isStopLoss)
        {
            if (price < ask + stopLevel)
            {
                if (ShowDetailedLog)
                    Print("警告: 卖单止损价格 ", price, " 太接近当前价格 ", ask, " (最小距离: ", stopLevel, ")");
                return false;
            }
        }
        else
        {
            if (price > bid - stopLevel)
            {
                if (ShowDetailedLog)
                    Print("警告: 卖单止盈价格 ", price, " 太接近当前价格 ", bid, " (最小距离: ", stopLevel, ")");
                return false;
            }
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| 生成执行预览                                                      |
//+------------------------------------------------------------------+
string GeneratePreview()
{
    string preview = "\n=== 止损止盈设置脚本预览 ===\n";
    preview += "货币对: " + Symbol() + "\n";
    
    // 显示过滤条件
    if (OnlyBuyOrders)
        preview += "订单类型: 仅买单\n";
    else if (OnlySellOrders)
        preview += "订单类型: 仅卖单\n";
    else
        preview += "订单类型: 买单和卖单\n";
    
    // 显示止损止盈设置
    string slText = IntegerToString(StopLossPoints) + " 点";
    if (StopLossPoints == 0) slText += " (保持原有)";
    else if (StopLossPoints == -1) slText += " (清空)";
    preview += "止损点数: " + slText + "\n";
    
    string tpText = IntegerToString(TakeProfitPoints) + " 点";
    if (TakeProfitPoints == 0) tpText += " (保持原有)";
    else if (TakeProfitPoints == -1) tpText += " (清空)";
    preview += "止盈点数: " + tpText + "\n\n";
    
    int orderCount = 0;
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && ShouldProcessOrder())
        {
            orderCount++;
            string symbol = OrderSymbol();
            double openPrice = OrderOpenPrice();
            double currentSL = OrderStopLoss();
            double currentTP = OrderTakeProfit();
            
            double newSL = CalculateStopLoss(OrderType(), openPrice, symbol, currentSL);
            double newTP = CalculateTakeProfit(OrderType(), openPrice, symbol, currentTP);
            
            newSL = NormalizePrice(symbol, newSL);
            newTP = NormalizePrice(symbol, newTP);
            
            preview += "订单 #" + IntegerToString(OrderTicket()) + ": ";
            preview += (OrderType() == OP_BUY ? "买单" : "卖单");
            preview += ", 开仓价: " + DoubleToString(openPrice, Digits) + "\n";
            
            // 显示止损信息
            if (StopLossPoints == 0)
            {
                if (currentSL > 0)
                    preview += "  止损: " + DoubleToString(currentSL, Digits) + " (保持不变)\n";
                else
                    preview += "  止损: 无 (保持不变)\n";
            }
            else if (StopLossPoints == -1)
            {
                preview += "  止损: 清空\n";
            }
            else
            {
                preview += "  新止损: " + DoubleToString(newSL, Digits) + " (" + IntegerToString(StopLossPoints) + "点)\n";
            }
            
            // 显示止盈信息
            if (TakeProfitPoints == 0)
            {
                if (currentTP > 0)
                    preview += "  止盈: " + DoubleToString(currentTP, Digits) + " (保持不变)\n";
                else
                    preview += "  止盈: 无 (保持不变)\n";
            }
            else if (TakeProfitPoints == -1)
            {
                preview += "  止盈: 清空\n";
            }
            else
            {
                preview += "  新止盈: " + DoubleToString(newTP, Digits) + " (" + IntegerToString(TakeProfitPoints) + "点)\n";
            }
                
            preview += "\n";
        }
    }
    
    if (orderCount == 0)
    {
        preview += "没有找到符合条件的订单。\n";
    }
    else
    {
        preview += "总共将处理 " + IntegerToString(orderCount) + " 个订单。\n";
    }
    
    return preview;
}

//+------------------------------------------------------------------+
//| 执行订单修改                                                      |
//+------------------------------------------------------------------+
void ExecuteOrderModifications()
{
    Print("\n开始执行订单修改...");
    
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && ShouldProcessOrder())
        {
            ProcessSingleOrder();
        }
    }
}

//+------------------------------------------------------------------+
//| 处理单个订单                                                      |
//+------------------------------------------------------------------+
void ProcessSingleOrder()
{
    int ticket = OrderTicket();
    string symbol = OrderSymbol();
    int orderType = OrderType();
    double openPrice = OrderOpenPrice();
    double currentSL = OrderStopLoss();
    double currentTP = OrderTakeProfit();
    
    // 计算新的止损止盈价格
    double newSL = CalculateStopLoss(orderType, openPrice, symbol, currentSL);
    double newTP = CalculateTakeProfit(orderType, openPrice, symbol, currentTP);
    
    // 标准化价格
    newSL = NormalizePrice(symbol, newSL);
    newTP = NormalizePrice(symbol, newTP);
    
    // 验证价格（只验证需要修改的价格）
    bool slValid = true;
    bool tpValid = true;
    
    if (StopLossPoints > 0)
        slValid = IsValidPrice(symbol, orderType, newSL, true);
    if (TakeProfitPoints > 0)
        tpValid = IsValidPrice(symbol, orderType, newTP, false);
    
    if (!slValid || !tpValid)
    {
        Print("跳过订单 #", ticket, ": 价格验证失败");
        stats.skippedOrders++;
        return;
    }
    
    // 检查是否需要修改
    double normalizedCurrentSL = NormalizeDouble(currentSL, Digits);
    double normalizedCurrentTP = NormalizeDouble(currentTP, Digits);
    
    if (MathAbs(normalizedCurrentSL - newSL) < Point && MathAbs(normalizedCurrentTP - newTP) < Point)
    {
        if (ShowDetailedLog)
            Print("订单 #", ticket, ": 止损止盈已经是目标值，无需修改");
        stats.skippedOrders++;
        return;
    }
    
    // 执行修改
    if (ModifyOrderSLTP(ticket, newSL, newTP))
    {
        stats.successfulOrders++;
        string slInfo, tpInfo;
        
        if (StopLossPoints == 0) slInfo = "保持原有";
        else if (StopLossPoints == -1) slInfo = "已清空";
        else slInfo = DoubleToString(newSL, Digits);
        
        if (TakeProfitPoints == 0) tpInfo = "保持原有";
        else if (TakeProfitPoints == -1) tpInfo = "已清空";
        else tpInfo = DoubleToString(newTP, Digits);
        
        Print("成功: 订单 #", ticket, " 已修改 - SL:", slInfo, " TP:", tpInfo);
    }
    else
    {
        stats.failedOrders++;
        Print("失败: 订单 #", ticket, " 修改失败");
    }
}

//+------------------------------------------------------------------+
//| 修改订单的止损止盈                                                |
//+------------------------------------------------------------------+
bool ModifyOrderSLTP(int ticket, double newSL, double newTP)
{
    if (!OrderSelect(ticket, SELECT_BY_TICKET))
    {
        Print("错误: 无法选择订单 #", ticket);
        return false;
    }
    
    double openPrice = OrderOpenPrice();
    datetime expiry = OrderExpiration();
    
    // 重试机制
    for (int attempt = 1; attempt <= MaxRetries; attempt++)
    {
        if (OrderModify(ticket, openPrice, newSL, newTP, expiry, clrNONE))
        {
            if (ShowDetailedLog)
                Print("订单 #", ticket, " 修改成功 (尝试 ", attempt, "/", MaxRetries, ")");
            return true;
        }
        else
        {
            int error = GetLastError();
            if (ShowDetailedLog)
                Print("尝试 ", attempt, "/", MaxRetries, " 失败: 订单 #", ticket, 
                      " 错误代码:", error, " - ", ErrorDescription(error));
            
            if (error == ERR_TRADE_CONTEXT_BUSY && attempt < MaxRetries)
            {
                Sleep(1000); // 等待1秒后重试
            }
            else
            {
                break; // 其他错误或达到最大重试次数
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| 获取错误描述                                                      |
//+------------------------------------------------------------------+
string ErrorDescription(int errorCode)
{
    switch(errorCode)
    {
        case ERR_NO_ERROR: return "无错误";
        case ERR_NO_RESULT: return "无结果";
        case ERR_COMMON_ERROR: return "通用错误";
        case ERR_INVALID_TRADE_PARAMETERS: return "无效的交易参数";
        case ERR_SERVER_BUSY: return "服务器忙";
        case ERR_OLD_VERSION: return "版本过旧";
        case ERR_NO_CONNECTION: return "无连接";
        case ERR_NOT_ENOUGH_RIGHTS: return "权限不足";
        case ERR_TOO_FREQUENT_REQUESTS: return "请求过于频繁";
        case ERR_MALFUNCTIONAL_TRADE: return "交易功能故障";
        case ERR_ACCOUNT_DISABLED: return "账户被禁用";
        case ERR_INVALID_ACCOUNT: return "无效账户";
        case ERR_TRADE_TIMEOUT: return "交易超时";
        case ERR_INVALID_PRICE: return "无效价格";
        case ERR_INVALID_STOPS: return "无效止损";
        case ERR_INVALID_TRADE_VOLUME: return "无效交易量";
        case ERR_MARKET_CLOSED: return "市场关闭";
        case ERR_TRADE_DISABLED: return "交易被禁用";
        case ERR_NOT_ENOUGH_MONEY: return "资金不足";
        case ERR_PRICE_CHANGED: return "价格改变";
        case ERR_OFF_QUOTES: return "无报价";
        case ERR_BROKER_BUSY: return "经纪商忙";
        case ERR_REQUOTE: return "重新报价";
        case ERR_ORDER_LOCKED: return "订单被锁定";
        case ERR_LONG_POSITIONS_ONLY_ALLOWED: return "只允许多头持仓";
        case ERR_TOO_MANY_REQUESTS: return "请求过多";
        case ERR_TRADE_MODIFY_DENIED: return "交易修改被拒绝";
        case ERR_TRADE_CONTEXT_BUSY: return "交易上下文忙";
        case ERR_TRADE_EXPIRATION_DENIED: return "交易到期被拒绝";
        case ERR_TRADE_TOO_MANY_ORDERS: return "订单过多";
        default: return "未知错误 (" + IntegerToString(errorCode) + ")";
    }
}

//+------------------------------------------------------------------+
//| 显示最终报告                                                      |
//+------------------------------------------------------------------+
void ShowFinalReport()
{
    Print("\n=== 执行报告 ===");
    Print("总订单数: ", stats.totalOrders);
    Print("符合条件订单数: ", stats.processedOrders);
    Print("成功修改: ", stats.successfulOrders);
    Print("修改失败: ", stats.failedOrders);
    Print("跳过订单: ", stats.skippedOrders);
    
    if (stats.processedOrders > 0)
    {
        double successRate = (double)stats.successfulOrders / stats.processedOrders * 100;
        Print("成功率: ", DoubleToString(successRate, 1), "%");
    }
    
    Print("=== 报告结束 ===");
}
//+------------------------------------------------------------------+