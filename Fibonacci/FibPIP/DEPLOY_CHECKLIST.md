# FibPIP — Compile Checklist & 部署說明

---

## 1. 文件放置

```
MT5 安裝目錄\MQL5\
├── Include\
│   └── Toolbox\
│       ├── FibPIP.mqh          ← 新增
│       ├── FibTypes.mqh        ← 已有（唔需要改）
│       ├── Fibonacci.mqh       ← 已有（唔需要改）
│       ├── PivotSR.mqh         ← 已有（唔需要改）
│       ├── SupportResistance.mqh ← 已有（唔需要改）
│       └── ATR.mqh             ← 已有（唔需要改）
└── Indicators\
    ├── Fibonacci_PIP.mq5       ← 新增
    └── FibComparison.mq5       ← 新增
```

---

## 2. Compile 順序

**必須按呢個順序 compile，否則會有 dependency error：**

```
1. FibTypes.mqh          → 唔需要 compile（純 struct）
2. ATR.mqh               → 唔需要 compile（純邏輯）
3. SupportResistance.mqh → 唔需要 compile（純邏輯）
4. FibPIP.mqh            → 唔需要 compile（純邏輯）
5. Fibonacci_PIP.mq5     → ✅ Compile
6. FibComparison.mq5     → ✅ Compile
```

喺 MetaEditor：開啟 `.mq5` 文件 → 按 `F7` compile。

---

## 3. 常見 Compile Error 同解決方法

| Error | 原因 | 解決 |
|---|---|---|
| `'GetPipSize' - function already defined` | `ATR.mqh` 同 `FibPIP.mqh` 都有 `GetPipSize()` | 喺 `FibPIP.mqh` 頭部加 `#include <Toolbox/ATR.mqh>` 並刪除 `FibPIP.mqh` 內嘅本地版本 |
| `'CalcFibSRScore' - function already defined` | `PivotSR.mqh` 同 `FibPIP.mqh` 都有同名函數 | `FibPIP.mqh` 用嘅係 `CalcFibSRScore_PIP`，唔同名，不應出現此 error |
| `'SRResult' - undeclared identifier` | `FibPIP.mqh` 未能搵到 `SupportResistance.mqh` | 確認 `SupportResistance.mqh` 喺 `Toolbox\` 資料夾入面 |
| `'FibLevels' - undeclared identifier` | `FibTypes.mqh` 路徑錯 | 確認 include path 係 `<Toolbox/FibTypes.mqh>` |
| `cannot open file 'Toolbox/FibPIP.mqh'` | 文件位置錯 | 確認放喺 `MQL5\Include\Toolbox\` |

---

## 4. 已知潛在衝突：`GetPipSize` 重複定義

`FibPIP.mqh` 內有本地版本 `GetPipSize()`，而 `ATR.mqh` 亦有同名函數。
`FibComparison.mq5` 同時 include 兩者，**大概率會出現 redefinition error**。

**修復方法（喺 MetaEditor 直接改 `FibPIP.mqh`）：**

```mql5
// 刪除 FibPIP.mqh 入面呢段：
double GetPipSize(string symbol)
{
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    if(digits == 3 || digits == 2) return 0.01;
    return 0.0001;
}

// 改為喺 #include 區域加：
#include <Toolbox/ATR.mqh>   // 提供 GetPipSize()
```

---

## 5. Attach 到 Chart 設定

### Fibonacci_PIP.mq5（單獨測試 PIP 方法）
- Attach 到任何 timeframe
- 推薦入門參數：
  ```
  InpPIPOrder     = 5
  InpWindowSize   = 96       // M5 用 96 bars = 8小時
  InpDistMode     = VER_DIS
  InpMinRangePips = 10.0
  InpUseSR        = true
  InpUseLock      = true
  InpLogBarCSV    = true
  InpLogAnchorCSV = true
  InpLogFolder    = FibPIP_Logs
  ```

### FibComparison.mq5（A/B 比較）
- 同一個 chart attach，兩組線同時顯示
- 確保 PIP window 同 PSR lookback 用相近嘅 bar 數，公平比較：
  ```
  InpPIP_Window    = 96
  InpPIP_Order     = 5
  InpPSR_PivotLook = 96
  InpPSR_PivotN    = 5
  // 共用 S/R 參數要一樣
  InpSRLookback    = 100
  InpSRZonePips    = 10.0
  InpSRMinCount    = 4
  InpSRTolPips     = 10.0
  ```

---

## 6. CSV 文件位置

MT5 Common Files 路徑（Windows）：
```
C:\Users\<用戶名>\AppData\Roaming\MetaQuotes\Terminal\Common\Files\
├── FibPIP_Logs\
│   ├── USDJPY_M5_BUY_O5_W96_VER_SR1_bar.csv
│   └── USDJPY_M5_BUY_O5_W96_VER_SR1_anchor.csv
└── FibCMP_Logs\
    ├── USDJPY_M5_BUY_CMP_bar.csv
    └── USDJPY_M5_BUY_CMP_anchor.csv
```

MT5 入面快速到達：`File → Open Common Data Folder`

---

## 7. 視覺確認清單（attach 後即時 check）

- [ ] 圖上出現青色線（PIP）同橙紅色線（PSR）
- [ ] Tooltip hover 顯示 `[PIP]` 或 `[PSR]` 標籤
- [ ] 兩條 0.618 線喺合理位置（唔係差太遠）
- [ ] Journal 有輸出 `=== FibCMP ===` 同埋 diff pips
- [ ] Common Files 資料夾出現 CSV 文件
- [ ] CSV 第一行係 header，之後每 bar 有一行數據
