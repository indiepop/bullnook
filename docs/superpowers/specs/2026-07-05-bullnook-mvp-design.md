# Bullnook MVP 设计文档

> 日期：2026-07-05
> 主题：Bullnook iOS A股选股 App MVP

---

## 背景与目标

Bullnook（牛角尖）是一款 iOS A股选股应用，每天为用户精选 5 只 A 股。推荐逻辑完全在 iOS 端本地完成，综合板块热度、龙虎榜资金、个股走势、消息链四个维度评分，并通过 LLM 生成自然语言推荐理由。

本设计文档基于项目已有的 PRD.md、ARCHITECTURE.md、DATA_SOURCES.md、DESIGN.md、ROADMAP.md 和 docs/CHART.md 制定，用于指导 MVP 实现。

---

## 选型决策

### 方案对比

| 方案 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| 纯本地 SwiftUI + SwiftData | 无后端成本、符合项目要求、MVP 最快 | 公开接口可能不稳定 | **采用** |
| 本地 App + 轻量后端代理 | 接口稳定、便于维护 | 需后端部署、违背纯本地架构 | 不采用 |
| 本地 + CloudKit 同步 | 跨设备同步 | MVP 价值有限、增加复杂度 | 不采用 |

**最终选择方案 1：纯本地 SwiftUI + SwiftData。**

---

## 技术栈

- **语言**：Swift 5.9+
- **UI 框架**：SwiftUI
- **最低系统版本**：iOS 17.0
- **小组件**：WidgetKit
- **本地存储**：SwiftData
- **图表**：Swift Charts
- **网络**：URLSession（统一封装）
- **状态管理**：@Observable / @State / @Bindable
- **LLM**：DeepSeek / Kimi / 通义千问（用户自备 API Key）

---

## 架构总览

```
┌─────────────────────────────────────────────┐
│                 iOS 客户端                   │
│  ┌──────────────┐ ┌──────────────┐          │
│  │ DailyPickView│ │StockDetailView          │
│  └──────────────┘ └──────────────┘          │
│  ┌──────────────┐ ┌──────────────┐          │
│  │WatchlistView │ │HistoricalPicksView      │
│  └──────────────┘ └──────────────┘          │
│  ┌─────────────────────────────────────┐   │
│  │ ViewModels + SwiftData 缓存/持久化  │   │
│  └─────────────────────────────────────┘   │
│  ┌─────────────────────────────────────┐   │
│  │ DataService / PickEngine / LLMAnalyzer│  │
│  └─────────────────────────────────────┘   │
│                    │                         │
│         HTTP / JSON / JSONP / CSV          │
│                    │                         │
└────────────────────┼────────────────────────┘
                     │
    ┌────────────────┼────────────────┐
    │         外部数据源               │
    │  新浪财经  东方财富  腾讯财经    │
    └─────────────────────────────────┘
                     │
    ┌────────────────┼────────────────┐
    │      LLM API (DeepSeek/Kimi/通义) │
    └─────────────────────────────────┘
```

---

## 核心数据模型（SwiftData）

- `Stock`：股票基础信息
- `DailyPick`：每日推荐结果（含四维得分、LLM 分析）
- `HistoricalPick`：历史推荐记录（含推荐日至今涨跌幅）
- `KLineData`：日线/周线/月线行情
- `F10Metric`：财务指标
- `WatchlistItem`：自选股
- `SectorData`：板块热度数据
- `DragonTigerData`：龙虎榜数据

---

## 模块职责

| 模块 | 职责 |
|------|------|
| `DataService` | 封装新浪/东方财富/腾讯公开接口，统一错误处理、重试、节流 |
| `PickEngine` | 本地四维度评分 + 过滤规则 + Top 5 排序 |
| `LLMAnalyzer` | 调用 LLM API 生成推荐理由，未配置 Key 时降级 |
| `StockCache` | SwiftData 数据缓存与读取 |
| `WatchlistStore` | 自选股持久化与定时刷新 |
| `DailyPickViewModel` | 推荐页状态管理 |
| `StockDetailViewModel` | 详情页状态管理 |
| `WatchlistViewModel` | 自选股页状态管理 |
| `BullnookWidget` | 今日 Top 1 推荐小组件 |

---

## 数据流

### 每日推荐生成

1. 用户打开 App 或下拉刷新
2. 先展示本地缓存的旧推荐
3. 后台异步抓取/更新数据：
   - 全市场股票列表
   - 日线行情
   - 龙虎榜数据
   - 板块热点数据
   - 个股新闻/公告
4. 过滤：排除退市股、ST 股、科创板（688）、北交所（8/4 开头）、停牌股
5. `PickEngine` 计算四维度得分
6. 取 Top 5
7. 若 LLM API Key 已配置，生成 LLM 推荐理由；否则使用规则摘要
8. 写入 SwiftData，刷新 UI
9. 同步写入历史推荐表

### 自选股刷新

1. `WatchlistView` 加载时启动 5 分钟定时器
2. 调用实时行情接口批量刷新
3. 更新 SwiftData 中的 `WatchlistItem`
4. 刷新 UI

---

## 数据源

| 数据 | 来源 | 接口类型 |
|------|------|---------|
| 实时行情 | 新浪财经 / 腾讯财经 | HTTP JSONP / JSON |
| 历史 K线 | 新浪财经 / 东方财富 | HTTP JSON / CSV |
| 龙虎榜 | 东方财富 | REST JSON |
| 板块热点 | 东方财富 | REST JSON |
| 个股新闻 | 东方财富 | JSONP |
| F10 财务 | 东方财富 | REST JSON |

---

## UI 结构

### 页面

- **DailyPickView（首页）**：今日 5 只推荐列表，支持下拉刷新
- **StockDetailView（个股详情）**：K线图、F10、入选理由分析
- **WatchlistView（自选股）**：自选列表、5 分钟刷新
- **HistoricalPicksView（历史推荐）**：按日期展示历史推荐及涨跌幅
- **SettingsView（设置）**：LLM API Key 配置、服务商选择

### 小组件

- **Small / Medium 尺寸**：展示今日 Top 1 推荐
- 点击跳转个股详情

### 设计关键词

- 深色模式优先
- 主色：深墨蓝（#0F172A）+ 金色强调（#F59E0B）
- 涨绿跌红
- 卡片式布局，强调数据可读性

---

## 错误处理原则

- 网络失败：展示友好占位图，允许下拉刷新/重试
- 数据缺失：显示“数据暂不可用”，不崩溃
- 抓取失败：记录日志，使用本地缓存或默认值，不阻断主流程
- 所有 `do-catch` 块记录错误，不吞异常
- 公开接口请求加间隔和重试，避免触发反爬

---

## 安全与合规

- LLM API Key 由用户配置，存储在 Keychain
- 不在代码中硬编码 API Key
- 自选股数据仅本地存储
- 推荐结果仅作为参考，多处显示风险免责声明

---

## MVP 范围

### 必须实现（P0）

1. 创建 Xcode 项目骨架（iOS 17+ SwiftUI App + Widget Extension）
2. SwiftData 模型定义
3. DataService 公开接口封装
4. PickEngine 推荐评分引擎
5. LLMAnalyzer 推荐理由生成
6. LLM API Key 配置（启动弹框 + 设置页 + Keychain）
7. DailyPickView
8. StockDetailView（含 Swift Charts K线图）
9. WatchlistView
10. HistoricalPicksView
11. Widget（今日 Top 1）
12. 风险免责声明

### 明确不做

- 交易功能
- 实时 Level-2 行情
- 社区/评论/直播
- 复杂策略回测
- 投顾服务或收益承诺

---

## 开发顺序

按 CLAUDE_CODE_STARTER.md 中的 12 步顺序逐步实现，每完成一个模块简要说明并继续下一步。

---

## 附录：参考文档

- `CLAUDE.md`
- `PRD.md`
- `ARCHITECTURE.md`
- `DATA_SOURCES.md`
- `DESIGN.md`
- `ROADMAP.md`
- `docs/CHART.md`
