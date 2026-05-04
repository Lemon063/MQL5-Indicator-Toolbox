# CHANGELOG_FibPIP.md

## 2026-05-04  v1.20

### 改動
- **移除 `FindPIPAnchors()` 整個函數**
  - 呢個函數係移植時額外加入，原版 `pip_algo_us.py` 冇對應概念
  - 移除後 `FibPIP.mqh` 更簡潔，冇多餘抽象層

- **移除方向性驗證**
  - 原版 `pip_algo_us.py` 唔做方向驗證
  - `GetAnchorPoints_PIP()` 直接取 PIP 點中最高同最低做錨點，唔理時間順序

- **移除所有 `[PIP DBG]` debug print**
  - 係之前 debug 用途臨時加入，應該清除

- **`GetAnchorPoints_PIP()` 重寫**
  - 唔再 call `FindPIPAnchors()`
  - 直接喺 `CalcPIPPoints()` 結果入面搵最高同最低點

### 唔影響
- `CalcPIPPoints()` 核心算法唔變
- `CalcFibSRScore_PIP()` 唔變
- `PIPAnchorResult` struct 唔變
- API 簽名唔變，向後兼容

---

## 2026-04-29  v1.10
- 加入 S/R cross-reference + Fib-SR overlap score
- S/R 整合用獨立 bool 控制
- 修復 `GetPipSize` 重複定義問題

## 2026-04-28  v1.00
- 初版：PIP 算法移植自 pip_algo_us.py
- 三種距離模式：EUC / PER / VER
