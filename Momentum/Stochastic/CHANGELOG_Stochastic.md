# CHANGELOG_Stochastic.md

## v1.0 — 2026-04
- 初版，由 Stochastic_SystemAlpha_2.mq5 sandbox EA 重構
- 邏輯抽出至 `Stochastic.mqh`（純 function，冇 input，冇 print）
- `StochBar` struct：儲存單 bar K/D 值
- `StochSignal` struct：crossUp, crossDown, isOB, isOS, K0/1/2, D0/1/2
- `CreateStochHandle()` — 統一 handle 初始化
- `GetStochValues()` — 取單 bar K/D
- `DetectStochSignal()` — 一次過取 bar0/1/2 並判斷 cross + OB/OS
- Cross 定義：K2<=D2 AND K1>D1（CrossUp）/ K2>=D2 AND K1<D1（CrossDown）
- `.mq5`：sub-window K/D 線 + OB/OS 水平線 + 金叉/死叉箭咀
- Journal print：中英夾雜，K值、D值、狀態、結果
- CSV log：欄位同 Sandbox EA 一致，方便對比
- Bar latch：同一根 bar 唔重複接受信號
