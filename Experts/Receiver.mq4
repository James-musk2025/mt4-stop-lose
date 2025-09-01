// 跟单端 - 连接广播管道进行读取
#import "kernel32.dll"
int CreateFileW(string filename, int desiredAccess, int shareMode, int securityAttributes, int creationDisposition, int flagsAndAttributes, int templateFile);
bool ReadFile(int hPipe, uchar& buffer[], int nBytesToRead, int& nBytesRead[], int& overlapped);
bool PeekNamedPipe(int hPipe, int& buffer[], int nBufferSize, int& bytesRead[], int& totalBytesAvail[], int& bytesLeftThisMessage[]);
bool CloseHandle(int hObject);
int GetLastError();
#import

int hPipe;

int OnInit()
{
   // 使用当前账户号来连接管道（或者可以硬编码特定的账户号）
   string accountToFollow = "2100891669"; // 连接到当前账户的管道
   string pipeName = "\\\\.\\pipe\\MT4_Broadcast_" + accountToFollow;
   
   Print("尝试连接管道: ", pipeName);
   
   // 以只读方式打开广播管道
   hPipe = CreateFileW(pipeName,
                      -2147483648, // GENERIC_READ (0x80000000)
                      0x00000001 | 0x00000002, // FILE_SHARE_READ | FILE_SHARE_WRITE
                      0,
                      3,         // OPEN_EXISTING
                      0, 0);
   
   if(hPipe == -1) {
      int error = GetLastError();
      Print("连接管道失败! 错误代码: ", error);
      Print("请确保广播端正在运行...");
      return(INIT_FAILED);
   }
   
   Print("成功连接到广播管道!");
   EventSetTimer(500); // 每500毫秒检查一次数据
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(hPipe != -1) {
      CloseHandle(hPipe);
      Print("管道连接已关闭");
   }
}

void OnTimer()
{
   // 检查管道中是否有可用数据
   int totalBytesAvail[1] = {0};
   int bytesRead[1] = {0};
   int bytesLeftThisMessage[1] = {0};
   int buffer[1] = {0};
   int nBufferSize = 0;
   
   if(PeekNamedPipe(hPipe, buffer, nBufferSize, bytesRead, totalBytesAvail, bytesLeftThisMessage)) {
      if(totalBytesAvail[0] > 0) {
         uchar data[1024];
         int bytesReadActual[1] = {0};
         int overlapped = 0;
         
         if(ReadFile(hPipe, data, MathMin(ArraySize(data), totalBytesAvail[0]), bytesReadActual, overlapped)) {
            string message = CharArrayToString(data, 0, bytesReadActual[0]);
            Print("收到消息: ", message);
         } else {
            int readError = GetLastError();
            Print("读取数据失败! 错误代码: ", readError);
         }
      }
   } else {
      int peekError = GetLastError();
      Print("检查管道数据失败! 错误代码: ", peekError);
   }
}