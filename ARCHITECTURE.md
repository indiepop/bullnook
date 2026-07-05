# ARCHITECTURE.md

Bullnook 系统架构文档。

---

## 系统总览

```
┌─────────────────────────────────────────────────────────────┐
│                         iOS 客户端                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ 每日推荐页   │  │ 个股详情页   │  │ 自选股页     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                 │                 │              │
│  ┌────────────────────────────────────────────────────┐   │
│  │ SwiftUI Views + ViewModels + SwiftData 缓存        │   │
│  └────────────────────────────────────────────────────┘   │
│         │                 │                 │              │
│  ┌────────────────────────────────────────────────────┐   │
│  │ DataService / PickEngine / LLMAnalyzer            │   │
│  │ StockCache / WatchlistStore                        │   │
│  └────────────────────────────────────────────────────┘   │
│                              │                              │
│                  HTTP / JSON / JSONP / CSV                  │
│                              │                              │
└──────────────────────────────┼──────────────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────────────┐
│                      外部数据源                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ 新浪财经     │  │ 东方财富     │  │ 腾讯财经     │      │
│  │ 行情/K线     │  │ 龙虎榜/板块  │  │ 实时行情     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │ 新浪新闻     │  │ 公司公告     │  （备用）              │
│  └──────────────┘  └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
│                              │                              │
│                  LLM API（DeepSeek / Kimi / 通义）         │
│                              │                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 模块职责

### iOS 端

| 模块 | 职责 |
|------|------|
| `DailyPickView` | 展示每日 5 只推荐，支持下拉刷新 |
| `StockDetailView` | 展示个股详情、K线图、F10、入选理由 |
| `WatchlistView` | 自选股列表，每 5 分钟刷新行情 |
| `DataService` | 封装新浪/东方财富/腾讯等公开接口抓取 |
| `PickEngine` | 本地四维度评分，生成 Top 5 推荐 |
| `LLMAnalyzer` | 调用 LLM API 生成推荐理由 |
| `StockCache` | 本地缓存推荐数据和行情数据（SwiftData） |
| `WatchlistStore` | 自选股持久化（SwiftData） |
| `Widget` | 展示今日 Top 1 推荐 |

---

## 数据流

### 每日推荐生成流程

1. 用户打开 App 或手动下拉刷新
2. 检查本地是否已有当天推荐：
   - 有 → 直接展示
   - 无 → 展示最近一天的旧推荐，同时在后台生成新推荐
3. 后台异步拉取/更新本地数据：
   - 全市场股票列表（如未缓存或过期）
   - 日线行情数据
   - 龙虎榜数据
   - 板块热点数据
   - 个股新闻/公告
4. 按过滤规则排除退市股、科创板、北交所、停牌股
5. `PickEngine` 计算每只股票的四维度得分
6. 取综合得分最高的 5 只股票
7. 检查 LLM API Key 是否配置：
   - 已配置 → `LLMAnalyzer` 调用 LLM API 生成推荐理由
   - 未配置 → 只生成基于规则的推荐理由，提示用户配置 API Key
8. 结果写入 SwiftData，刷新 UI
9. 历史推荐表自动记录每次生成结果

### 自选股行情刷新流程

1. `WatchlistView` 加载时启动 5 分钟定时刷新
2. `DataService` 调用新浪/腾讯实时行情接口，传入自选股代码列表
3. 解析返回的最新价、涨跌幅、成交量等
4. 更新 SwiftData 中的 `WatchlistItem`
5. 刷新 UI

---

## 数据库设计（简化版）

```sql
-- 每日推荐
CREATE TABLE daily_picks (
    id TEXT PRIMARY KEY,
    date TEXT NOT NULL,
    rank INTEGER NOT NULL,
    stock_code TEXT NOT NULL,
    stock_name TEXT NOT NULL,
    score REAL NOT NULL,
    reason_summary TEXT,
    sector_score REAL,
    lhb_score REAL,
    trend_score REAL,
    news_score REAL,
    llm_analysis TEXT,
    generated_at TIMESTAMP
);

-- 日线行情
CREATE TABLE kline_daily (
    symbol TEXT,
    date TEXT,
    open REAL,
    high REAL,
    low REAL,
    close REAL,
    volume REAL,
    PRIMARY KEY (symbol, date)
);

-- 周线/月线
CREATE TABLE kline_weekly (...);
CREATE TABLE kline_monthly (...);

-- F10 财务指标
CREATE TABLE f10_metrics (
    symbol TEXT PRIMARY KEY,
    pe REAL,
    pb REAL,
    roe REAL,
    revenue_growth REAL,
    profit_growth REAL,
    updated_at TIMESTAMP
);

-- 龙虎榜
CREATE TABLE dragon_tiger (
    symbol TEXT,
    date TEXT,
    net_buy_amount REAL,
    buy_seats TEXT,
    sell_seats TEXT,
    PRIMARY KEY (symbol, date)
);

-- 板块热点
CREATE TABLE sector_hot (
    sector_name TEXT,
    date TEXT,
    change_pct REAL,
    net_inflow REAL,
    PRIMARY KEY (sector_name, date)
);
```

---

## 部署架构

### 开发期

- iOS：Xcode 本地运行
- 数据：直接调用新浪/东方财富公开接口
- 存储：SwiftData 本地存储
- LLM：使用本地配置的 API Key

### 生产期

- iOS：TestFlight / App Store
- 数据：继续走本地公开接口，无需后端
- 存储：SwiftData
- LLM：用户自备 API Key 或应用内配置
- 可选后端：仅用于未来推送通知、版本兼容数据聚合、用户反馈

---

## 扩展性考虑

- 推荐引擎未来可接入更多因子（北向资金、融资融券、情绪指标）
- 如果公开接口失效或不稳定，可升级为由后端聚合数据
- 前端缓存策略可升级为离线优先（SwiftData + 增量同步）
