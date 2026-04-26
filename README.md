# hermony_demo

Hermony NEXT 教程项目（[hermony 主仓](../hermony)）的端到端实战 demo 仓库。

## 7 个分支地图

| 分支 | tag | 说明 |
|---|---|---|
| `main` | - | 默认分支，指向最新（v5-arkts-final）|
| `v1-single` | `v1.0.0` | §21.1 单端笔记（ArkUI + V1 @State + RDB + 权限），含 3 处教学型性能债 |
| `v2-multidevice` | `v2.0.0` | §21.2 多端协同（v1 base + 流转 + 分布式数据 + 响应式断点）|
| `v3-perf-baseline` | `v3.0.0-baseline` | §21.3 性能优化前（与 v1 等价 + hiTraceMeter 打点）|
| `v3-perf-optimized` | `v3.0.0-optimized` | §21.3 性能优化后（修复 3 处教学型性能债）|
| `v4-test-ci` | `v4.0.0` | §21.4 测试 + CI（v2 base + Hypium + AGC pipeline yaml）|
| `v5-arkts-final` | `v5.0.0` | §21.5 Android 迁移后的鸿蒙工程 |
| `v5-android-source` | `v5.0.0` | §21.5 Android 原工程（与 v5-arkts-final commit 一一对应）|

## 使用方式

```bash
git clone git@github.com:HelloiOS2014/hermony_demo.git
cd hermony_demo
git checkout v1-single  # 或其他分支
# 用 DevEco Studio 打开（鸿蒙分支）/ Android Studio 打开（v5-android-source）
```

## 教程

每个分支对应教程站 §21.x 章节。教程仓地址 TBD。
