# Placeholder: docs/screenshots/optimized.png

模拟器 + hiTraceMeter 录制 60s 滚动 v3-perf-optimized 分支后的 DevEco Profiler 截图。

预期内容：
- 时间轴上长帧标记稀疏（绿色为主，仅个别黄色帧）
- noteList.itemBuildCount 计数曲线增长极慢（60s 累计仅约 3200）
- noteList.buildCount 计数曲线接近水平（仅 add/update 时 +1）

M8 真机批次将用真实 .png 替换本占位文件。详见 docs/perf-summary.md。
