# CHANGELOG_FibOptB.md

## 2026-05-04  v1.01

### Fibonacci_M5_OptB.mq5
- 改用 ANCHOR_H1 評分邏輯代替 ANCHOR_M5 距離優先
  - 原因：移除鎖定後 ANCHOR_M5 搵到太多細 range 雜音錨點
  - ANCHOR_H1 用波段完整性 + S/R 強度評分，喺 96 bars 窗口揀最適合配對
- InpMinRangePips 預設值由 5.0 改返 10.0

### Fibonacci_PIP_OptB.mq5
- 唔再 call GetAnchorPoints_PIP()
  - 原因：直接用 CalcPIPPoints() 隔離更清晰，唔受 FibPIP.mqh 版本影響
- 直接 call CalcPIPPoints() 搵 PIP 轉角點，再自己取最高/最低做錨點
- 冇方向性驗證，忠實於原版 pip_algo_us.py

---

## 2026-05-04  v1.00
- 初版 Option B：移除鎖定機制，每 bar 重新計錨點
