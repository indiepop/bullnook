# Bullnook

> A股选股 App，每天只推荐 5 只股票。

中文名：牛角尖  
英文名：Bullnook  
平台：iOS（SwiftUI + WidgetKit）  
数据与计算：iOS 端本地完成（新浪/东方财富/腾讯公开接口 + 本地评分 + LLM API）  

---

## 核心特点

- 每天为用户精选 5 只 A股（首次打开时生成）
- 综合板块热度、龙虎榜资金、个股走势、消息链四维分析
- 接入 LLM 生成可读的推荐理由
- 个股详情支持 K线图（日/周/月）、F10 财务指标、入选理由拆解
- 自选股管理，每 5 分钟刷新行情
- 小组件显示今日 Top 1 推荐

---

## 项目结构

```
Bullnook/
├── Bullnook/          # iOS App (SwiftUI)
│   ├── Models/        # SwiftData 模型
│   ├── Views/         # SwiftUI 页面
│   ├── Services/      # DataService / PickEngine / LLMAnalyzer / 缓存
│   └── Widget/        # WidgetKit 小组件
├── docs/              # 产品/技术文档
├── CLAUDE.md          # 给 Claude Code 的项目上下文
└── README.md
```

---

## 文档

- [PRD.md](PRD.md) — 产品需求文档
- [ARCHITECTURE.md](ARCHITECTURE.md) — 系统架构
- [DATA_SOURCES.md](DATA_SOURCES.md) — 数据源说明
- [DESIGN.md](DESIGN.md) — UI/UX 设计
- [ROADMAP.md](ROADMAP.md) — 迭代路线图
- [CHART.md](docs/CHART.md) — K线图实现方案（Swift Charts）

---

## 快速开始

### 环境要求

- macOS 15+
- Xcode 16+
- iOS 17+ 模拟器或真机
- LLM API Key（DeepSeek / Kimi / 通义千问）

### 配置

1. 在 `Bullnook/Services/Config.swift` 中配置你的 LLM API Key
2. 在 `Info.plist` 中允许访问公开接口的 HTTP 域名（如 `hq.sinajs.cn`、`push2.eastmoney.com`）
3. 打开 Xcode 工程，运行到模拟器或真机

### 运行

```bash
cd Bullnook
open Bullnook.xcodeproj
```

---

## 免责声明

本应用所有推荐和分析仅供参考，不构成投资建议。股市有风险，投资需谨慎。
