# 给 Claude Code 的启动提示词

请复制以下内容，粘贴到 Claude Code 的输入框中，开始生成 Bullnook 项目代码。

---

## 启动提示词

```
我们要开始开发一个名为 Bullnook（中文名：牛角尖）的 iOS A股选股 App。项目目录在 /Users/yangzhuo/Bullnook。

请先阅读项目根目录下的所有 .md 文件，尤其是 CLAUDE.md、PRD.md、ARCHITECTURE.md、DATA_SOURCES.md、DESIGN.md、ROADMAP.md 和 docs/CHART.md。这些文件定义了产品的完整上下文、技术架构、数据接口、UI/UX 和开发顺序。

核心要求：
1. 纯 iOS 本地架构，不需要后端。数据通过公开接口直接抓取：新浪财经（行情/K线）、东方财富（龙虎榜/板块/F10/新闻）、腾讯财经（备用行情）。
2. SwiftUI 开发，最低 iOS 17，支持 WidgetKit 小组件。
3. 本地数据存储使用 SwiftData。
4. 每天为用户精选 5 只 A股。推荐逻辑在本地完成：综合板块热度、龙虎榜资金、个股走势、消息链四个维度评分，取 Top 5。
5. 接入 LLM API（DeepSeek / Kimi / 通义千问）生成推荐理由。LLM API Key 由用户首次启动弹框配置，也可在设置页修改，存储在 Keychain。
6. 未配置 LLM API Key 时，推荐功能仍可展示基于规则的评分结果，但缺少 LLM 分析文本。
7. 推荐策略：用户打开 App 时，先展示本地缓存的旧推荐，后台异步生成新推荐。历史推荐保存到本地总表，每只股票显示从推荐日至今的涨跌幅。
8. 推荐候选池过滤：排除退市股、ST 股、科创板（688 开头）、北交所（8/4 开头）、停牌股。
9. K线图使用 Swift Charts 原生实现，支持日/周/月切换。
10. 自选股每 5 分钟刷新一次行情。
11. 全程优先保证主流程可用，公开接口抓取失败时优雅降级，不崩溃。

请按以下顺序实现 MVP：
1. 创建 Xcode 项目骨架（iOS 17+ SwiftUI App，包含 Widget Extension）。
2. 定义 SwiftData 模型（Stock, DailyPick, KLineData, F10Metric, WatchlistItem, HistoricalPick 等）。
3. 实现 DataService：封装新浪实时行情、新浪历史 K线、东方财富 K线、东方财富龙虎榜/板块/新闻接口。注意 JSONP/CSV 解析和错误处理。
4. 实现 PickEngine：四维度评分 + 过滤规则 + Top 5 排序。
5. 实现 LLMAnalyzer：调用 LLM API 生成推荐理由，未配置 Key 时降级为规则摘要。
6. 实现 LLM API Key 配置：启动弹框 + 设置页，Keychain 存储。
7. 实现 DailyPickView：每日推荐列表，先展示缓存、后台刷新、下拉刷新。
8. 实现 StockDetailView：股票信息、K线图（Swift Charts）、F10、入选理由。
9. 实现 WatchlistView：自选股管理 + 5 分钟定时刷新。
10. 实现 HistoricalPicksView：历史推荐总表，显示从推荐日至今的涨跌幅。
11. 实现 Widget：今日 Top 1 推荐。
12. 添加风险免责声明。

开发规范：
- 使用 async/await 处理异步。
- 数据模型用 Codable。
- ViewModel 使用 @Observable。
- 公开接口请求加间隔和重试，避免触发反爬。
- 在 Info.plist 中配置允许的 HTTP 域名。
- 不要在代码中硬编码 LLM API Key。

请从第 1 步开始，先搭建项目骨架并告诉我你的计划。每完成一个模块，简要说明并继续下一步。
```

---

## 使用方式

1. 打开终端，进入项目目录：
   ```bash
   cd /Users/yangzhuo/Bullnook
   ```

2. 启动 Claude Code（假设已安装）：
   ```bash
   claude
   ```

3. 在 Claude Code 中粘贴上面的完整提示词。

4. Claude Code 会自动读取所有 `.md` 文件并开始生成代码。

---

## 注意事项

- 如果 Claude Code 提示项目目录下已有文件，让它先读取再生成。
- 如果它跳过某些 `.md` 文件，提醒它必须阅读 `CLAUDE.md` 和 `PRD.md`。
- 如果它开始生成 Python 后端代码，提醒它：本项目是**纯本地 iOS 架构**，没有后端。
- 如果它建议替换 Swift Charts 为第三方库，提醒它：MVP 优先使用 Swift Charts，简单即可。
