# DATA_SOURCES.md

Bullnook 数据源说明文档。

---

## 数据源选择

本项目采用 **iOS 端直接调用公开接口** 的方式获取数据，不依赖后端。

主要数据源：
- 新浪财经：实时行情、历史 K线
- 东方财富：龙虎榜、板块、F10、个股新闻
- 腾讯财经：实时行情快照（备用）

选择原因：
- 完全免费，无需自建后端
- 数据覆盖 A 股行情、龙虎榜、板块、新闻等
- 数据来自公开站点，iOS 端可直接请求

---

## 接口速查

### 新浪财经

#### 实时行情

```
https://hq.sinajs.cn/list=sh600519,sz000001
```

返回：`var hq_str_sh600519="贵州茅台,23.45,...";`

字段：
- 名称
- 最新价
- 昨收
- 今开
- 最高
- 最低
- 买一/卖一
- 成交量
- 成交额
- 日期时间

#### 历史 K线

```
https://quotes.sina.cn/cn/api/quotes.php?symbol=sh600519&datalen=250&fq=1&d=1
```

参数：
- `datalen`: 返回条数
- `fq`: 1 为前复权
- `d`: 1 日线，7 周线，30 月线

### 东方财富

#### 历史 K线

```
https://push2his.eastmoney.com/api/qt/stock/kline/get?secid=1.600519&fields1=f1,f2,f3,f4,f5,f6&fields2=f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61&klt=101&fqt=1&beg=20240101&end=20260705
```

参数：
- `secid`: `1.代码` 表示上海，`0.代码` 表示深圳
- `klt`: 101 日线，102 周线，103 月线
- `fqt`: 1 前复权

返回字段：`日期,开盘,收盘,最高,最低,成交量,成交额,振幅,涨跌幅,涨跌额,换手率`

#### 龙虎榜

```
https://datacenter-web.eastmoney.com/api/data/v1/get?sortColumns=SECURITY_CODE,TRADE_DATE&sortTypes=-1,-1&pageSize=500&pageNumber=1&reportName=RPT_DMSK_TS_LSTOCKT&columns=ALL&source=WEB&client=WEB
```

#### 板块列表

```
https://push2.eastmoney.com/api/qt/clist/get?pn=1&pz=100&po=1&np=1&fltt=2&invt=2&fid=f3&fs=m:90+t:2&fields=f12,f14,f2,f3,f4,f5,f6,f7,f8,f9,f10,f18,f20,f21,f22,f23,f24,f25,f26,f33,f34,f35,f36,f37,f38,f39,f40,f41,f42,f43,f44,f45,f46,f47,f48,f49,f50,f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61,f62,f63,f64,f65,f66,f67,f68,f69,f70,f71,f72,f73,f74,f75,f76,f77,f78,f79,f80,f81,f82,f83,f84,f85,f86,f87,f88,f89,f90,f91,f92,f93
```

#### 个股新闻

```
https://searchapi.eastmoney.com/api/sns/get?type=14&cb=jQuery&keyword=600519&pageindex=1&pagesize=20
```

### 腾讯财经（备用实时行情）

```
https://qt.gtimg.cn/q=sh600519,sz000001
```

返回：`v_sh600519="1~贵州茅台~600519~23.45...";`

---

## 原 AkShare 方案（已放弃）

以下 AkShare 接口原用于后端方案，现改为 iOS 端直接调用公开接口，仅保留作参考：

### 1. A股历史行情（日线/周线/月线）

```python
import akshare as ak

# 日线
df = ak.stock_zh_a_hist(symbol="600519", period="daily", start_date="20240101", end_date="20260705", adjust="qfq")

# 周线
df = ak.stock_zh_a_hist(symbol="600519", period="weekly", start_date="20240101", end_date="20260705", adjust="qfq")

# 月线
df = ak.stock_zh_a_hist(symbol="600519", period="monthly", start_date="20200101", end_date="20260705", adjust="qfq")
```

返回字段：
- `日期`
- `开盘`
- `收盘`
- `最高`
- `最低`
- `成交量`
- `成交额`
- `振幅`
- `涨跌幅`
- `涨跌额`
- `换手率`

---

### 2. 实时行情快照

```python
df = ak.stock_zh_a_spot_em()
```

返回全市场实时行情，包含最新价、涨跌幅、成交额等。

---

### 3. 龙虎榜

```python
# 某日龙虎榜
ak.stock_lhb_detail_daily_sina(start_date="20260705", end_date="20260705")

# 龙虎榜详情
ak.stock_lhb_detail_em(start_date="20260705", end_date="20260705")
```

---

### 4. 板块/行业涨幅

```python
# 行业板块涨幅
ak.stock_board_industry_name_em()

# 行业板块历史行情
ak.stock_board_industry_hist_em(symbol="白酒", period="日k")

# 概念板块
ak.stock_board_concept_name_em()
```

---

### 5. 个股新闻/公告

```python
# 个股新闻
ak.stock_news_em(symbol="600519")

# 公司公告
ak.stock_notice_report(symbol="600519", date="20260705")
```

---

### 6. 财务指标（F10）

```python
# 个股财务指标
ak.stock_financial_analysis_indicator(symbol="600519")

# 个股主要指标
ak.stock_zh_a_new()
```

常用字段：
- 市盈率（PE）
- 市净率（PB）
- 净资产收益率（ROE）
- 营收增速
- 净利润增速

---

### 7. 股票基础信息

```python
# 全市场股票列表
ak.stock_info_a_code_name()

# 带行业信息
ak.stock_info()
```

---

## 数据更新频率

| 数据类型 | 更新频率 | 说明 |
|---------|---------|------|
| 日线/周线/月线 | 每日收盘后 | 增量更新 |
| 实时行情 | 每 5 分钟 | 用于自选股刷新 |
| 龙虎榜 | 每日收盘后 | 有上榜数据才更新 |
| 板块数据 | 每日收盘后 | 计算板块热度 |
| 个股新闻 | 每日 08:00 前 | 用于消息链分析 |
| 财务数据 | 季度/年度 | 季报/年报发布后更新 |
| 股票基础信息 | 每月 | 新增/退市股票 |

---

## 数据字段标准化

iOS 端抓取到数据后，统一转换为以下英文字段名：

| 中文原名 | 英文字段名 | 类型 |
|---------|----------|------|
| 日期 | date | string |
| 开盘 | open | float |
| 收盘 | close | float |
| 最高 | high | float |
| 最低 | low | float |
| 成交量 | volume | float |
| 成交额 | amount | float |
| 涨跌幅 | change_pct | float |
| 换手率 | turnover | float |
| 市盈率 | pe | float |
| 市净率 | pb | float |
| 净资产收益率 | roe | float |

---

## 公开接口注意事项

1. **接口可能变动**：新浪、东方财富页面结构变化可能导致接口失效。需要定期检查。
2. **请求频率限制**：避免高频请求，建议加间隔、重试、批量请求。
3. **跨域与 HTTP 限制**：iOS 默认只允许 HTTPS，需在 Info.plist 中配置允许 HTTP 例外域名。
4. **数据一致性**：不同接口的数据源可能略有差异，以实际返回为准。
5. **退市/ST 股票**：全市场股票列表中可能包含 ST/退市风险股，推荐引擎需做过滤。

---

## 备选数据源

| 数据源 | 优点 | 缺点 |
|-------|------|------|
| Tushare | 接口稳定 | 免费版有限额，高级数据需积分 |
| 新浪财经 | 实时行情 | 非官方 API，不稳定 |
| 腾讯财经 | 实时行情 | 字段有限 |
| 东方财富 | 数据全面 | 需要自行抓取 |

: MVP 阶段以新浪、东方财富、腾讯公开接口为主，必要时补充其他数据源。公开接口不稳定时，可考虑升级到后端聚合方案。
