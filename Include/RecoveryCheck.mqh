// 恢复检查模块 - 支持复杂的恢复逻辑检查
#property strict
#property copyright "Recovery Check Module"
#property link ""
#property version "1.00"

// 恢复检查配置参数
input int SignalAccountNumber = 2100892675; // 喊单账户号
bool UseSignalAccountStats = true;          // 是否使用喊单账户统计信息
input double RecoveryRatioThreshold = 0.2;  // 恢复比例阈值
bool UseMovingAverageCheck = false;         // 是否使用均线检查
int MAPeriod = 20;                          // 均线周期

// 统计信息结构体
struct AccountStats
{
   double floatingLoss;  // 持仓浮亏
   double equity;        // 账户净值
   double maxDrawdown;   // 最大回撤
   double recoveryRatio; // 恢复比率
   string updateTime;    // 更新时间
   bool isValid;         // 数据是否有效
};

//+------------------------------------------------------------------+
//| 读取喊单账户统计信息                                             |
//+------------------------------------------------------------------+
AccountStats ReadSignalAccountStats(int accountNumber)
{
   AccountStats stats;
   stats.isValid = false;

   string filename = IntegerToString(accountNumber) + "_stats.dat";

   if (!FileIsExist(filename, FILE_COMMON))
   {
      Print("统计文件不存在: ", filename);
      return stats;
   }

   int handle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_COMMON);
   if (handle == INVALID_HANDLE)
   {
      Print("打开统计文件失败: ", filename);
      return stats;
   }

   string statsData = FileReadString(handle);
   FileClose(handle);

   // 解析统计信息
   string parts[];
   int count = StringSplit(statsData, '|', parts);

   if (count == 5)
   {
      for (int i = 0; i < count; i++)
      {
         string keyValue[];
         StringSplit(parts[i], '=', keyValue);

         if (ArraySize(keyValue) == 2)
         {
            if (keyValue[0] == "position_floating_loss")
               stats.floatingLoss = StringToDouble(keyValue[1]);
            else if (keyValue[0] == "equity")
               stats.equity = StringToDouble(keyValue[1]);
            else if (keyValue[0] == "max_drawdown_since_profit")
               stats.maxDrawdown = StringToDouble(keyValue[1]);
            else if (keyValue[0] == "last_updated_utc")
               stats.updateTime = keyValue[1];
            else if (keyValue[0] == "recovery_ratio")
               stats.recoveryRatio = StringToDouble(keyValue[1]);
         }
      }
      stats.isValid = true;
      // Print("成功读取喊单账户统计信息");
   }
   else
   {
      Print("统计信息格式错误");
   }

   return stats;
}

//+------------------------------------------------------------------+
//| 基于喊单账户统计信息检查恢复条件                                 |
//+------------------------------------------------------------------+
bool CheckRecoveryBySignalAccount(const AccountStats &stats)
{
   if (!stats.isValid)
   {
      Print("喊单账户统计信息无效，无法检查恢复条件");
      return false;
   }

   // 检查恢复比例是否达到阈值
   if (stats.recoveryRatio >= RecoveryRatioThreshold)
   {
      Print("喊单账户恢复比例达标: ", stats.recoveryRatio * 100, "%");
      return true;
   }

   // 检查浮亏是否已经大幅减少
   if (stats.floatingLoss > 0 && stats.floatingLoss < (stats.maxDrawdown * 0.3))
   {
      Print("喊单账户浮亏大幅减少: $", stats.floatingLoss);
      return true;
   }

   Print("喊单账户未达到恢复条件 - 恢复比例: ", stats.recoveryRatio * 100,
         "%, 浮亏: $", stats.floatingLoss);
   return false;
}

//+------------------------------------------------------------------+
//| 基于均线检查恢复条件                                             |
//+------------------------------------------------------------------+
bool CheckRecoveryByMovingAverage(string symbol, int timeframe)
{
   if (!UseMovingAverageCheck)
      return false;

   double ma = iMA(symbol, timeframe, MAPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
   double currentPrice = iClose(symbol, timeframe, 0);

   // 如果当前价格高于均线，认为趋势向好
   if (currentPrice > ma)
   {
      Print("价格高于均线，趋势向好 - 价格: ", currentPrice, ", 均线: ", ma);
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| 综合检查恢复条件                                                 |
//+------------------------------------------------------------------+
bool CheckRecoveryConditions(bool stoppedOut, double currentEquity = 0,
                             double initBalance = 0, double stopLossAmount = 0,
                             string symbol = "", int timeframe = 0)
{
   if (!stoppedOut)
   {
      Print("未处于止损状态，无需恢复");
      return false;
   }

   bool shouldRecover = false;

   // 1. 优先使用喊单账户统计信息检查
   if (UseSignalAccountStats)
   {
      AccountStats stats = ReadSignalAccountStats(SignalAccountNumber);
      if (stats.isValid)
      {
         shouldRecover = CheckRecoveryBySignalAccount(stats);
      }
   }

   // 2. 额外的均线检查（如果配置启用）
   if (!shouldRecover && UseMovingAverageCheck && symbol != "" && timeframe > 0)
   {
      shouldRecover = CheckRecoveryByMovingAverage(symbol, timeframe);
   }

   return shouldRecover;
}

//+------------------------------------------------------------------+
//| 获取喊单账户的恢复比例                                           |
//+------------------------------------------------------------------+
double GetSignalAccountRecoveryRatio(int accountNumber)
{
   AccountStats stats = ReadSignalAccountStats(accountNumber);
   if (stats.isValid)
   {
      return stats.recoveryRatio;
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| 获取喊单账户的浮亏信息                                           |
//+------------------------------------------------------------------+
double GetSignalAccountFloatingLoss(int accountNumber)
{
   AccountStats stats = ReadSignalAccountStats(accountNumber);
   if (stats.isValid)
   {
      return stats.floatingLoss;
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| 检查喊单账户统计信息是否有效                                     |
//+------------------------------------------------------------------+
bool IsSignalAccountStatsValid(int accountNumber)
{
   AccountStats stats = ReadSignalAccountStats(accountNumber);
   return stats.isValid;
}