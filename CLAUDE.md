# CLAUDE.md

> 本项目使用 Claude Code 进行代码生成。本文档是 Claude Code 理解项目、生成代码的核心上下文。  
> 项目名：Bullnook（牛角尖）  
> 类型：iOS A股选股 App（SwiftUI + Widget）  
> 数据与计算：iOS 端本地完成（公开接口 + 本地评分 + LLM API）  
> 可选后端：未来用于推送通知、版本兼容数据聚合、用户反馈  

---

## 项目概述

Bullnook 是一款 iOS 选股应用，每天为用户精选 5 只 A股。  
推荐逻辑在 iOS 端本地完成，综合板块热度、龙虎榜资金、个股走势、消息链四个维度评分，并通过 LLM 生成自然语言推荐理由。  
App 负责数据抓取、计算、展示、本地存储，所有数据保存在用户设备上。

---

## 技术栈

### 移动端（iOS）
- 语言：Swift 5.9+
- 框架：SwiftUI
- 最低系统版本：iOS 17.0
- 小组件：WidgetKit（今日推荐小组件）
- 网络：SwiftData + URLSession（或 Alamofire）
- 图表：Swift Charts
- 状态管理：SwiftData / @Observable / @State / @Bindable

### 数据与计算
- 数据抓取：iOS 端直接调用公开免费接口（新浪、东方财富、腾讯等）
- 本地计算：推荐评分引擎在 iOS 本地运行
- 本地存储：SwiftData
- LLM：DeepSeek / Kimi / 通义千问（通过 iOS 端直接调用 API）
- 可选后端：未来用于推送通知、版本兼容数据聚合、用户反馈

---

## 目录结构

```
Bullnook/
├── Bullnook/                    # iOS App 主工程
│   ├── App/
│   │   └── BullnookApp.swift
│   ├── Views/
│   │   ├── DailyPickView/       # 每日推荐主页面
│   │   ├── StockDetailView/     # 个股详情页
│   │   ├── WatchlistView/       # 自选股页面
│   │   └── Components/          # 复用组件
│   ├── Models/
│   │   ├── Stock.swift
│   │   ├── DailyPick.swift
│   │   ├── KLineData.swift
│   │   └── F10Metric.swift
│   ├── Services/
│   │   ├── DataService/         # 公开数据源接口封装
│   │   │   ├── SinaAPI.swift
│   │   │   ├── EastMoneyAPI.swift
│   │   │   └── TencentAPI.swift
│   │   ├── PickEngine.swift     # 本地推荐评分引擎
│   │   ├── LLMAnalyzer.swift    # LLM 分析生成
│   │   ├── StockCache.swift     # 本地数据缓存
│   │   └── WatchlistStore.swift # 自选股持久化
│   ├── Widget/
│   │   └── BullnookWidget.swift
│   └── Resources/
│       └── Assets.xcassets
├── docs/                        # 产品/技术文档
│   ├── PRD.md
│   ├── ARCHITECTURE.md
│   ├── DATA_SOURCES.md
│   ├── DESIGN.md
│   └── ROADMAP.md
├── CLAUDE.md
└── README.md
```

---

## 核心数据模型

### Swift 模型

```swift
struct Stock: Identifiable, Codable {
    let id: String              // 股票代码，如 "600519"
    let symbol: String          // 带市场前缀，如 "sh600519"
    let name: String
    let industry: String
    let marketCap: Double
}

struct DailyPick: Identifiable, Codable {
    let id: String
    let date: String            // YYYY-MM-DD
    let rank: Int               // 1-5
    let stock: Stock
    let score: Double           // 综合得分 0-100
    let reasonSummary: String   // 一句话理由
    let dimensions: PickDimensions
    let analysis: String        // LLM 生成的分析
}

struct PickDimensions: Codable {
    let sectorScore: Double
    let lhbScore: Double        // 龙虎榜
    let trendScore: Double
    let newsScore: Double
}

struct KLineData: Identifiable, Codable {
    let id: String
    let date: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}

struct F10Metric: Codable {
    let pe: Double
    let pb: Double
    let roe: Double
    let revenueGrowth: Double
    let profitGrowth: Double
}

struct WatchlistItem: Identifiable, Codable {
    let id: String
    let stock: Stock
    let addedAt: Date
    let currentPrice: Double
    let changePercent: Double
}
```

---

## 数据服务（DataService）

所有数据在 iOS 端本地抓取，不依赖自建后端。数据源封装如下：

| 数据源 | 用途 | 接口类型 |
|-------|------|---------|
| 新浪财经 | 实时行情、K线数据 | HTTP JSONP / CSV |
| 东方财富 | 龙虎榜、板块、F10、个股新闻 | REST API |
| 腾讯财经 | 实时行情快照（备用） | HTTP JSON |

### 新浪实时行情接口

```
https://hq.sinajs.cn/list=sh600519,sz000001
```

返回格式：`var hq_str_sh600519="贵州茅台,23.45,...";`

### 新浪历史 K线

```
https://quotes.sina.cn/cn/api/quotes.php?symbol=sh600519&datalen=250&fq=1&d=1
```

参数：
- `datalen`: 返回条数
- `fq`: 1 为前复权
- `d`: 1 为日线，7 为周线，30 为月线

### 东方财富历史 K线

```
https://push2his.eastmoney.com/api/qt/stock/kline/get?secid=1.600519&fields1=f1,f2,f3,f4,f5,f6&fields2=f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61&klt=101&fqt=1&beg=20240101&end=20260705
```

参数：
- `secid=1.600519`: 1 表示上海，0 表示深圳
- `klt=101`: 101 日线，102 周线，103 月线
- `fqt=1`: 前复权

返回数据字段：`日期,开盘,收盘,最高,最低,成交量,成交额,振幅,涨跌幅,涨跌额,换手率`

### 东方财富龙虎榜

```
https://datacenter-web.eastmoney.com/api/data/v1/get?sortColumns=SECURITY_CODE,TRADE_DATE&sortTypes=-1,-1&pageSize=500&pageNumber=1&reportName=RPT_DMSK_TS_LSTOCKT&columns=ALL&source=WEB&client=WEB
```

### 东方财富板块列表

```
https://push2.eastmoney.com/api/qt/clist/get?pn=1&pz=100&po=1&np=1&fltt=2&invt=2&fid=f3&fs=m:90+t:2&fields=f12,f14,f2,f3,f4,f5,f6,f7,f8,f9,f10,f18,f20,f21,f22,f23,f24,f25,f26,f33,f34,f35,f36,f37,f38,f39,f40,f41,f42,f43,f44,f45,f46,f47,f48,f49,f50,f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61,f62,f63,f64,f65,f66,f67,f68,f69,f70,f71,f72,f73,f74,f75,f76,f77,f78,f79,f80,f81,f82,f83,f84,f85,f86,f87,f88,f89,f90,f91,f92,f93
```

### 东方财富个股新闻

```
https://searchapi.eastmoney.com/api/sns/get?type=14&cb=jQuery&keyword=600519&pageindex=1&pagesize=20
```

---

## 本地推荐流程

1. 首次使用或数据过期时，抓取全市场股票列表
2. 根据本地缓存的日线数据，计算每只股票走势得分
3. 抓取板块/龙虎榜数据，计算板块得分和龙虎榜得分
4. 抓取个股新闻/公告，计算消息链得分
5. 四维度加权求和，取 Top 5
6. 调用 LLM API，为 Top 5 生成推荐理由
7. 结果存入本地 SwiftData，Widget 读取展示

---

## 本地存储

- SwiftData 持久化以下数据：
  - `DailyPick`：每日推荐结果
  - `KLineData`：日线/周线/月线行情
  - `F10Metric`：财务指标
  - `WatchlistItem`：自选股
  - `StockInfo`：全市场股票基础信息
  - `SectorData` / `DragonTigerData`：板块和龙虎榜数据
- 缓存策略：数据按日期版本化，过期后重新抓取

---

## 编码规范

### Swift
- 使用 SwiftUI 声明式语法，避免 UIKit 依赖
- ViewModel 使用 `@Observable` class
- 网络请求封装在 `DataService` 各模块中，统一错误处理
- 数据模型使用 `Codable`，便于本地缓存
- 颜色、字体、间距统一使用 `Assets` 和 `Theme` 扩展
- 异步操作使用 `async/await`，避免回调地狱
- 公开接口解析使用正则或 JSON 解析，兼容 JSONP/CSV 格式
- 数据抓取必须加间隔和重试，避免触发反爬

---

## 错误处理原则

- 网络失败时：展示友好占位图，允许下拉刷新
- 数据缺失时：显示 "数据暂不可用"，不崩溃
- 抓取失败时：记录日志，使用本地缓存或默认值，不阻断主流程
- 所有 `do-catch` 块必须记录错误日志，不吞异常

---

## 安全与合规

- 不存储用户交易信息
- 自选股数据仅本地存储（SwiftData）
- 推荐结果仅作为参考，必须在前端显示风险免责声明
- LLM API 密钥由用户自行配置或本地安全存储，不硬编码在代码中
- 未配置 LLM API Key 时，推荐功能仍可展示基于规则的评分结果，但缺少 LLM 分析文本
- 推荐功能缺失 LLM 分析时，不影响个股详情、自选股、K线图等其他功能

---

## 开发流程

1. 先实现公开数据源抓取（新浪 K线、东方财富龙虎榜/板块/新闻）
2. 实现推荐过滤规则（排除退市、科创板、北交所、停牌股）
3. 再实现本地推荐引擎：四维度评分 + Top 5 排序
4. 接入 LLM API，生成推荐理由（未配置 Key 时支持降级）
5. 实现历史推荐记录表，记录从推荐日至今的涨跌幅
6. 开发 iOS 主流程：每日推荐 → 个股详情 → 加自选
7. 接入 Widget：今日 Top 1 推荐
8. 最后完善 K线图（Swift Charts）、F10、历史推荐总表
9. 全程优先保证主流程可用，数据接口失败时优雅降级

---

## 与 Claude Code 协作方式

- 每次生成代码前，先阅读 `CLAUDE.md` 和相关的 `.md` 文档
- 优先按 P0 → P1 → P2 顺序实现功能
- 修改 Swift 模型后，同步检查 View 和 DataService 调用是否匹配
- 修改数据源接口后，同步更新模型和文档
- 公开数据源不稳定，抓取逻辑必须加错误处理和重试
- 不确定时，先提出假设，再生成代码
- 纯本地架构，不生成 Python 后端或 FastAPI 代码
