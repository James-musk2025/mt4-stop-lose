// 喊单端 - 创建广播管道
#import "kernel32.dll"
int CreateNamedPipeW(string pipename, int openMode, int pipeMode, int maxInstances, int outBufferSize, int inBufferSize, int defaultTimeout, int securityAttributes);
bool ConnectNamedPipe(int hPipe, int& overlapped);
bool WriteFile(int hPipe, uchar& buffer[], int nBytesToWrite, int& nBytesWritten[], int& overlapped);
bool CloseHandle(int hObject);
int GetLastError();
#import

int hBroadcastPipe;
string pipeName = "\\\\.\\pipe\\MT4_Broadcast_" + IntegerToString(AccountNumber());
int counter = 0;
datetime lastSendTime = 0;
int error;

int OnInit()
{
   // 创建一個出站（只写）、基于消息的管道
   hBroadcastPipe = CreateNamedPipeW(pipeName,
                                    0x00000002, // PIPE_ACCESS_OUTBOUND
                                    0x00000004, // PIPE_TYPE_MESSAGE
                                    10,         // nMaxInstances: 允许10个客户端连接
                                    1024,       // outBufferSize
                                    0,          // inBufferSize (0 because it's outbound only)
                                    0, 0);
   
   if(hBroadcastPipe == -1) {
      error = GetLastError();
      Print("创建管道失败! 错误代码: ", error);
      return(INIT_FAILED);
   }
   
   Print("广播管道创建成功: ", pipeName);
   
   // 等待客户端连接
   int overlapped = 0;
   if(ConnectNamedPipe(hBroadcastPipe, overlapped)) {
      Print("客户端已连接到管道");
   } else {
      error = GetLastError();
      Print("等待客户端连接失败! 错误代码: ", error);
      return(INIT_FAILED);
   }
   
   Print("开始发送连续数字...");
   EventSetTimer(1000); // 每秒发送一次
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(hBroadcastPipe != -1) {
      CloseHandle(hBroadcastPipe);
      Print("管道句柄已关闭");
   }
}

void OnTimer()
{
   // 每秒发送一个连续数字
   counter++;
   string message = "数字: " + IntegerToString(counter);
   uchar data[];
   StringToCharArray(message, data);
   int written[1];
   int overlapped = 0;
   
   // 写入一次，所有连接的客户端都能读到
   if(WriteFile(hBroadcastPipe, data, ArraySize(data), written, overlapped)) {
      Print("发送成功: ", message, " (", written[0], " 字节)");
   } else {
      error = GetLastError();
      Print("发送失败! 错误代码: ", error);
   }
}