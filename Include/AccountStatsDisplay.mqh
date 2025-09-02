// 账户统计信息显示功能
#property strict

//+------------------------------------------------------------------+
//| 在图表上显示统计信息                                             |
//+------------------------------------------------------------------+
void DisplayAccountStats(int corner = 0, int x = 10, int y = 20)
{
   // 获取统计信息（如果是接收端，需要从其他地方获取数据）
   // 这里只是显示框架，具体数据需要在调用处提供
   
   string statsText = "账户统计信息加载中...";
   
   // 创建唯一对象名称避免冲突
   string objName = "AccountStats_" + IntegerToString(ChartID());
   
   // 删除旧对象
   ObjectDelete(objName);
   
   // 创建文本对象
   ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
   ObjectSetText(objName, statsText, 10, "Arial", Red);
   ObjectSet(objName, OBJPROP_CORNER, corner);
   ObjectSet(objName, OBJPROP_XDISTANCE, x);
   ObjectSet(objName, OBJPROP_YDISTANCE, y);
   ObjectSet(objName, OBJPROP_BACK, false);
   ObjectSet(objName, OBJPROP_SELECTABLE, false);
   ObjectSet(objName, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| 更新统计信息显示                                                 |
//+------------------------------------------------------------------+
void UpdateStatsDisplay(double floatingLoss, double equity, double maxDrawdownParam, 
                       double recoveryRatio, string updateTime, int corner = 0, int x = 10, int y = 20)
{
   // 格式化显示文本
   string statsText = StringFormat(
      "持仓浮亏: $%.2f\n账户净值: $%.2f\n最大回撤: $%.2f\n恢复比率: %.1f%%\n更新时间: %s",
      floatingLoss,
      equity,
      MathAbs(maxDrawdownParam),
      recoveryRatio * 100,
      updateTime
   );
   
   string objName = "AccountStats_" + IntegerToString(ChartID());
   
   // 如果对象不存在则创建
   if(ObjectFind(objName) < 0)
   {
      ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
      ObjectSetText(objName, statsText, 10, "Arial", Red);
      ObjectSet(objName, OBJPROP_CORNER, corner);
      ObjectSet(objName, OBJPROP_XDISTANCE, x);
      ObjectSet(objName, OBJPROP_YDISTANCE, y);
      ObjectSet(objName, OBJPROP_BACK, false);
      ObjectSet(objName, OBJPROP_SELECTABLE, false);
      ObjectSet(objName, OBJPROP_HIDDEN, true);
   }
   else
   {
      // 更新文本内容
      ObjectSetText(objName, statsText, 10, "Arial", Red);
   }
}

//+------------------------------------------------------------------+
//| 清除统计信息显示                                                 |
//+------------------------------------------------------------------+
void ClearStatsDisplay()
{
   string objName = "AccountStats_" + IntegerToString(ChartID());
   ObjectDelete(objName);
}