// 文件接收端 - 使用文件方式通信
input int targetAccount = 2100891669; // 设置为要跟随的账户号

int OnInit()
{
   // 设置要跟随的账户号（这里使用当前账户号作为示例）
   Print("文件接收端启动，监听账户: ", targetAccount);
   EventSetTimer(1); // 每500毫秒检查一次文件
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
}

void OnTimer()
{
   // 检查目标账户的.dat文件
   string filename = IntegerToString(targetAccount) + ".dat";
   
   if(FileIsExist(filename, FILE_COMMON)) {
      int handle = FileOpen(filename, FILE_READ|FILE_TXT|FILE_COMMON);
      if(handle != INVALID_HANDLE) {
         string message = FileReadString(handle);
         FileClose(handle);
         
         // 检查消息是否包含新内容（避免重复处理相同消息）
         static string lastMessage = "";
         if(message != lastMessage) {
            Print("收到新消息: ", message);
            lastMessage = message;
         } else {
            Print("检测到信号文件: ", filename, " (内容未变化)");
         }
      } else {
         Print("文件读取失败!");
      }
   } else {
      Print("没有找到信号文件: ", filename);
   }
}