// 账户统计信息显示功能
#property strict

int GetRandom300to500()
{
    return 300 + MathRand() % 201;
}

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
//| 更新风险管理信息显示（用于AccountStatsReceiver）                 |
//+------------------------------------------------------------------+
void UpdateRiskManagementDisplay(int signalAccountNumber, double initBalance,
                                 double stopLossAmount, double stopLossEquity,
                                 double accountEquity,
                                 double recoveryThreshold, string eaTemplates,
                                 int corner = 0, int x = 10, int y = 150, int textColor = Red)
{
   // 创建7个单独的文本对象，每行一个
   string objNames[8];
   objNames[0] = "Risk_Separator_" + IntegerToString(ChartID());
   objNames[1] = "Risk_SignalAccount_" + IntegerToString(ChartID());
   objNames[2] = "Risk_InitialBalance_" + IntegerToString(ChartID());
   objNames[3] = "Risk_StopLossAmount_" + IntegerToString(ChartID());
   objNames[4] = "Risk_StopLossEquity_" + IntegerToString(ChartID());
   objNames[5] = "Risk_AccountEquity_" + IntegerToString(ChartID());
   objNames[6] = "Risk_RecoveryThreshold_" + IntegerToString(ChartID());
   objNames[7] = "Risk_EATemplates_" + IntegerToString(ChartID());

   string texts[8];
   texts[0] = "------------";
   texts[1] = StringFormat("喊单账户: %d", signalAccountNumber);
   texts[2] = StringFormat("账户余额: $%.2f", initBalance);
   texts[3] = StringFormat("止损金额: $%.2f", stopLossAmount);
   texts[4] = StringFormat("止损净值: $%.2f", stopLossEquity);
   texts[5] = StringFormat("账户净值: $%.2f", accountEquity);
   texts[6] = StringFormat("重启阈值: %.1f%%", recoveryThreshold * 100);
   texts[7] = StringFormat("EA模板: %s", eaTemplates);

   for (int i = 0; i < 7; i++)
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
//| 清除风险管理信息显示                                             |
//+------------------------------------------------------------------+
void ClearRiskManagementDisplay()
{
   string objNames[7];
   objNames[0] = "Risk_SignalAccount_" + IntegerToString(ChartID());
   objNames[1] = "Risk_Separator_" + IntegerToString(ChartID());
   objNames[2] = "Risk_InitialBalance_" + IntegerToString(ChartID());
   objNames[3] = "Risk_StopLossAmount_" + IntegerToString(ChartID());
   objNames[4] = "Risk_StopLossEquity_" + IntegerToString(ChartID());
   objNames[5] = "Risk_RecoveryThreshold_" + IntegerToString(ChartID());
   objNames[6] = "Risk_EATemplates_" + IntegerToString(ChartID());

   for (int i = 0; i < 7; i++)
   {
      ObjectDelete(objNames[i]);
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