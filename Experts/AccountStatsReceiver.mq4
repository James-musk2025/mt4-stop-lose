// 账户统计信息接收端
#property copyright "Account Statistics Receiver"
#property link      ""
#property version   "1.00"
#property strict

// 要监控的账户号
int targetAccount = 2100891669; // 修改为要监控的实际账户号

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("账户统计接收端启动，监控账户: ", targetAccount);
   EventSetMillisecondTimer(300); // 每500毫秒检查一次
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
      
      // 显示解析结果
      Print("=== 账户统计信息 ===");
      Print("账户: ", targetAccount);
      Print("持仓浮亏: $", DoubleToStr(floatingLoss, 2));
      Print("账户净值: $", DoubleToStr(equity, 2));
      Print("最大回撤: $", DoubleToStr(MathAbs(maxDrawdown), 2));
      Print("恢复比率: ", DoubleToStr(recoveryRatio * 100, 1), "%");
      Print("更新时间: ", updateTime);
      Print("====================");
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
   string filename = IntegerToString(targetAccount) + "_stats.dat";
   
   if(FileIsExist(filename, FILE_COMMON))
   {
      int handle = FileOpen(filename, FILE_READ|FILE_TXT|FILE_COMMON);
      if(handle != INVALID_HANDLE)
      {
         string stats = FileReadString(handle);
         FileClose(handle);
         
         // 解析并显示统计信息
         ParseStatsString(stats);
      }
      else
      {
         Print("读取统计文件失败!");
      }
   }
   else
   {
      Print("未找到统计文件: ", filename);
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   CheckAndReadStats();
}