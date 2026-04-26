# Placeholder: docs/screenshots/baseline.png

模拟器 + hiTraceMeter 录制 60s 滚动 v3-perf-baseline 分支后的 DevEco Profiler 截图。

预期内容：
- 时间轴上密集橙色 / 红色长帧标记（> 16.6ms）
- noteList.itemBuildCount 计数曲线快速增长（60s 累计约 642000）
- noteList.buildCount 计数曲线明显跳点（每次 add/update 都触发整列表 build）

M8 真机批次将用真实 .png 替换本占位文件。详见 docs/perf-summary.md。
