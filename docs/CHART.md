Bullnook App 的 K 线图实现使用 **Swift Charts**（iOS 16+ 原生框架）。

---

## 选择 Swift Charts 的原因

- iOS 原生支持，无需引入第三方库
- 与 SwiftUI 无缝集成
- 支持 `Chart` + `RectangleMark` / `RuleMark` 组合画蜡烛图
- 支持时间轴缩放、选择、手势
- 维护成本低，随系统升级自动获得优化

---

## 图表类型

### 1. K 线图（蜡烛图）

使用 `RectangleMark` 表示每根 K 线：
- 实体：开盘 → 收盘
- 上影线：最高
- 下影线：最低
- 颜色：涨为深绿色，跌为深红色，平盘为灰色

### 2. 成交量图

K 线图底部叠加成交量：
- 使用 `BarMark`
- 颜色与 K 线颜色一致

### 3. 均线（MA5 / MA10 / MA20）

使用 `LineMark` 叠加：
- MA5：黄色
- MA10：橙色
- MA20：紫色

---

## 交互

- 切换周期：日线 / 周线 / 月线
- 手势缩放：捏合放大/缩小时间范围
- 长按显示十字光标：显示当前日期、开收高低、成交量
- 默认展示最近 60 根 K 线，最大可加载 250 根

---

## 数据格式

```swift
struct KLineData: Identifiable, Codable {
    let id: String
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    let changePercent: Double
}
```

---

## 示例代码结构

```swift
import SwiftUI
import Charts

struct KLineChart: View {
    let data: [KLineData]
    let period: KLinePeriod

    var body: some View {
        Chart(data) { item in
            // 上影线
            RuleMark(
                x: .value("Date", item.date),
                yStart: .value("Low", item.low),
                yEnd: .value("High", item.high)
            )
            .foregroundStyle(color(for: item))

            // 实体
            RectangleMark(
                x: .value("Date", item.date),
                yStart: .value("Open", item.open),
                yEnd: .value("Close", item.close),
                width: .fixed(6)
            )
            .foregroundStyle(color(for: item))
        }
    }

    func color(for item: KLineData) -> Color {
        item.close >= item.open ? .up : .down
    }
}
```

---

## 备选方案

如果 Swift Charts 在复杂交互或性能上不满足需求，可考虑：

- **SwiftUI Canvas 自定义绘制**：完全可控，但开发成本高
- **TradingView Lightweight Charts**：成熟但需引入 WebView，依赖 JS
- **AAInfographics**：基于 Highcharts，也是 WebView 方案

MVP 阶段优先使用 Swift Charts，后续根据性能和交互需求再评估。
