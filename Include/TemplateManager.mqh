// 模板管理模块 - 简化版，使用结构体数组
#property strict
#property copyright "Template Manager Module - Simplified"
#property link ""
#property version "1.00"

// 模板-图表映射结构体
struct TemplateChartMapping
{
    string templateName;
    long chartId;
};

// 全局映射数组
TemplateChartMapping templateMappings[];

//+------------------------------------------------------------------+
//| 初始化模板管理模块                                               |
//+------------------------------------------------------------------+
void InitTemplateManager()
{
    // 只清理无效的映射记录，保留仍然有效的图表映射
    CleanupInvalidMappings();
    Print("模板管理模块初始化完成，有效映射数量: ", ArraySize(templateMappings));
}

//+------------------------------------------------------------------+
//| 应用模板到图表并记录映射                                         |
//+------------------------------------------------------------------+
bool ApplyTemplateAndRecord(string templateName, string symbol = "", int timeframe = 0)
{
    if (symbol == "") symbol = Symbol();
    if (timeframe == 0) timeframe = Period();
    
    // 检查是否已有该模板的有效图表
    long existingChartId = FindChartByTemplate(templateName);
    if (existingChartId != -1)
    {
        Print("模板已应用在图表 ", existingChartId, "，跳过重复应用: ", templateName);
        return true;
    }
    
    // 创建新图表
    long chartId = ChartOpen(symbol, timeframe);
    if (chartId == 0)
    {
        Print("创建图表失败");
        return false;
    }
    
    // 应用模板
    if (!ChartApplyTemplate(chartId, templateName))
    {
        ChartClose(chartId);
        Print("应用模板失败: ", templateName);
        return false;
    }
    
    // 记录映射关系
    RecordTemplateMapping(templateName, chartId);
    Print("模板应用成功: ", templateName, " -> 图表 ", chartId);
    return true;
}

//+------------------------------------------------------------------+
//| 记录模板-ChartId映射关系                                         |
//+------------------------------------------------------------------+
void RecordTemplateMapping(string templateName, long chartId)
{
    int newSize = ArraySize(templateMappings) + 1;
    ArrayResize(templateMappings, newSize);
    templateMappings[newSize-1].templateName = templateName;
    templateMappings[newSize-1].chartId = chartId;
}

//+------------------------------------------------------------------+
//| 通过模板名查找图表                                               |
//+------------------------------------------------------------------+
long FindChartByTemplate(string templateName)
{
    for (int i = 0; i < ArraySize(templateMappings); i++)
    {
        if (templateMappings[i].templateName == templateName)
        {
            // 检查图表是否仍然有效
            if (ChartGetInteger(templateMappings[i].chartId, CHART_WINDOW_HANDLE) != 0)
            {
                return templateMappings[i].chartId;
            }
        }
    }
    return -1;
}

//+------------------------------------------------------------------+
//| 关闭指定模板的所有图表                                           |
//+------------------------------------------------------------------+
void CloseTemplateCharts(string templateName)
{
    int closedCount = 0;
    for (int i = ArraySize(templateMappings) - 1; i >= 0; i--)
    {
        if (templateMappings[i].templateName == templateName)
        {
            if (ChartGetInteger(templateMappings[i].chartId, CHART_WINDOW_HANDLE) != 0)
            {
                ChartClose(templateMappings[i].chartId);
                closedCount++;
            }
            // 移除映射记录
            ArrayRemove(templateMappings, i, 1);
        }
    }
    Print("关闭模板 '", templateName, "' 的 ", closedCount, " 个图表");
}

//+------------------------------------------------------------------+
//| 关闭所有参数指定模板的图表                                       |
//+------------------------------------------------------------------+
void CloseAllTemplateCharts(string templatesList)
{
    string templateList[];
    int count = StringSplit(templatesList, ',', templateList);
    
    for (int i = 0; i < count; i++)
    {
        string templateName = StringTrim(templateList[i]);
        CloseTemplateCharts(templateName);
    }
}

//+------------------------------------------------------------------+
//| 恢复参数指定模板的图表                                           |
//+------------------------------------------------------------------+
void RestoreTemplateCharts(string templatesList)
{
    string templateList[];
    int count = StringSplit(templatesList, ',', templateList);
    
    for (int i = 0; i < count; i++)
    {
        string templateName = StringTrim(templateList[i]);
        ApplyTemplateAndRecord(templateName);
    }
}

//+------------------------------------------------------------------+
//| 字符串去除前后空格                                               |
//+------------------------------------------------------------------+
string StringTrim(string str)
{
    int start = 0;
    int end = StringLen(str) - 1;
    
    while (start <= end && StringGetCharacter(str, start) == ' ')
        start++;
        
    while (end >= start && StringGetCharacter(str, end) == ' ')
        end--;
        
    return StringSubstr(str, start, end - start + 1);
}

//+------------------------------------------------------------------+
//| 清理无效的图表映射记录                                           |
//+------------------------------------------------------------------+
void CleanupInvalidMappings()
{
    for (int i = ArraySize(templateMappings) - 1; i >= 0; i--)
    {
        if (ChartGetInteger(templateMappings[i].chartId, CHART_WINDOW_HANDLE) == 0)
        {
            // 图表已关闭，移除映射记录
            ArrayRemove(templateMappings, i, 1);
        }
    }
}

//+------------------------------------------------------------------+
//| 自定义ArrayRemove函数（MQL4兼容）                               |
//+------------------------------------------------------------------+
void ArrayRemove(TemplateChartMapping &array[], int index, int count = 1)
{
    int size = ArraySize(array);
    if (index < 0 || index >= size) return;
    
    // 创建临时数组
    TemplateChartMapping tempArray[];
    ArrayResize(tempArray, size - count);
    
    // 复制要保留的元素
    int destIndex = 0;
    for (int i = 0; i < size; i++)
    {
        if (i < index || i >= index + count)
        {
            tempArray[destIndex] = array[i];
            destIndex++;
        }
    }
    
    // 更新原数组
    ArrayResize(array, size - count);
    for (int i = 0; i < size - count; i++)
    {
        array[i] = tempArray[i];
    }
}