// 文件广播发送端 - 使用文件方式通信
int counter = 0;

int OnInit()
{
   Print("文件广播发送端启动");
   Print("开始写入连续数字到文件...");
   EventSetMillisecondTimer(500); // 每500毫秒写入一次
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
}

void OnTimer()
{
   // 每秒写入一个连续数字
   counter++;
   string message = "数字: " + IntegerToString(counter);
   
   // 创建文件名：账户号.dat
   string filename = IntegerToString(AccountNumber()) + ".dat";
   
   // 写入文件到MT4的Files目录
   int handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(handle != INVALID_HANDLE) {
      FileWrite(handle, message);
      FileClose(handle);
      Print("写入成功: ", message, " 到文件 ", filename);
   } else {
      Print("文件写入失败!");
   }
}