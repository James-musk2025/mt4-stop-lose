#property copyright "Copyright 2025"
#property link      "https://www.example.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    int totalOrders = OrdersTotal();
    
    for(int i = totalOrders - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            int orderType = OrderType();
            
            // 检查是否为挂单类型
            if(orderType == OP_BUYLIMIT || 
               orderType == OP_SELLLIMIT ||
               orderType == OP_BUYSTOP ||
               orderType == OP_SELLSTOP)
            {
                int ticket = OrderTicket();
                bool deleted = OrderDelete(ticket);
                
                if(deleted)
                {
                    Print("已删除挂单 #", ticket);
                }
                else
                {
                    Print("删除挂单 #", ticket, " 失败. 错误代码: ", GetLastError());
                }
            }
        }
    }
    
    Print("所有挂单处理完成");
}