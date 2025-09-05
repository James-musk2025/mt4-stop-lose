// 账户统计信息显示功能
#property strict

//+------------------------------------------------------------------+
//| 更新统计信息显示                                                 |
//+------------------------------------------------------------------+
void UpdateStatsDisplay(double floatingLoss, double equity, double maxDrawdownParam,
                        double recoveryRatio, string updateTime, int corner = 0, int x = 10, int y = 20, int textColor = Red)
{
   // 创建5个单独的文本对象，每行一个
   string objNames[5];
   objNames[0] = "Stats_FloatingLoss_" + IntegerToString(ChartID());
   objNames[1] = "Stats_Equity_" + IntegerToString(ChartID());
   objNames[2] = "Stats_MaxDrawdown_" + IntegerToString(ChartID());
   objNames[3] = "Stats_RecoveryRatio_" + IntegerToString(ChartID());
   objNames[4] = "Stats_UpdateTime_" + IntegerToString(ChartID());

   string texts[5];
   texts[0] = StringFormat("持仓浮亏: $%.2f", floatingLoss);
   texts[1] = StringFormat("账户净值: $%.2f", equity);
   texts[2] = StringFormat("最大回撤: $%.2f", MathAbs(maxDrawdownParam));
   texts[3] = StringFormat("恢复比率: %.1f%%", recoveryRatio * 100);
   texts[4] = StringFormat("更新时间: %s", updateTime);

   for (int i = 0; i < 5; i++)
   {
      // 删除旧对象
      ObjectDelete(objNames[i]);

      // 创建新对象
      ObjectCreate(objNames[i], OBJ_LABEL, 0, 0, 0);
      ObjectSetText(objNames[i], texts[i], 10, "Arial", textColor);
      ObjectSet(objNames[i], OBJPROP_CORNER, corner);
      ObjectSet(objNames[i], OBJPROP_XDISTANCE, x);
      ObjectSet(objNames[i], OBJPROP_YDISTANCE, y + (i * 20)); // 每行间隔20像素
      ObjectSet(objNames[i], OBJPROP_BACK, false);
      ObjectSet(objNames[i], OBJPROP_SELECTABLE, false);
      ObjectSet(objNames[i], OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| 清除统计信息显示                                                 |
//+------------------------------------------------------------------+
void ClearStatsDisplay()
{
   string objNames[5];
   objNames[0] = "Stats_FloatingLoss_" + IntegerToString(ChartID());
   objNames[1] = "Stats_Equity_" + IntegerToString(ChartID());
   objNames[2] = "Stats_MaxDrawdown_" + IntegerToString(ChartID());
   objNames[3] = "Stats_RecoveryRatio_" + IntegerToString(ChartID());
   objNames[4] = "Stats_UpdateTime_" + IntegerToString(ChartID());

   for (int i = 0; i < 5; i++)
   {
      ObjectDelete(objNames[i]);
   }
}