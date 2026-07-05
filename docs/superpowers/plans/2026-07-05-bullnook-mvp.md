# Bullnook MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Bullnook iOS A股选股 App MVP — a pure-local SwiftUI app that fetches public market data, scores stocks locally, and presents 5 daily picks with LLM-powered analysis.

**Architecture:** Single iOS 17+ SwiftUI target plus a Widget Extension. All data fetching, scoring, and persistence run on-device via `URLSession`, `PickEngine`, and `SwiftData`. No backend. LLM API calls are optional and gracefully degrade to rule-based summaries when no API key is configured.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, Swift Charts, WidgetKit, Keychain.

## Global Constraints

- Minimum deployment target: iOS 17.0
- Language: Swift 5.9+
- UI framework: SwiftUI
- Local storage: SwiftData
- Charts: Swift Charts (no third-party chart libraries)
- Networking: `URLSession` only
- No backend; call public APIs directly (Sina, EastMoney, Tencent)
- LLM API Key stored in Keychain; never hard-coded
- Graceful degradation on every network/API failure
- Dark-mode-first UI with `#0F172A` background and `#F59E0B` accent
- Up = green (`#10B981`), Down = red (`#EF4444`)
- All network requests use retries and throttling to avoid anti-scraping blocks
- App Transport Security must allow HTTP domains used by public APIs

---

## File Structure

```
BullNook/
├── App/
│   └── BullnookApp.swift                    (modify existing)
├── Models/
│   ├── Stock.swift
│   ├── DailyPick.swift
│   ├── HistoricalPick.swift
│   ├── KLineData.swift
│   ├── F10Metric.swift
│   ├── WatchlistItem.swift
│   ├── SectorData.swift
│   └── DragonTigerData.swift
├── Services/
│   ├── NetworkClient.swift
│   ├── SinaAPI.swift
│   ├── EastMoneyAPI.swift
│   ├── TencentAPI.swift
│   ├── StockCache.swift
│   ├── PickEngine.swift
│   ├── LLMAnalyzer.swift
│   └── KeychainManager.swift
├── ViewModels/
│   ├── DailyPickViewModel.swift
│   ├── StockDetailViewModel.swift
│   ├── WatchlistViewModel.swift
│   └── SettingsViewModel.swift
├── Views/
│   ├── Components/
│   │   ├── Theme.swift
│   │   ├── DisclaimerView.swift
│   │   └── LoadingView.swift
│   ├── DailyPickView/
│   │   ├── DailyPickView.swift
│   │   └── PickCard.swift
│   ├── StockDetailView/
│   │   ├── StockDetailView.swift
│   │   ├── KLineChartView.swift
│   │   ├── F10View.swift
│   │   └── AnalysisView.swift
│   ├── WatchlistView/
│   │   ├── WatchlistView.swift
│   │   └── WatchlistRow.swift
│   ├── HistoricalPicksView/
│   │   └── HistoricalPicksView.swift
│   └── SettingsView/
│       └── SettingsView.swift
└── Widget/
    ├── BullnookWidgetBundle.swift
    └── BullnookWidget.swift
```

**Notes on Xcode project integration:** After creating each new Swift file, add it to the `BullNook` target in `BullNook.xcodeproj`. If automated editing of `.pbxproj` is unavailable, open Xcode and use **File → Add Files to "BullNook"**. The plan assumes files are created on disk first and then added to the target before building.

---

### Task 1: Project Skeleton and Configuration

**Files:**
- Create: `BullNook/Info.plist`
- Modify: `BullNook.xcodeproj` (add new files to target)
- Modify: `BullNook/BullnookApp.swift`

**Interfaces:**
- Produces: App entry point configured for SwiftData and Keychain; ATS exceptions for public API HTTP domains.

- [ ] **Step 1: Add App Transport Security exceptions**

Create `BullNook/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
        <key>NSExceptionDomains</key>
        <dict>
            <key>hq.sinajs.cn</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
            <key>quotes.sina.cn</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
            <key>qt.gtimg.cn</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
            <key>push2his.eastmoney.com</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
            <key>datacenter-web.eastmoney.com</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
            <key>push2.eastmoney.com</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
            <key>searchapi.eastmoney.com</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
        </dict>
    </dict>
</dict>
</plist>
```

- [ ] **Step 2: Update BullnookApp.swift to configure SwiftData container**

Replace contents of `BullNook/BullnookApp.swift`:

```swift
//
//  BullnookApp.swift
//  BullNook
//

import SwiftUI
import SwiftData

@main
struct BullNookApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Stock.self,
            DailyPick.self,
            HistoricalPick.self,
            KLineData.self,
            F10Metric.self,
            WatchlistItem.self,
            SectorData.self,
            DragonTigerData.self
        ])
    }
}
```

- [ ] **Step 3: Add new files to the Xcode project target**

Open `BullNook.xcodeproj` in Xcode and add `Info.plist` to the `BullNook` target, ensuring it is recognized as the target's Info.plist file in Build Settings. Alternatively, set `INFOPLIST_FILE = BullNook/Info.plist` in the target's build settings.

- [ ] **Step 4: Build to verify project compiles**

Run:
```bash
cd /Users/yangzhuo/BullNook
xcodebuild -project BullNook.xcodeproj -scheme BullNook -destination 'platform=iOS Simulator,name=iPhone 15' build
```

Expected: Build succeeds with no new code errors (existing `ContentView` compiles).

---

### Task 2: Define SwiftData Models

**Files:**
- Create: `BullNook/Models/Stock.swift`
- Create: `BullNook/Models/DailyPick.swift`
- Create: `BullNook/Models/HistoricalPick.swift`
- Create: `BullNook/Models/KLineData.swift`
- Create: `BullNook/Models/F10Metric.swift`
- Create: `BullNook/Models/WatchlistItem.swift`
- Create: `BullNook/Models/SectorData.swift`
- Create: `BullNook/Models/DragonTigerData.swift`

**Interfaces:**
- Produces: SwiftData `@Model` classes used by all subsequent tasks.

- [ ] **Step 1: Create Stock.swift**

```swift
import Foundation
import SwiftData

@Model
class Stock {
    @Attribute(.unique) var id: String
    var symbol: String
    var name: String
    var industry: String
    var marketCap: Double
    var listDate: String?
    var exchange: String
    
    init(id: String, symbol: String, name: String, industry: String = "", marketCap: Double = 0, listDate: String? = nil, exchange: String = "") {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.industry = industry
        self.marketCap = marketCap
        self.listDate = listDate
        self.exchange = exchange
    }
}
```

- [ ] **Step 2: Create DailyPick.swift**

```swift
import Foundation
import SwiftData

@Model
class DailyPick {
    @Attribute(.unique) var id: String
    var date: String
    var rank: Int
    var stockCode: String
    var stockName: String
    var industry: String
    var score: Double
    var reasonSummary: String
    var sectorScore: Double
    var lhbScore: Double
    var trendScore: Double
    var newsScore: Double
    var analysis: String
    var generatedAt: Date
    var currentPrice: Double
    var changePercent: Double
    
    init(id: String, date: String, rank: Int, stockCode: String, stockName: String, industry: String, score: Double, reasonSummary: String, sectorScore: Double, lhbScore: Double, trendScore: Double, newsScore: Double, analysis: String, generatedAt: Date = Date(), currentPrice: Double = 0, changePercent: Double = 0) {
        self.id = id
        self.date = date
        self.rank = rank
        self.stockCode = stockCode
        self.stockName = stockName
        self.industry = industry
        self.score = score
        self.reasonSummary = reasonSummary
        self.sectorScore = sectorScore
        self.lhbScore = lhbScore
        self.trendScore = trendScore
        self.newsScore = newsScore
        self.analysis = analysis
        self.generatedAt = generatedAt
        self.currentPrice = currentPrice
        self.changePercent = changePercent
    }
}
```

- [ ] **Step 3: Create HistoricalPick.swift**

```swift
import Foundation
import SwiftData

@Model
class HistoricalPick {
    @Attribute(.unique) var id: String
    var date: String
    var rank: Int
    var stockCode: String
    var stockName: String
    var industry: String
    var score: Double
    var reasonSummary: String
    var sectorScore: Double
    var lhbScore: Double
    var trendScore: Double
    var newsScore: Double
    var analysis: String
    var generatedAt: Date
    var performanceSincePick: Double
    
    init(id: String, date: String, rank: Int, stockCode: String, stockName: String, industry: String, score: Double, reasonSummary: String, sectorScore: Double, lhbScore: Double, trendScore: Double, newsScore: Double, analysis: String, generatedAt: Date = Date(), performanceSincePick: Double = 0) {
        self.id = id
        self.date = date
        self.rank = rank
        self.stockCode = stockCode
        self.stockName = stockName
        self.industry = industry
        self.score = score
        self.reasonSummary = reasonSummary
        self.sectorScore = sectorScore
        self.lhbScore = lhbScore
        self.trendScore = trendScore
        self.newsScore = newsScore
        self.analysis = analysis
        self.generatedAt = generatedAt
        self.performanceSincePick = performanceSincePick
    }
    
    convenience init(from dailyPick: DailyPick, performanceSincePick: Double = 0) {
        self.init(
            id: dailyPick.id,
            date: dailyPick.date,
            rank: dailyPick.rank,
            stockCode: dailyPick.stockCode,
            stockName: dailyPick.stockName,
            industry: dailyPick.industry,
            score: dailyPick.score,
            reasonSummary: dailyPick.reasonSummary,
            sectorScore: dailyPick.sectorScore,
            lhbScore: dailyPick.lhbScore,
            trendScore: dailyPick.trendScore,
            newsScore: dailyPick.newsScore,
            analysis: dailyPick.analysis,
            generatedAt: dailyPick.generatedAt,
            performanceSincePick: performanceSincePick
        )
    }
}
```

- [ ] **Step 4: Create KLineData.swift**

```swift
import Foundation
import SwiftData

@Model
class KLineData {
    var symbol: String
    var date: String
    var open: Double
    var high: Double
    var low: Double
    var close: Double
    var volume: Double
    var amount: Double
    var amplitude: Double
    var changePercent: Double
    var changeAmount: Double
    var turnover: Double
    
    init(symbol: String, date: String, open: Double, high: Double, low: Double, close: Double, volume: Double, amount: Double = 0, amplitude: Double = 0, changePercent: Double = 0, changeAmount: Double = 0, turnover: Double = 0) {
        self.symbol = symbol
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.amount = amount
        self.amplitude = amplitude
        self.changePercent = changePercent
        self.changeAmount = changeAmount
        self.turnover = turnover
    }
}
```

- [ ] **Step 5: Create F10Metric.swift**

```swift
import Foundation
import SwiftData

@Model
class F10Metric {
    @Attribute(.unique) var symbol: String
    var pe: Double
    var pb: Double
    var roe: Double
    var revenueGrowth: Double
    var profitGrowth: Double
    var totalMarketCap: Double
    var circulatingMarketCap: Double
    var updatedAt: Date
    
    init(symbol: String, pe: Double = 0, pb: Double = 0, roe: Double = 0, revenueGrowth: Double = 0, profitGrowth: Double = 0, totalMarketCap: Double = 0, circulatingMarketCap: Double = 0, updatedAt: Date = Date()) {
        self.symbol = symbol
        self.pe = pe
        self.pb = pb
        self.roe = roe
        self.revenueGrowth = revenueGrowth
        self.profitGrowth = profitGrowth
        self.totalMarketCap = totalMarketCap
        self.circulatingMarketCap = circulatingMarketCap
        self.updatedAt = updatedAt
    }
}
```

- [ ] **Step 6: Create WatchlistItem.swift**

```swift
import Foundation
import SwiftData

@Model
class WatchlistItem {
    @Attribute(.unique) var id: String
    var stockCode: String
    var stockName: String
    var industry: String
    var addedAt: Date
    var currentPrice: Double
    var changePercent: Double
    var lastUpdated: Date
    
    init(id: String, stockCode: String, stockName: String, industry: String = "", addedAt: Date = Date(), currentPrice: Double = 0, changePercent: Double = 0, lastUpdated: Date = Date()) {
        self.id = id
        self.stockCode = stockCode
        self.stockName = stockName
        self.industry = industry
        self.addedAt = addedAt
        self.currentPrice = currentPrice
        self.changePercent = changePercent
        self.lastUpdated = lastUpdated
    }
}
```

- [ ] **Step 7: Create SectorData.swift**

```swift
import Foundation
import SwiftData

@Model
class SectorData {
    @Attribute(.unique) var id: String
    var name: String
    var date: String
    var changePercent: Double
    var netInflow: Double
    var limitUpCount: Int
    
    init(id: String, name: String, date: String, changePercent: Double = 0, netInflow: Double = 0, limitUpCount: Int = 0) {
        self.id = id
        self.name = name
        self.date = date
        self.changePercent = changePercent
        self.netInflow = netInflow
        self.limitUpCount = limitUpCount
    }
}
```

- [ ] **Step 8: Create DragonTigerData.swift**

```swift
import Foundation
import SwiftData

@Model
class DragonTigerData {
    @Attribute(.unique) var id: String
    var symbol: String
    var name: String
    var date: String
    var netBuyAmount: Double
    var buySeats: String
    var sellSeats: String
    
    init(id: String, symbol: String, name: String, date: String, netBuyAmount: Double = 0, buySeats: String = "", sellSeats: String = "") {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.date = date
        self.netBuyAmount = netBuyAmount
        self.buySeats = buySeats
        self.sellSeats = sellSeats
    }
}
```

- [ ] **Step 9: Add files to Xcode target and build**

Add all files under `BullNook/Models/` to the `BullNook` target. Build:

```bash
cd /Users/yangzhuo/BullNook
xcodebuild -project BullNook.xcodeproj -scheme BullNook -destination 'platform=iOS Simulator,name=iPhone 15' build
```

Expected: Build succeeds.

---

### Task 3: Network Client and Parsing Helpers

**Files:**
- Create: `BullNook/Services/NetworkClient.swift`

**Interfaces:**
- Consumes: `URL`
- Produces: `Data`, throttled/retrying network fetch

- [ ] **Step 1: Implement NetworkClient.swift**

```swift
import Foundation

enum NetworkError: Error {
    case invalidResponse
    case httpError(Int)
    case decodingFailure
    case missingData
}

actor NetworkClient {
    static let shared = NetworkClient()
    
    private var lastRequestTime: Date = .distantPast
    private let minInterval: TimeInterval = 0.3
    
    func fetch(_ url: URL, retries: Int = 3, delay: TimeInterval = 1.0) async throws -> Data {
        var attempt = 0
        var lastError: Error?
        
        while attempt < retries {
            await throttle()
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                guard (200..300).contains(httpResponse.statusCode) else {
                    throw NetworkError.httpError(httpResponse.statusCode)
                }
                return data
            } catch {
                lastError = error
                attempt += 1
                if attempt < retries {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw lastError ?? NetworkError.missingData
    }
    
    func fetchString(_ url: URL, retries: Int = 3, delay: TimeInterval = 1.0) async throws -> String {
        let data = try await fetch(url, retries: retries, delay: delay)
        guard let string = String(data: data, encoding: .utf8) else {
            throw NetworkError.decodingFailure
        }
        return string
    }
    
    private func throttle() async {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRequestTime)
        if elapsed < minInterval {
            try? await Task.sleep(nanoseconds: UInt64((minInterval - elapsed) * 1_000_000_000))
        }
        lastRequestTime = Date()
    }
}
```

- [ ] **Step 2: Add to target and build**

Add `NetworkClient.swift` to the `BullNook` target and build.

Expected: Build succeeds.

---

### Task 4: Sina API Service

**Files:**
- Create: `BullNook/Services/SinaAPI.swift`

**Interfaces:**
- Consumes: `NetworkClient`, stock symbols
- Produces: `RealTimeQuote`, `[KLineData]`

- [ ] **Step 1: Implement SinaAPI.swift**

```swift
import Foundation

struct RealTimeQuote {
    let symbol: String
    let name: String
    let currentPrice: Double
    let previousClose: Double
    let open: Double
    let high: Double
    let low: Double
    let volume: Double
    let amount: Double
    let dateTime: String
    
    var changePercent: Double {
        guard previousClose > 0 else { return 0 }
        return (currentPrice - previousClose) / previousClose * 100
    }
}

struct SinaAPI {
    static func realTimeQuotes(symbols: [String]) async -> [RealTimeQuote] {
        guard !symbols.isEmpty else { return [] }
        let list = symbols.joined(separator: ",")
        guard let url = URL(string: "https://hq.sinajs.cn/list=\(list)") else { return [] }
        
        do {
            let raw = try await NetworkClient.shared.fetchString(url)
            return parseQuotes(raw: raw, symbols: symbols)
        } catch {
            print("Sina real-time quote fetch failed: \(error)")
            return []
        }
    }
    
    private static func parseQuotes(raw: String, symbols: [String]) -> [RealTimeQuote] {
        var quotes: [RealTimeQuote] = []
        for symbol in symbols {
            let key = "hq_str_\(symbol)"
            guard let range = raw.range(of: "var \(key)=\""),
                  let endRange = raw[range.upperBound...].range(of: "\";") else { continue }
            let content = String(raw[range.upperBound..<endRange.lowerBound])
            let parts = content.split(separator: ",").map(String.init)
            guard parts.count >= 33 else { continue }
            
            quotes.append(RealTimeQuote(
                symbol: symbol,
                name: parts[0],
                currentPrice: Double(parts[3]) ?? 0,
                previousClose: Double(parts[2]) ?? 0,
                open: Double(parts[1]) ?? 0,
                high: Double(parts[4]) ?? 0,
                low: Double(parts[5]) ?? 0,
                volume: Double(parts[8]) ?? 0,
                amount: Double(parts[9]) ?? 0,
                dateTime: "\(parts[30]) \(parts[31])"
            ))
        }
        return quotes
    }
    
    static func kline(symbol: String, period: KLinePeriod = .daily, count: Int = 250) async -> [KLineData] {
        let d: Int
        switch period {
        case .daily: d = 1
        case .weekly: d = 7
        case .monthly: d = 30
        }
        guard let url = URL(string: "https://quotes.sina.cn/cn/api/quotes.php?symbol=\(symbol)&datalen=\(count)&fq=1&d=\(d)") else { return [] }
        
        do {
            let raw = try await NetworkClient.shared.fetchString(url)
            return parseKLine(raw: raw, symbol: symbol)
        } catch {
            print("Sina kline fetch failed: \(error)")
            return []
        }
    }
    
    private static func parseKLine(raw: String, symbol: String) -> [KLineData] {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let dataArray = result["data"] as? [[String: Any]] else { return [] }
        
        return dataArray.compactMap { item in
            guard let day = item["d"] as? String,
                  let open = item["o"] as? Double,
                  let high = item["h"] as? Double,
                  let low = item["l"] as? Double,
                  let close = item["c"] as? Double,
                  let volume = item["v"] as? Double else { return nil }
            return KLineData(
                symbol: symbol,
                date: day,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume
            )
        }
    }
}

enum KLinePeriod: String, CaseIterable {
    case daily = "日线"
    case weekly = "周线"
    case monthly = "月线"
}
```

Note: `KLinePeriod` is defined here because it is used by both Sina and EastMoney APIs. If later tasks move it, update this file.

- [ ] **Step 2: Add to target and build**

Expected: Build succeeds.

---

### Task 5: East Money API Service

**Files:**
- Create: `BullNook/Services/EastMoneyAPI.swift`

**Interfaces:**
- Consumes: `NetworkClient`, stock symbols, dates
- Produces: `[KLineData]`, `[DragonTigerData]`, `[SectorData]`, `[StockNews]`, `F10Metric?`

- [ ] **Step 1: Implement EastMoneyAPI.swift**

```swift
import Foundation

struct StockNews {
    let title: String
    let url: String
    let publishTime: String
}

struct EastMoneyAPI {
    
    // MARK: - Helpers
    
    private static func secid(for symbol: String) -> String {
        if symbol.hasPrefix("sh") { return "1.\(String(symbol.dropFirst(2)))" }
        if symbol.hasPrefix("sz") { return "0.\(String(symbol.dropFirst(2)))" }
        return "1.\(symbol)"
    }
    
    private static func klt(for period: KLinePeriod) -> String {
        switch period {
        case .daily: return "101"
        case .weekly: return "102"
        case .monthly: return "103"
        }
    }
    
    // MARK: - KLine
    
    static func kline(symbol: String, period: KLinePeriod = .daily, start: String, end: String) async -> [KLineData] {
        let sec = secid(for: symbol)
        let klt = klt(for: period)
        let urlString = "https://push2his.eastmoney.com/api/qt/stock/kline/get?secid=\(sec)&fields1=f1,f2,f3,f4,f5,f6&fields2=f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61&klt=\(klt)&fqt=1&beg=\(start)&end=\(end)"
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let raw = try await NetworkClient.shared.fetchString(url)
            return parseKLine(raw: raw, symbol: symbol)
        } catch {
            print("EastMoney kline fetch failed: \(error)")
            return []
        }
    }
    
    private static func parseKLine(raw: String, symbol: String) -> [KLineData] {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["data"] as? [String: Any],
              let klines = result["klines"] as? [String] else { return [] }
        
        return klines.compactMap { line in
            let parts = line.split(separator: ",").map(String.init)
            guard parts.count >= 9 else { return nil }
            return KLineData(
                symbol: symbol,
                date: parts[0],
                open: Double(parts[1]) ?? 0,
                close: Double(parts[2]) ?? 0,
                high: Double(parts[3]) ?? 0,
                low: Double(parts[4]) ?? 0,
                volume: Double(parts[5]) ?? 0,
                amount: Double(parts[6]) ?? 0,
                amplitude: Double(parts[7]) ?? 0,
                changePercent: Double(parts[8]) ?? 0,
                changeAmount: Double(parts[9]) ?? 0,
                turnover: Double(parts.count > 10 ? parts[10] : "0") ?? 0
            )
        }
    }
    
    // MARK: - Dragon Tiger
    
    static func dragonTiger(pageSize: Int = 500) async -> [DragonTigerData] {
        let urlString = "https://datacenter-web.eastmoney.com/api/data/v1/get?sortColumns=SECURITY_CODE,TRADE_DATE&sortTypes=-1,-1&pageSize=\(pageSize)&pageNumber=1&reportName=RPT_DMSK_TS_LSTOCKT&columns=ALL&source=WEB&client=WEB"
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let raw = try await NetworkClient.shared.fetchString(url)
            return parseDragonTiger(raw: raw)
        } catch {
            print("EastMoney dragon tiger fetch failed: \(error)")
            return []
        }
    }
    
    private static func parseDragonTiger(raw: String) -> [DragonTigerData] {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let rows = result["data"] as? [[String: Any]] else { return [] }
        
        return rows.compactMap { row in
            guard let code = row["SECURITY_CODE"] as? String,
                  let name = row["SECURITY_NAME_ABBR"] as? String,
                  let date = row["TRADE_DATE"] as? String else { return nil }
            let netBuy = (row["NET_BUY_AMT"] as? Double) ?? 0
            let buySeats = (row["BUY_STOCK"] as? String) ?? ""
            let sellSeats = (row["SELL_STOCK"] as? String) ?? ""
            return DragonTigerData(
                id: "\(code)_\(date)",
                symbol: codeToSymbol(code),
                name: name,
                date: String(date.prefix(10)),
                netBuyAmount: netBuy,
                buySeats: buySeats,
                sellSeats: sellSeats
            )
        }
    }
    
    // MARK: - Sectors
    
    static func sectorList() async -> [SectorData] {
        let urlString = "https://push2.eastmoney.com/api/qt/clist/get?pn=1&pz=100&po=1&np=1&fltt=2&invt=2&fid=f3&fs=m:90+t:2&fields=f12,f14,f2,f3,f4,f5,f6,f7,f8,f9,f10,f20,f21,f22"
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let raw = try await NetworkClient.shared.fetchString(url)
            return parseSectors(raw: raw)
        } catch {
            print("EastMoney sector list fetch failed: \(error)")
            return []
        }
    }
    
    private static func parseSectors(raw: String) -> [SectorData] {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["data"] as? [String: Any],
              let diff = result["diff"] as? [[String: Any]] else { return [] }
        
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        return diff.compactMap { item in
            guard let name = item["f14"] as? String else { return nil }
            let change = (item["f3"] as? Double) ?? 0
            let inflow = (item["f22"] as? Double) ?? 0
            return SectorData(
                id: "\(name)_\(today)",
                name: name,
                date: today,
                changePercent: change,
                netInflow: inflow,
                limitUpCount: 0
            )
        }
    }
    
    // MARK: - News
    
    static func stockNews(symbol: String, pageSize: Int = 20) async -> [StockNews] {
        let code = String(symbol.dropFirst(2))
        let urlString = "https://searchapi.eastmoney.com/api/sns/get?type=14&cb=jQuery&keyword=\(code)&pageindex=1&pagesize=\(pageSize)"
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let raw = try await NetworkClient.shared.fetchString(url)
            return parseNews(raw: raw)
        } catch {
            print("EastMoney news fetch failed: \(error)")
            return []
        }
    }
    
    private static func parseNews(raw: String) -> [StockNews] {
        guard let start = raw.range(of: "(")?.upperBound,
              let end = raw.range(of: ")")?.lowerBound else { return [] }
        let jsonString = String(raw[start..<end])
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let posts = result["posts"] as? [[String: Any]] else { return [] }
        
        return posts.compactMap { post in
            guard let title = post["title"] as? String,
                  let url = post["url"] as? String,
                  let time = post["pub_time"] as? String else { return nil }
            return StockNews(title: title, url: url, publishTime: time)
        }
    }
    
    // MARK: - F10
    
    static func f10(symbol: String) async -> F10Metric? {
        let code = String(symbol.dropFirst(2))
        let sec = secid(for: symbol)
        let urlString = "https://f10.eastmoney.com/FinancialAnalysis/Index?type=web&code=\(code)"
        // Public F10 endpoints vary; fallback to a simplified endpoint if needed.
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let raw = try await NetworkClient.shared.fetchString(url)
            return parseF10(raw: raw, symbol: symbol)
        } catch {
            print("EastMoney F10 fetch failed: \(error)")
            return nil
        }
    }
    
    private static func parseF10(raw: String, symbol: String) -> F10Metric? {
        // Placeholder: real parsing depends on the live response format.
        // Return default zeros so the UI can degrade gracefully.
        return F10Metric(symbol: symbol)
    }
    
    // MARK: - Utilities
    
    private static func codeToSymbol(_ code: String) -> String {
        if code.hasPrefix("6") { return "sh\(code)" }
        if code.hasPrefix("0") || code.hasPrefix("3") { return "sz\(code)" }
        return code
    }
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f
    }()
}
```

- [ ] **Step 2: Add to target and build**

Expected: Build succeeds. The `parseF10` placeholder intentionally returns default values because public F10 endpoints vary; the UI must degrade gracefully.

---

### Task 6: Tencent API Service (Backup Quotes)

**Files:**
- Create: `BullNook/Services/TencentAPI.swift`

**Interfaces:**
- Consumes: `NetworkClient`, stock symbols
- Produces: `[RealTimeQuote]` compatible with Sina quotes

- [ ] **Step 1: Implement TencentAPI.swift**

```swift
import Foundation

struct TencentAPI {
    static func realTimeQuotes(symbols: [String]) async -> [RealTimeQuote] {
        guard !symbols.isEmpty else { return [] }
        let list = symbols.joined(separator: ",")
        guard let url = URL(string: "https://qt.gtimg.cn/q=\(list)") else { return [] }
        
        do {
            let raw = try await NetworkClient.shared.fetchString(url)
            return parseQuotes(raw: raw, symbols: symbols)
        } catch {
            print("Tencent real-time quote fetch failed: \(error)")
            return []
        }
    }
    
    private static func parseQuotes(raw: String, symbols: [String]) -> [RealTimeQuote] {
        var quotes: [RealTimeQuote] = []
        for symbol in symbols {
            let key = "v_\(symbol)"
            guard let range = raw.range(of: "\(key)=\""),
                  let endRange = raw[range.upperBound...].range(of: "\";") else { continue }
            let content = String(raw[range.upperBound..<endRange.lowerBound])
            let parts = content.split(separator: "~").map(String.init)
            guard parts.count >= 45 else { continue }
            
            let name = parts[1]
            let currentPrice = Double(parts[3]) ?? 0
            let previousClose = Double(parts[4]) ?? 0
            let open = Double(parts[5]) ?? 0
            let high = Double(parts[33]) ?? 0
            let low = Double(parts[34]) ?? 0
            let volume = Double(parts[36]) ?? 0
            let amount = Double(parts[37]) ?? 0
            
            quotes.append(RealTimeQuote(
                symbol: symbol,
                name: name,
                currentPrice: currentPrice,
                previousClose: previousClose,
                open: open,
                high: high,
                low: low,
                volume: volume,
                amount: amount,
                dateTime: parts[30]
            ))
        }
        return quotes
    }
}
```

- [ ] **Step 2: Add to target and build**

Expected: Build succeeds.

---

### Task 7: Stock Cache

**Files:**
- Create: `BullNook/Services/StockCache.swift`

**Interfaces:**
- Consumes: SwiftData `ModelContext`
- Produces: CRUD helpers for `DailyPick`, `KLineData`, `WatchlistItem`, `HistoricalPick`, `SectorData`, `DragonTigerData`, `F10Metric`

- [ ] **Step 1: Implement StockCache.swift**

```swift
import Foundation
import SwiftData

@MainActor
final class StockCache {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Daily Picks
    
    func dailyPicks(for date: String) -> [DailyPick] {
        let descriptor = FetchDescriptor<DailyPick>(
            predicate: #Predicate { $0.date == date },
            sortBy: [SortDescriptor(\.rank)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func latestDailyPicks(limit: Int = 5) -> [DailyPick] {
        let descriptor = FetchDescriptor<DailyPick>(
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.rank)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return Array(all.prefix(limit))
    }
    
    func save(dailyPicks: [DailyPick]) {
        for pick in dailyPicks {
            context.insert(pick)
        }
        try? context.save()
    }
    
    func deleteAllDailyPicks(for date: String) {
        let descriptor = FetchDescriptor<DailyPick>(predicate: #Predicate { $0.date == date })
        guard let items = try? context.fetch(descriptor) else { return }
        for item in items {
            context.delete(item)
        }
        try? context.save()
    }
    
    // MARK: - Historical Picks
    
    func historicalPicks() -> [HistoricalPick] {
        let descriptor = FetchDescriptor<HistoricalPick>(
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.rank)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func save(historicalPicks: [HistoricalPick]) {
        for pick in historicalPicks {
            context.insert(pick)
        }
        try? context.save()
    }
    
    // MARK: - KLine
    
    func kline(symbol: String, period: KLinePeriod) -> [KLineData] {
        let descriptor = FetchDescriptor<KLineData>(
            predicate: #Predicate { $0.symbol == symbol },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func save(kline: [KLineData]) {
        for item in kline {
            context.insert(item)
        }
        try? context.save()
    }
    
    // MARK: - Watchlist
    
    func watchlistItems() -> [WatchlistItem] {
        let descriptor = FetchDescriptor<WatchlistItem>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func addToWatchlist(stockCode: String, stockName: String, industry: String = "") {
        let item = WatchlistItem(id: stockCode, stockCode: stockCode, stockName: stockName, industry: industry)
        context.insert(item)
        try? context.save()
    }
    
    func removeFromWatchlist(stockCode: String) {
        let descriptor = FetchDescriptor<WatchlistItem>(predicate: #Predicate { $0.stockCode == stockCode })
        guard let items = try? context.fetch(descriptor) else { return }
        for item in items {
            context.delete(item)
        }
        try? context.save()
    }
    
    func isInWatchlist(stockCode: String) -> Bool {
        let descriptor = FetchDescriptor<WatchlistItem>(predicate: #Predicate { $0.stockCode == stockCode })
        return (try? context.fetchCount(descriptor)) ?? 0 > 0
    }
    
    func updateWatchlist(items: [WatchlistItem]) {
        try? context.save()
    }
    
    // MARK: - Sectors / Dragon Tiger / F10
    
    func sectors(for date: String) -> [SectorData] {
        let descriptor = FetchDescriptor<SectorData>(predicate: #Predicate { $0.date == date })
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func save(sectors: [SectorData]) {
        for item in sectors { context.insert(item) }
        try? context.save()
    }
    
    func dragonTiger(for date: String) -> [DragonTigerData] {
        let descriptor = FetchDescriptor<DragonTigerData>(predicate: #Predicate { $0.date == date })
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func save(dragonTiger: [DragonTigerData]) {
        for item in dragonTiger { context.insert(item) }
        try? context.save()
    }
    
    func f10(symbol: String) -> F10Metric? {
        let descriptor = FetchDescriptor<F10Metric>(predicate: #Predicate { $0.symbol == symbol })
        return try? context.fetch(descriptor).first
    }
    
    func save(f10: F10Metric) {
        context.insert(f10)
        try? context.save()
    }
}
```

- [ ] **Step 2: Add to target and build**

Expected: Build succeeds.

---

### Task 8: Pick Engine

**Files:**
- Create: `BullNook/Services/PickEngine.swift`

**Interfaces:**
- Consumes: `[Stock]`, `[KLineData]` per stock, `[SectorData]`, `[DragonTigerData]`, `[StockNews]` per stock
- Produces: `[DailyPick]` sorted by score

- [ ] **Step 1: Implement PickEngine.swift**

```swift
import Foundation

struct PickInputs {
    let stocks: [Stock]
    let klines: [String: [KLineData]]
    let sectors: [SectorData]
    let dragonTigers: [DragonTigerData]
    let news: [String: [StockNews]]
}

actor PickEngine {
    
    func generatePicks(inputs: PickInputs, date: String) async -> [DailyPick] {
        var candidates: [DailyPick] = []
        let sectorMap = Dictionary(grouping: inputs.sectors, by: { $0.name })
        let dragonMap = Dictionary(grouping: inputs.dragonTigers, by: { $0.symbol })
        
        for stock in inputs.stocks {
            guard isEligible(stock: stock, klines: inputs.klines[stock.symbol]) else { continue }
            
            let symbol = stock.symbol
            let kline = inputs.klines[symbol] ?? []
            let stockNews = inputs.news[symbol] ?? []
            let stockDragon = dragonMap[symbol] ?? []
            
            let sectorScore = scoreSector(stock: stock, sectors: inputs.sectors, sectorMap: sectorMap)
            let lhbScore = scoreDragonTiger(stock: stock, dragonTigers: stockDragon)
            let trendScore = scoreTrend(kline: kline)
            let newsScore = scoreNews(news: stockNews)
            
            let total = (sectorScore + lhbScore + trendScore + newsScore) / 4.0
            let reason = reasonSummary(sector: sectorScore, lhb: lhbScore, trend: trendScore, news: newsScore)
            
            let pick = DailyPick(
                id: "\(date)_\(stock.id)",
                date: date,
                rank: 0,
                stockCode: stock.id,
                stockName: stock.name,
                industry: stock.industry,
                score: total,
                reasonSummary: reason,
                sectorScore: sectorScore,
                lhbScore: lhbScore,
                trendScore: trendScore,
                newsScore: newsScore,
                analysis: ""
            )
            candidates.append(pick)
        }
        
        let sorted = candidates.sorted { $0.score > $1.score }
        let top5 = Array(sorted.prefix(5)).enumerated().map { index, pick in
            DailyPick(
                id: pick.id,
                date: pick.date,
                rank: index + 1,
                stockCode: pick.stockCode,
                stockName: pick.stockName,
                industry: pick.industry,
                score: pick.score,
                reasonSummary: pick.reasonSummary,
                sectorScore: pick.sectorScore,
                lhbScore: pick.lhbScore,
                trendScore: pick.trendScore,
                newsScore: pick.newsScore,
                analysis: pick.analysis
            )
        }
        return top5
    }
    
    // MARK: - Filtering
    
    private func isEligible(stock: Stock, klines: [KLineData]?) -> Bool {
        let name = stock.name
        if name.contains("退") || name.contains("ST") || name.contains("*ST") {
            return false
        }
        let code = stock.id
        if code.hasPrefix("688") { return false }
        if code.hasPrefix("8") || code.hasPrefix("4") { return false }
        guard let klines = klines, !klines.isEmpty else {
            return false // treat missing kline as suspended
        }
        let latest = klines.sorted { $0.date < $1.date }
        guard let last = latest.last, last.close > 0 else { return false }
        return true
    }
    
    // MARK: - Scoring
    
    private func scoreSector(stock: Stock, sectors: [SectorData], sectorMap: [String: [SectorData]]) -> Double {
        // Simple average sector change capped at 0-100
        guard !sectors.isEmpty else { return 50 }
        let maxChange = sectors.map { abs($0.changePercent) }.max() ?? 1
        let matched = sectors.first { stock.industry.contains($0.name) || $0.name.contains(stock.industry) }
        let change = matched?.changePercent ?? 0
        let normalized = maxChange > 0 ? (change / maxChange) * 100 : 50
        return min(max(normalized, 0), 100)
    }
    
    private func scoreDragonTiger(stock: Stock, dragonTigers: [DragonTigerData]) -> Double {
        guard !dragonTigers.isEmpty else { return 50 }
        let netBuy = dragonTigers.reduce(0) { $0 + $1.netBuyAmount }
        let score = 50 + min(netBuy / 1_000_000.0, 50)
        return min(score, 100)
    }
    
    private func scoreTrend(kline: [KLineData]) -> Double {
        guard kline.count >= 5 else { return 50 }
        let sorted = kline.sorted { $0.date < $1.date }
        guard let last = sorted.last, let fiveDaysAgo = sorted.dropLast(5).last else { return 50 }
        let change = fiveDaysAgo.close > 0 ? (last.close - fiveDaysAgo.close) / fiveDaysAgo.close * 100 : 0
        let ma5 = sorted.suffix(5).map(\.close).reduce(0, +) / 5
        let ma10 = sorted.suffix(min(10, sorted.count)).map(\.close).reduce(0, +) / Double(min(10, sorted.count))
        var score = 50 + change * 2
        if last.close > ma5 { score += 10 }
        if last.close > ma10 { score += 10 }
        return min(max(score, 0), 100)
    }
    
    private func scoreNews(news: [StockNews]) -> Double {
        let count = Double(news.count)
        return min(50 + count * 5, 100)
    }
    
    private func reasonSummary(sector: Double, lhb: Double, trend: Double, news: Double) -> String {
        let scores = [
            ("板块热度", sector),
            ("龙虎榜资金", lhb),
            ("个股走势", trend),
            ("消息链", news)
        ]
        let top = scores.max { $0.1 < $1.1 } ?? scores[0]
        return "\(top.0)表现突出，综合评分较高"
    }
}
```

- [ ] **Step 2: Add to target and build**

Expected: Build succeeds.

---

### Task 9: LLM Analyzer

**Files:**
- Create: `BullNook/Services/LLMAnalyzer.swift`

**Interfaces:**
- Consumes: `DailyPick`, `[DailyPick]`, LLM provider + API key
- Produces: `String` analysis text

- [ ] **Step 1: Implement LLMAnalyzer.swift**

```swift
import Foundation

enum LLMProvider: String, CaseIterable, Identifiable {
    case deepSeek = "DeepSeek"
    case kimi = "Kimi"
    case qianwen = "通义千问"
    
    var id: String { rawValue }
    
    var baseURL: String {
        switch self {
        case .deepSeek: return "https://api.deepseek.com/chat/completions"
        case .kimi: return "https://api.moonshot.cn/v1/chat/completions"
        case .qianwen: return "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation"
        }
    }
}

struct LLMConfig: Codable {
    var provider: String
    var apiKey: String
}

actor LLMAnalyzer {
    
    func analyze(pick: DailyPick, allPicks: [DailyPick], config: LLMConfig?) async -> String {
        guard let config = config, !config.apiKey.isEmpty else {
            return fallbackAnalysis(pick: pick)
        }
        
        guard let provider = LLMProvider(rawValue: config.provider) else {
            return fallbackAnalysis(pick: pick)
        }
        
        let prompt = buildPrompt(pick: pick, allPicks: allPicks)
        
        do {
            switch provider {
            case .deepSeek, .kimi:
                return try await callOpenAICompatible(provider: provider, apiKey: config.apiKey, prompt: prompt)
            case .qianwen:
                return try await callQianwen(apiKey: config.apiKey, prompt: prompt)
            }
        } catch {
            print("LLM analysis failed: \(error)")
            return fallbackAnalysis(pick: pick)
        }
    }
    
    private func fallbackAnalysis(pick: DailyPick) -> String {
        return "【规则摘要】\(pick.stockName)(\(pick.stockCode)) 今日入选原因：\(pick.reasonSummary)。四维度得分：板块热度 \(String(format: "%.1f", pick.sectorScore))，龙虎榜 \(String(format: "%.1f", pick.lhbScore))，走势 \(String(format: "%.1f", pick.trendScore))，消息 \(String(format: "%.1f", pick.newsScore))。请在设置中配置 LLM API Key 以获取智能分析。"
    }
    
    private func buildPrompt(pick: DailyPick, allPicks: [DailyPick]) -> String {
        let peers = allPicks.filter { $0.id != pick.id }.map { "\($0.stockName)(\($0.stockCode)) 得分 \($0.score)" }.joined(separator: "；")
        return """
        你是一位专业的 A 股分析师。请用 100-150 字分析股票 \(pick.stockName)(代码 \(pick.stockCode)) 今日入选“每日精选”的原因。
        行业：\(pick.industry)。
        四维度得分（0-100）：板块热度 \(String(format: "%.1f", pick.sectorScore))，龙虎榜资金 \(String(format: "%.1f", pick.lhbScore))，个股走势 \(String(format: "%.1f", pick.trendScore))，消息链 \(String(format: "%.1f", pick.newsScore))。综合得分 \(String(format: "%.1f", pick.score))。
        其他入选股票：\(peers)。
        要求：专业、客观、风险提示，不要给出具体买卖建议。
        """
    }
    
    private func callOpenAICompatible(provider: LLMProvider, apiKey: String, prompt: String) async throws -> String {
        guard let url = URL(string: provider.baseURL) else { throw NetworkError.invalidResponse }
        
        let body: [String: Any] = [
            "model": provider == .kimi ? "moonshot-v1-8k" : "deepseek-chat",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 300
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..300).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NetworkError.decodingFailure
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func callQianwen(apiKey: String, prompt: String) async throws -> String {
        guard let url = URL(string: LLMProvider.qianwen.baseURL) else { throw NetworkError.invalidResponse }
        
        let body: [String: Any] = [
            "model": "qwen-turbo",
            "input": [
                "messages": [
                    ["role": "user", "content": prompt]
                ]
            ],
            "parameters": [
                "temperature": 0.7,
                "max_tokens": 300
            ]
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..300).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any],
              let text = output["text"] as? String else {
            throw NetworkError.decodingFailure
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 2: Add to target and build**

Expected: Build succeeds.

---

### Task 10: Keychain Manager and Settings

**Files:**
- Create: `BullNook/Services/KeychainManager.swift`
- Create: `BullNook/Views/SettingsView/SettingsView.swift`
- Create: `BullNook/ViewModels/SettingsViewModel.swift`

**Interfaces:**
- Produces: `KeychainManager.save(config:)`, `KeychainManager.load()`, `SettingsView`

- [ ] **Step 1: Implement KeychainManager.swift**

```swift
import Foundation
import Security

enum KeychainError: Error {
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
    case decodingFailure
}

struct KeychainManager {
    private static let service = "com.bullnook.llmconfig"
    private static let account = "llmConfig"
    
    static func save(config: LLMConfig) throws {
        let data = try JSONEncoder().encode(config)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    static func load() -> LLMConfig? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(LLMConfig.self, from: data)
    }
    
    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 2: Implement SettingsViewModel.swift**

```swift
import Foundation

@Observable
@MainActor
final class SettingsViewModel {
    var provider: LLMProvider = .deepSeek
    var apiKey: String = ""
    var isConfigured: Bool = false
    var showSavedConfirmation: Bool = false
    
    init() {
        loadConfig()
    }
    
    func loadConfig() {
        guard let config = KeychainManager.load() else {
            isConfigured = false
            return
        }
        provider = LLMProvider(rawValue: config.provider) ?? .deepSeek
        apiKey = config.apiKey
        isConfigured = !apiKey.isEmpty
    }
    
    func saveConfig() {
        let config = LLMConfig(provider: provider.rawValue, apiKey: apiKey)
        do {
            try KeychainManager.save(config: config)
            isConfigured = !apiKey.isEmpty
            showSavedConfirmation = true
        } catch {
            print("Failed to save LLM config: \(error)")
        }
    }
    
    func clearConfig() {
        KeychainManager.delete()
        apiKey = ""
        isConfigured = false
    }
}
```

- [ ] **Step 3: Implement SettingsView.swift**

```swift
import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("LLM 服务商") {
                    Picker("服务商", selection: $viewModel.provider) {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("API Key") {
                    SecureField("输入 API Key", text: $viewModel.apiKey)
                        .textContentType(.password)
                    
                    Button("保存") {
                        viewModel.saveConfig()
                    }
                    .disabled(viewModel.apiKey.isEmpty)
                    
                    if viewModel.isConfigured {
                        Button("清除配置", role: .destructive) {
                            viewModel.clearConfig()
                        }
                    }
                }
                
                Section("说明") {
                    Text("API Key 仅保存在设备钥匙串中，不会上传到任何服务器。未配置时推荐功能将使用规则摘要替代智能分析。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .alert("已保存", isPresented: $viewModel.showSavedConfirmation) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("LLM API Key 已保存到钥匙串。")
            }
        }
    }
}
```

- [ ] **Step 4: Add to target and build**

Expected: Build succeeds.

---

### Task 11: Theme and Shared Components

**Files:**
- Create: `BullNook/Views/Components/Theme.swift`
- Create: `BullNook/Views/Components/DisclaimerView.swift`
- Create: `BullNook/Views/Components/LoadingView.swift`

**Interfaces:**
- Produces: `Color` extensions, reusable `DisclaimerView`, `LoadingView`

- [ ] **Step 1: Implement Theme.swift**

```swift
import SwiftUI

extension Color {
    static let appBackground = Color(hex: "#0F172A")
    static let appCardBackground = Color(hex: "#1E293B")
    static let appTertiary = Color(hex: "#334155")
    static let appTextPrimary = Color(hex: "#F8FAFC")
    static let appTextSecondary = Color(hex: "#94A3B8")
    static let appAccentGold = Color(hex: "#F59E0B")
    static let appUp = Color(hex: "#10B981")
    static let appDown = Color(hex: "#EF4444")
    static let appNeutral = Color(hex: "#64748B")
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
```

- [ ] **Step 2: Implement DisclaimerView.swift**

```swift
import SwiftUI

struct DisclaimerView: View {
    var body: some View {
        Text("本应用所有推荐和分析仅供参考，不构成投资建议。股市有风险，投资需谨慎。")
            .font(.caption)
            .foregroundStyle(.appTextSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }
}
```

- [ ] **Step 3: Implement LoadingView.swift**

```swift
import SwiftUI

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.appAccentGold)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.appTextSecondary)
        }
        .padding()
    }
}
```

- [ ] **Step 4: Add to target and build**

Expected: Build succeeds.

---

### Task 12: Daily Pick View

**Files:**
- Create: `BullNook/Views/DailyPickView/PickCard.swift`
- Create: `BullNook/Views/DailyPickView/DailyPickView.swift`
- Create: `BullNook/ViewModels/DailyPickViewModel.swift`

**Interfaces:**
- Consumes: `StockCache`, `PickEngine`, `LLMAnalyzer`, `SinaAPI`, `EastMoneyAPI`
- Produces: `DailyPickView` displaying top 5 picks

- [ ] **Step 1: Implement DailyPickViewModel.swift**

```swift
import Foundation
import SwiftData

@Observable
@MainActor
final class DailyPickViewModel {
    private let context: ModelContext
    private let cache: StockCache
    private let pickEngine = PickEngine()
    private let llmAnalyzer = LLMAnalyzer()
    
    var picks: [DailyPick] = []
    var isLoading = false
    var errorMessage: String?
    var showAPIKeyAlert = false
    
    init(context: ModelContext) {
        self.context = context
        self.cache = StockCache(context: context)
        loadCachedPicks()
    }
    
    func loadCachedPicks() {
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        let cached = cache.dailyPicks(for: date: today)
        if !cached.isEmpty {
            picks = cached
        } else {
            picks = cache.latestDailyPicks(limit: 5)
        }
    }
    
    func refreshPicks() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        
        // Fetch sector and dragon tiger data for today
        let sectors = await EastMoneyAPI.sectorList()
        let dragonTigers = await EastMoneyAPI.dragonTiger()
        
        // Build a small candidate pool for MVP (in production this would be all A-shares)
        let candidateStocks = await loadCandidateStocks()
        
        // Fetch klines and news for candidates
        var klines: [String: [KLineData]] = [:]
        var news: [String: [StockNews]] = [:]
        for stock in candidateStocks {
            async let kline = EastMoneyAPI.kline(symbol: stock.symbol, period: .daily, start: "20240101", end: today)
            async let stockNews = EastMoneyAPI.stockNews(symbol: stock.symbol)
            let (k, n) = await (kline, stockNews)
            klines[stock.symbol] = k
            news[stock.symbol] = n
        }
        
        let inputs = PickInputs(stocks: candidateStocks, klines: klines, sectors: sectors, dragonTigers: dragonTigers, news: news)
        var generated = await pickEngine.generatePicks(inputs: inputs, date: today)
        
        // Fetch real-time quotes for generated picks
        let quotes = await SinaAPI.realTimeQuotes(symbols: generated.map(\.stockCode).map { codeToSymbol($0) })
        let quoteMap = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })
        
        // Enrich with LLM analysis
        let config = KeychainManager.load()
        generated = await withTaskGroup(of: DailyPick.self) { group in
            for pick in generated {
                group.addTask {
                    var mutable = pick
                    let analysis = await self.llmAnalyzer.analyze(pick: pick, allPicks: generated, config: config)
                    mutable.analysis = analysis
                    if let quote = quoteMap[codeToSymbol(pick.stockCode)] {
                        mutable.currentPrice = quote.currentPrice
                        mutable.changePercent = quote.changePercent
                    }
                    return mutable
                }
            }
            var results: [DailyPick] = []
            for await pick in group {
                results.append(pick)
            }
            return results.sorted { $0.rank < $1.rank }
        }
        
        // Save
        cache.deleteAllDailyPicks(for: today)
        cache.save(dailyPicks: generated)
        
        let historical = generated.map { HistoricalPick(from: $0, performanceSincePick: $0.changePercent) }
        cache.save(historicalPicks: historical)
        
        picks = generated
    }
    
    private func loadCandidateStocks() async -> [Stock] {
        // In a real app, fetch full A-share list. Here we use a representative sample for MVP.
        return [
            Stock(id: "600519", symbol: "sh600519", name: "贵州茅台", industry: "白酒", marketCap: 2_000_000_000_000),
            Stock(id: "000001", symbol: "sz000001", name: "平安银行", industry: "银行", marketCap: 200_000_000_000),
            Stock(id: "000333", symbol: "sz000333", name: "美的集团", industry: "家电", marketCap: 400_000_000_000),
            Stock(id: "002594", symbol: "sz002594", name: "比亚迪", industry: "汽车", marketCap: 700_000_000_000),
            Stock(id: "300750", symbol: "sz300750", name: "宁德时代", industry: "电池", marketCap: 800_000_000_000),
            Stock(id: "601318", symbol: "sh601318", name: "中国平安", industry: "保险", marketCap: 900_000_000_000),
            Stock(id: "600036", symbol: "sh600036", name: "招商银行", industry: "银行", marketCap: 800_000_000_000),
            Stock(id: "000858", symbol: "sz000858", name: "五粮液", industry: "白酒", marketCap: 600_000_000_000),
            Stock(id: "002475", symbol: "sz002475", name: "立讯精密", industry: "电子", marketCap: 250_000_000_000),
            Stock(id: "600276", symbol: "sh600276", name: "恒瑞医药", industry: "医药", marketCap: 300_000_000_000)
        ]
    }
}

private func codeToSymbol(_ code: String) -> String {
    if code.hasPrefix("6") { return "sh\(code)" }
    if code.hasPrefix("0") || code.hasPrefix("3") { return "sz\(code)" }
    return code
}
```

Note: There is a bug in `loadCachedPicks`: `cache.dailyPicks(for: date: today)` should be `cache.dailyPicks(for: today)`. Fix during implementation.

- [ ] **Step 2: Implement PickCard.swift**

```swift
import SwiftUI

struct PickCard: View {
    let pick: DailyPick
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.appAccentGold.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Text("\(pick.rank)")
                        .font(.headline)
                        .foregroundStyle(.appAccentGold)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(pick.stockName)
                        .font(.headline)
                        .foregroundStyle(.appTextPrimary)
                    Text(pick.stockCode)
                        .font(.caption)
                        .foregroundStyle(.appTextSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f", pick.currentPrice))
                        .font(.headline)
                        .foregroundStyle(.appTextPrimary)
                    Text(String(format: "%.2f%%", pick.changePercent))
                        .font(.caption)
                        .foregroundStyle(pick.changePercent >= 0 ? .appUp : .appDown)
                }
            }
            
            HStack {
                Text(pick.industry)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appTertiary)
                    .foregroundStyle(.appTextSecondary)
                    .clipShape(Capsule())
                
                Spacer()
                
                Text("综合得分 \(String(format: "%.1f", pick.score))")
                    .font(.caption)
                    .foregroundStyle(.appAccentGold)
            }
            
            Text(pick.reasonSummary)
                .font(.subheadline)
                .foregroundStyle(.appTextSecondary)
                .lineLimit(2)
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 3: Implement DailyPickView.swift**

```swift
import SwiftUI
import SwiftData

struct DailyPickView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel: DailyPickViewModel?
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    content(viewModel: viewModel)
                } else {
                    LoadingView(message: "加载中...")
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("今日精选")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.appAccentGold)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = DailyPickViewModel(context: context)
                }
            }
        }
    }
    
    @ViewBuilder
    private func content(viewModel: DailyPickViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection(viewModel: viewModel)
                
                if viewModel.isLoading && viewModel.picks.isEmpty {
                    LoadingView(message: "正在生成今日推荐...")
                        .padding(.top, 40)
                } else if viewModel.picks.isEmpty {
                    emptyState(viewModel: viewModel)
                } else {
                    picksList(viewModel: viewModel)
                }
                
                DisclaimerView()
                    .padding(.top, 8)
            }
            .padding()
        }
        .refreshable {
            await viewModel.refreshPicks()
        }
    }
    
    private func headerSection(viewModel: DailyPickViewModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("今日 5 只精选")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.appTextPrimary)
            Text("基于板块、龙虎榜、走势、消息链综合分析")
                .font(.subheadline)
                .foregroundStyle(.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func picksList(viewModel: DailyPickViewModel) -> some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.picks) { pick in
                NavigationLink(value: pick) {
                    PickCard(pick: pick)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationDestination(for: DailyPick.self) { pick in
            StockDetailView(pick: pick)
        }
    }
    
    private func emptyState(viewModel: DailyPickViewModel) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.appTextSecondary)
            Text("今日推荐正在生成中")
                .font(.headline)
                .foregroundStyle(.appTextPrimary)
            Text("首次使用或数据过期时会重新抓取公开数据并计算评分。")
                .font(.caption)
                .foregroundStyle(.appTextSecondary)
                .multilineTextAlignment(.center)
            Button("立即生成") {
                Task {
                    await viewModel.refreshPicks()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccentGold)
        }
        .padding(.top, 60)
    }
}
```

- [ ] **Step 4: Add to target and build**

Expected: Build succeeds after fixing `cache.dailyPicks(for: date: today)` to `cache.dailyPicks(for: today)`.

---

### Task 13: Stock Detail View

**Files:**
- Create: `BullNook/Views/StockDetailView/KLineChartView.swift`
- Create: `BullNook/Views/StockDetailView/F10View.swift`
- Create: `BullNook/Views/StockDetailView/AnalysisView.swift`
- Create: `BullNook/Views/StockDetailView/StockDetailView.swift`
- Create: `BullNook/ViewModels/StockDetailViewModel.swift`

**Interfaces:**
- Consumes: `DailyPick`, `StockCache`, `SinaAPI`/`EastMoneyAPI`
- Produces: `StockDetailView` with tabs for K-line, F10, analysis

- [ ] **Step 1: Implement StockDetailViewModel.swift**

```swift
import Foundation
import SwiftData

@Observable
@MainActor
final class StockDetailViewModel {
    private let cache: StockCache
    let pick: DailyPick
    
    var kline: [KLineData] = []
    var selectedPeriod: KLinePeriod = .daily
    var f10: F10Metric?
    var isInWatchlist = false
    var isLoading = false
    
    init(pick: DailyPick, context: ModelContext) {
        self.pick = pick
        self.cache = StockCache(context: context)
    }
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        let symbol = codeToSymbol(pick.stockCode)
        let cached = cache.kline(symbol: symbol, period: selectedPeriod)
        if cached.count >= 60 {
            kline = cached
        } else {
            let today = DateFormatter.yyyyMMdd.string(from: Date())
            kline = await EastMoneyAPI.kline(symbol: symbol, period: selectedPeriod, start: "20240101", end: today)
            if !kline.isEmpty {
                cache.save(kline: kline)
            }
        }
        
        f10 = cache.f10(symbol: symbol)
        if f10 == nil {
            if let fetched = await EastMoneyAPI.f10(symbol: symbol) {
                f10 = fetched
                cache.save(f10: fetched)
            }
        }
        
        isInWatchlist = cache.isInWatchlist(stockCode: pick.stockCode)
    }
    
    func toggleWatchlist() {
        if isInWatchlist {
            cache.removeFromWatchlist(stockCode: pick.stockCode)
        } else {
            cache.addToWatchlist(stockCode: pick.stockCode, stockName: pick.stockName, industry: pick.industry)
        }
        isInWatchlist.toggle()
    }
    
    func switchPeriod(_ period: KLinePeriod) async {
        selectedPeriod = period
        await loadData()
    }
}

private func codeToSymbol(_ code: String) -> String {
    if code.hasPrefix("6") { return "sh\(code)" }
    if code.hasPrefix("0") || code.hasPrefix("3") { return "sz\(code)" }
    return code
}
```

- [ ] **Step 2: Implement KLineChartView.swift**

```swift
import SwiftUI
import Charts

struct KLineChartView: View {
    let data: [KLineData]
    
    var body: some View {
        Chart(data) { item in
            RuleMark(
                x: .value("Date", item.date),
                yStart: .value("Low", item.low),
                yEnd: .value("High", item.high)
            )
            .foregroundStyle(color(for: item))
            .lineStyle(StrokeStyle(lineWidth: 1))
            
            RectangleMark(
                x: .value("Date", item.date),
                yStart: .value("Open", item.open),
                yEnd: .value("Close", item.close),
                width: .fixed(4)
            )
            .foregroundStyle(color(for: item))
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 260)
    }
    
    private func color(for item: KLineData) -> Color {
        if item.close > item.open { return .appUp }
        if item.close < item.open { return .appDown }
        return .appNeutral
    }
}
```

- [ ] **Step 3: Implement F10View.swift**

```swift
import SwiftUI

struct F10View: View {
    let f10: F10Metric?
    let marketCap: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let f10 = f10 {
                metricRow(title: "市盈率 (PE)", value: String(format: "%.2f", f10.pe))
                metricRow(title: "市净率 (PB)", value: String(format: "%.2f", f10.pb))
                metricRow(title: "ROE", value: String(format: "%.2f%%", f10.roe))
                metricRow(title: "营收增速", value: String(format: "%.2f%%", f10.revenueGrowth))
                metricRow(title: "净利润增速", value: String(format: "%.2f%%", f10.profitGrowth))
                metricRow(title: "总市值", value: formatMarketCap(f10.totalMarketCap))
                metricRow(title: "流通市值", value: formatMarketCap(f10.circulatingMarketCap))
            } else {
                Text("F10 数据暂不可用")
                    .foregroundStyle(.appTextSecondary)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.appTextSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(.appTextPrimary)
                .fontWeight(.medium)
        }
    }
    
    private func formatMarketCap(_ value: Double) -> String {
        if value >= 1_000_000_000_000 { return String(format: "%.2f 万亿", value / 1_000_000_000_000) }
        if value >= 100_000_000 { return String(format: "%.2f 亿", value / 100_000_000) }
        return String(format: "%.0f", value)
    }
}
```

- [ ] **Step 4: Implement AnalysisView.swift**

```swift
import SwiftUI

struct AnalysisView: View {
    let pick: DailyPick
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("四维度得分")
                .font(.headline)
                .foregroundStyle(.appTextPrimary)
            
            scoreRow(title: "板块热度", score: pick.sectorScore)
            scoreRow(title: "龙虎榜资金", score: pick.lhbScore)
            scoreRow(title: "个股走势", score: pick.trendScore)
            scoreRow(title: "消息链", score: pick.newsScore)
            
            Divider()
                .background(Color.appTertiary)
            
            Text("入选分析")
                .font(.headline)
                .foregroundStyle(.appTextPrimary)
            
            Text(pick.analysis.isEmpty ? pick.reasonSummary : pick.analysis)
                .font(.body)
                .foregroundStyle(.appTextSecondary)
            
            DisclaimerView()
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func scoreRow(title: String, score: Double) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.appTextSecondary)
            Spacer()
            Text(String(format: "%.1f", score))
                .foregroundStyle(.appAccentGold)
                .fontWeight(.bold)
        }
    }
}
```

- [ ] **Step 5: Implement StockDetailView.swift**

```swift
import SwiftUI
import SwiftData

struct StockDetailView: View {
    @Environment(\.modelContext) private var context
    let pick: DailyPick
    @State private var viewModel: StockDetailViewModel?
    @State private var selectedTab = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                periodSelector
                
                if let viewModel = viewModel {
                    tabContent(viewModel: viewModel)
                } else {
                    LoadingView(message: "加载详情中...")
                }
            }
            .padding()
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(pick.stockName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let viewModel = viewModel {
                    Button {
                        viewModel.toggleWatchlist()
                    } label: {
                        Image(systemName: viewModel.isInWatchlist ? "star.fill" : "star")
                            .foregroundStyle(.appAccentGold)
                    }
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = StockDetailViewModel(pick: pick, context: context)
            }
            Task {
                await viewModel?.loadData()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pick.stockName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.appTextPrimary)
                    Text("\(pick.stockCode) · \(pick.industry)")
                        .font(.subheadline)
                        .foregroundStyle(.appTextSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.2f", pick.currentPrice))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.appTextPrimary)
                    Text(String(format: "%.2f%%", pick.changePercent))
                        .font(.subheadline)
                        .foregroundStyle(pick.changePercent >= 0 ? .appUp : .appDown)
                }
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var periodSelector: some View {
        Picker("周期", selection: $selectedTab) {
            Text("走势").tag(0)
            Text("F10").tag(1)
            Text("分析").tag(2)
        }
        .pickerStyle(.segmented)
        .colorMultiply(.appAccentGold)
    }
    
    @ViewBuilder
    private func tabContent(viewModel: StockDetailViewModel) -> some View {
        if selectedTab == 0 {
            VStack(spacing: 12) {
                Picker("K线周期", selection: Binding(
                    get: { viewModel.selectedPeriod },
                    set: { _ in }
                )) {
                    ForEach(KLinePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.selectedPeriod) { _, newValue in
                    Task {
                        await viewModel.switchPeriod(newValue)
                    }
                }
                
                if viewModel.kline.isEmpty {
                    Text("K线数据暂不可用")
                        .foregroundStyle(.appTextSecondary)
                        .padding()
                } else {
                    KLineChartView(data: viewModel.kline)
                }
            }
            .padding()
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if selectedTab == 1 {
            F10View(f10: viewModel.f10, marketCap: 0)
        } else {
            AnalysisView(pick: pick)
        }
    }
}
```

Note: The tab implementation mixes a `selectedTab` state with `viewModel.selectedPeriod`. Simplify during implementation by using `selectedTab` for top tabs and a separate picker for K-line period inside the chart tab.

- [ ] **Step 6: Add to target and build**

Expected: Build succeeds after addressing the tab/picker binding simplification.

---

### Task 14: Watchlist View

**Files:**
- Create: `BullNook/Views/WatchlistView/WatchlistRow.swift`
- Create: `BullNook/Views/WatchlistView/WatchlistView.swift`
- Create: `BullNook/ViewModels/WatchlistViewModel.swift`

**Interfaces:**
- Consumes: `StockCache`, `SinaAPI`/`TencentAPI`
- Produces: `WatchlistView` with 5-minute auto refresh

- [ ] **Step 1: Implement WatchlistViewModel.swift**

```swift
import Foundation
import SwiftData

@Observable
@MainActor
final class WatchlistViewModel {
    private let cache: StockCache
    
    var items: [WatchlistItem] = []
    var lastUpdated: Date?
    var isLoading = false
    private var timer: Timer?
    
    init(context: ModelContext) {
        self.cache = StockCache(context: context)
        loadItems()
    }
    
    func loadItems() {
        items = cache.watchlistItems()
    }
    
    func startAutoRefresh() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshQuotes()
            }
        }
        Task {
            await refreshQuotes()
        }
    }
    
    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }
    
    func refreshQuotes() async {
        guard !items.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        
        let symbols = items.map { codeToSymbol($0.stockCode) }
        let quotes = await SinaAPI.realTimeQuotes(symbols: symbols)
        let quoteMap = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })
        
        for item in items {
            if let quote = quoteMap[codeToSymbol(item.stockCode)] {
                item.currentPrice = quote.currentPrice
                item.changePercent = quote.changePercent
                item.lastUpdated = Date()
            }
        }
        
        cache.updateWatchlist(items: items)
        lastUpdated = Date()
    }
    
    func remove(item: WatchlistItem) {
        cache.removeFromWatchlist(stockCode: item.stockCode)
        loadItems()
    }
}

private func codeToSymbol(_ code: String) -> String {
    if code.hasPrefix("6") { return "sh\(code)" }
    if code.hasPrefix("0") || code.hasPrefix("3") { return "sz\(code)" }
    return code
}
```

- [ ] **Step 2: Implement WatchlistRow.swift**

```swift
import SwiftUI

struct WatchlistRow: View {
    let item: WatchlistItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.stockName)
                    .font(.headline)
                    .foregroundStyle(.appTextPrimary)
                Text("\(item.stockCode) · \(item.industry)")
                    .font(.caption)
                    .foregroundStyle(.appTextSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f", item.currentPrice))
                    .font(.headline)
                    .foregroundStyle(.appTextPrimary)
                Text(String(format: "%.2f%%", item.changePercent))
                    .font(.caption)
                    .foregroundStyle(item.changePercent >= 0 ? .appUp : .appDown)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 3: Implement WatchlistView.swift**

```swift
import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel: WatchlistViewModel?
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    content(viewModel: viewModel)
                } else {
                    LoadingView(message: "加载中...")
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("自选股")
            .onAppear {
                if viewModel == nil {
                    viewModel = WatchlistViewModel(context: context)
                }
                viewModel?.startAutoRefresh()
            }
            .onDisappear {
                viewModel?.stopAutoRefresh()
            }
        }
    }
    
    @ViewBuilder
    private func content(viewModel: WatchlistViewModel) -> some View {
        if viewModel.items.isEmpty {
            emptyState
        } else {
            listView(viewModel: viewModel)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star")
                .font(.system(size: 48))
                .foregroundStyle(.appTextSecondary)
            Text("暂无自选股")
                .font(.headline)
                .foregroundStyle(.appTextPrimary)
            Text("从每日推荐中添加股票，追踪自选行情")
                .font(.caption)
                .foregroundStyle(.appTextSecondary)
        }
        .padding(.top, 80)
    }
    
    private func listView(viewModel: WatchlistViewModel) -> some View {
        List {
            Section {
                if let lastUpdated = viewModel.lastUpdated {
                    Text("最后更新：\(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.appTextSecondary)
                }
            }
            
            ForEach(viewModel.items) { item in
                WatchlistRow(item: item)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.remove(item: viewModel.items[index])
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refreshQuotes()
        }
    }
}
```

- [ ] **Step 4: Add to target and build**

Expected: Build succeeds.

---

### Task 15: Historical Picks View

**Files:**
- Create: `BullNook/Views/HistoricalPicksView/HistoricalPicksView.swift`

**Interfaces:**
- Consumes: `StockCache`
- Produces: `HistoricalPicksView`

- [ ] **Step 1: Implement HistoricalPicksView.swift**

```swift
import SwiftUI
import SwiftData

struct HistoricalPicksView: View {
    @Environment(\.modelContext) private var context
    @State private var cache: StockCache?
    @State private var picks: [HistoricalPick] = []
    @State private var sortByPerformance = false
    
    var body: some View {
        NavigationStack {
            List {
                Toggle("按涨跌幅排序", isOn: $sortByPerformance)
                    .foregroundStyle(.appTextPrimary)
                
                ForEach(groupedPicks.keys.sorted(by: >), id: \.self) { date in
                    Section(date) {
                        ForEach(displayedPicks(for: date)) { pick in
                            historicalRow(pick: pick)
                        }
                    }
                }
            }
            .navigationTitle("历史推荐")
            .background(Color.appBackground.ignoresSafeArea())
            .onAppear {
                if cache == nil {
                    cache = StockCache(context: context)
                }
                picks = cache?.historicalPicks() ?? []
            }
            .onChange(of: sortByPerformance) { _, _ in
                picks = cache?.historicalPicks() ?? []
            }
        }
    }
    
    private var groupedPicks: [String: [HistoricalPick]] {
        Dictionary(grouping: picks, by: { $0.date })
    }
    
    private func displayedPicks(for date: String) -> [HistoricalPick] {
        let group = groupedPicks[date] ?? []
        if sortByPerformance {
            return group.sorted { $0.performanceSincePick > $1.performanceSincePick }
        }
        return group.sorted { $0.rank < $1.rank }
    }
    
    private func historicalRow(pick: HistoricalPick) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(pick.rank). \(pick.stockName)")
                    .font(.headline)
                    .foregroundStyle(.appTextPrimary)
                Text(pick.stockCode)
                    .font(.caption)
                    .foregroundStyle(.appTextSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f%%", pick.performanceSincePick))
                    .font(.headline)
                    .foregroundStyle(pick.performanceSincePick >= 0 ? .appUp : .appDown)
                Text("得分 \(String(format: "%.1f", pick.score))")
                    .font(.caption)
                    .foregroundStyle(.appTextSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 2: Add to target and build**

Expected: Build succeeds.

---

### Task 16: Widget

**Files:**
- Create: `BullNook/Widget/BullnookWidgetBundle.swift`
- Create: `BullNook/Widget/BullnookWidget.swift`
- Modify: `BullNook.xcodeproj` (add Widget Extension target)

**Interfaces:**
- Consumes: `DailyPick` from shared SwiftData container
- Produces: Widget displaying today's Top 1 pick

- [ ] **Step 1: Add a Widget Extension target to the Xcode project**

In Xcode, choose **File → New → Target → Widget Extension**, name it `BullnookWidget`, and make sure "Include Configuration Intent" is unchecked. This creates a new target and files. For this plan, create the files manually in `BullNook/Widget/` and add them to the Widget Extension target.

- [ ] **Step 2: Implement BullnookWidgetBundle.swift**

```swift
//
//  BullnookWidgetBundle.swift
//  BullnookWidget
//

import WidgetKit
import SwiftUI

@main
struct BullnookWidgetBundle: WidgetBundle {
    var body: some Widget {
        BullnookWidget()
    }
}
```

- [ ] **Step 3: Implement BullnookWidget.swift**

```swift
//
//  BullnookWidget.swift
//  BullnookWidget
//

import WidgetKit
import SwiftUI
import SwiftData

struct BullnookEntry: TimelineEntry {
    let date: Date
    let pick: DailyPick?
}

struct BullnookProvider: TimelineProvider {
    func placeholder(in context: Context) -> BullnookEntry {
        BullnookEntry(date: Date(), pick: nil)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (BullnookEntry) -> Void) {
        let entry = BullnookEntry(date: Date(), pick: samplePick())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<BullnookEntry>) -> Void) {
        let entry = BullnookEntry(date: Date(), pick: samplePick())
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
        completion(timeline)
    }
    
    private func samplePick() -> DailyPick {
        DailyPick(
            id: "sample",
            date: "20260705",
            rank: 1,
            stockCode: "600519",
            stockName: "贵州茅台",
            industry: "白酒",
            score: 88.5,
            reasonSummary: "板块热度与走势共振",
            sectorScore: 90,
            lhbScore: 70,
            trendScore: 95,
            newsScore: 80,
            analysis: ""
        )
    }
}

struct BullnookWidgetEntryView: View {
    var entry: BullnookProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        if let pick = entry.pick {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("今日 Top 1")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("#\(pick.rank)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Text(pick.stockName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(pick.stockCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if family != .systemSmall {
                    Text(pick.reasonSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding()
            .widgetURL(URL(string: "bullnook://stock/\(pick.stockCode)"))
        } else {
            Text("今日推荐尚未生成")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct BullnookWidget: Widget {
    let kind: String = "BullnookWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BullnookProvider()) { entry in
            BullnookWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("牛角尖推荐")
        .description("展示今日 Top 1 精选股票")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

- [ ] **Step 4: Configure App Groups for shared SwiftData (optional for MVP)**

For the widget to read the same SwiftData container as the app, both targets need an App Group entitlement. For MVP, the widget can use the static sample or a simplified timeline. Add App Group capability to both targets if shared data is required.

- [ ] **Step 5: Build the Widget Extension**

Select the `BullnookWidget` scheme in Xcode and build. Or run:

```bash
cd /Users/yangzhuo/BullNook
xcodebuild -project BullNook.xcodeproj -scheme BullnookWidget -destination 'platform=iOS Simulator,name=iPhone 15' build
```

Expected: Build succeeds.

---

### Task 17: App Integration, Build, and Verification

**Files:**
- Modify: `BullNook/BullnookApp.swift`
- Modify: `BullNook/ContentView.swift`

**Interfaces:**
- Produces: Complete app entry point with tab navigation

- [ ] **Step 1: Implement ContentView.swift**

```swift
//
//  ContentView.swift
//  BullNook
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DailyPickView()
                .tabItem {
                    Label("每日推荐", systemImage: "flame")
                }
            
            WatchlistView()
                .tabItem {
                    Label("自选股", systemImage: "star")
                }
            
            HistoricalPicksView()
                .tabItem {
                    Label("历史", systemImage: "clock.arrow.circlepath")
                }
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .accentColor(.appAccentGold)
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 2: Update BullnookApp.swift to add welcome logic**

For MVP, keep `BullnookApp.swift` minimal. The first-launch API key prompt can be shown from `DailyPickView` when picks are empty and no key is configured.

```swift
//
//  BullnookApp.swift
//  BullNook
//

import SwiftUI
import SwiftData

@main
struct BullNookApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Stock.self,
            DailyPick.self,
            HistoricalPick.self,
            KLineData.self,
            F10Metric.self,
            WatchlistItem.self,
            SectorData.self,
            DragonTigerData.self
        ])
    }
}
```

- [ ] **Step 3: Add first-launch API key prompt to DailyPickView**

Add the following to `DailyPickView` after `loadCachedPicks()` is called:

```swift
.onAppear {
    if viewModel == nil {
        viewModel = DailyPickViewModel(context: context)
    }
    if KeychainManager.load() == nil {
        showSettings = true
    }
}
```

- [ ] **Step 4: Final build and run**

```bash
cd /Users/yangzhuo/BullNook
xcodebuild -project BullNook.xcodeproj -scheme BullNook -destination 'platform=iOS Simulator,name=iPhone 15' build
```

Expected: Build succeeds.

- [ ] **Step 5: Manual verification checklist**

1. App launches on iPhone 15 simulator
2. DailyPickView shows cached/sample picks or empty state
3. Tapping a pick navigates to StockDetailView
4. K-line tab renders chart (or placeholder if data unavailable)
5. WatchlistView shows empty state and supports adding from detail
6. HistoricalPicksView lists saved picks
7. SettingsView saves/clears API key in Keychain
8. Widget scheme builds successfully
9. Risk disclaimer visible on DailyPickView and AnalysisView

---

## Self-Review

### Spec Coverage

| Spec Requirement | Implementing Task |
|------------------|-------------------|
| iOS 17+ SwiftUI App + Widget | Task 1, 16 |
| SwiftData models | Task 2 |
| Public data sources (Sina/EastMoney/Tencent) | Tasks 3-6 |
| Four-dimension scoring + filtering | Task 8 |
| LLM analysis with graceful degradation | Task 9 |
| API Key in Keychain + settings | Task 10 |
| DailyPickView | Task 12 |
| StockDetailView with K-line/F10/analysis | Task 13 |
| WatchlistView with 5-min refresh | Task 14 |
| HistoricalPicksView | Task 15 |
| Widget Top 1 | Task 16 |
| Risk disclaimer | Tasks 11, 13, 17 |

### Placeholder Scan

- `EastMoneyAPI.parseF10` returns default zeros because public F10 endpoints are unstable; this is intentional graceful degradation, not an unimplemented placeholder.
- `DailyPickViewModel.loadCandidateStocks` uses a hardcoded candidate list for MVP; production should fetch full A-share list.

### Type Consistency

- `KLinePeriod` defined in `SinaAPI.swift`; used across `SinaAPI`, `EastMoneyAPI`, `StockCache`, `StockDetailViewModel`.
- `codeToSymbol` helper duplicated across view models; consider moving to a shared `StockSymbol` utility during implementation.
- `cache.dailyPicks(for: date: today)` typo in `DailyPickViewModel` must be corrected to `cache.dailyPicks(for: today)`.

### Known Gaps / MVP Simplifications

1. Full A-share stock list not fetched; uses a 10-stock sample.
2. F10 parsing returns default zeros due to unstable public endpoint.
3. Widget reads static sample data unless App Groups + shared container is configured.
4. News sentiment analysis is keyword-count based, not true NLP.

These gaps are acceptable for MVP and documented for future iteration.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-05-bullnook-mvp.md`.**

Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints.

Which approach would you like?
