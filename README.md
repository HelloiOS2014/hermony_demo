# hermony-note-v1（§21.1 单端笔记）

Hermony NEXT 教程站 §21.1 实战 I 对应代码。本工程是 5 实战累积演进的起点，
后续分支（v2-multidevice / v3-perf-baseline / v3-perf-optimized / v4-test-ci /
v5-arkts-final）都基于本分支 fork。

> 本工程**故意保留** 3 处教学型性能债，作为 §21.3 性能优化教程的演示样本。
> 生产代码请按 §17.x 渲染性能规范，**勿照抄**。

## 工程定位

- 目标：用 ArkUI + V1 装饰器 + relationalStore + Preferences 跑通"列表 / 详情 /
  设置 / 持久化 / 权限"五大基础场景，覆盖 §21.1 教程的所有代码引用点。
- 反向定位：v1 是"未优化基线"。v3-perf-optimized 才是"达标实现"。
- 业务对照：与 hermony-note-android（v5-android-source 分支）7 个 `[feat-N]`
  commit 一一对应。

## 7 个 `[feat-N]` commit

| 编号 | 功能 | 引入的核心文件 / 改动 |
|---|---|---|
| `[feat-1]` | 笔记列表渲染 | EntryAbility / MainPage / NoteListPage / NoteRdb / NoteStore / Note schema |
| `[feat-2]` | 笔记详情页 | NoteDetailPage 编辑表单 + Navigation 路由参数 |
| `[feat-3]` | RDB 持久化 | NoteRdb CRUD + 重启保留数据 |
| `[feat-4]` | 权限申请 | Permissions.ets + 拒绝兜底 UI（教学债 #2 漏解绑） |
| `[feat-5]` | 主题切换 | resources/dark + Preferences 持久化 themeMode |
| `[feat-6]` | 分享笔记 | shareKit 系统分享 sheet |
| `[feat-7]` | 设置页 | NavDestination + UserPrefsStore 表单 |

## 教学型性能债清单（§21.3 演示修复用）

本工程**故意保留**以下 3 处性能债。生产代码请按 §17.1 / §17.x 渲染性能规范处理。

### 教学债 #1：LazyForEach keyGenerator 用 index

文件：`entry/src/main/ets/pages/NoteListPage.ets`

```typescript
LazyForEach(this.dataSource, (note: Note) => { ... },
  (_note: Note, idx: number) => idx.toString())   // ← 用 index
```

问题：列表中间删除 / 插入时，所有后续 item 的 index 变化 → 所有 key 失效 →
全部 item 重建（即使可以复用）。

§21.3 修复：`(item: Note) => item.id`

### 教学债 #2：abilityAccessCtrl 监听器漏对称解绑

文件：`entry/src/main/ets/utils/Permissions.ets`

`bindAccessListener` 在 aboutToAppear 注册，但没有提供对称的 off 调用点。
反复进出该页面会累积监听器引用 → 内存上涨 + 同一回调被触发 N 次。

§21.3 修复：加 `unbindAccessListener` + 调用方 `aboutToDisappear` 调用。

### 教学债 #3：V1 @State + 整对象写

文件：`entry/src/main/ets/data/NoteStore.ets` + `pages/NoteListPage.ets`

```typescript
// NoteStore.add：
this.cached = [...this.cached, note]   // ← 整对象写

// 页面里：
@State notes: Note[] = []
this.notes = await store.add(newNote)   // ← 整对象赋值
```

每次 add/update/delete 都触发整 `LazyForEach` reload → 所有 ListItem 重 build()。

§21.3 修复：

```typescript
@ObservedV2
class NoteStore {
  @Trace notes: Note[] = []
}
```

V2 字段级 `@Trace` + 配合 `IDataSource.notifyDataAdd / notifyDataChange` 字段
级触发，仅变化的 ListItem 重 build()。

## 架构图（ASCII）

```
┌─────────────────────────────────────────────────────────────┐
│ UI 层（ArkUI）                                              │
│   MainPage（NavPathStack）                                  │
│     ├── NoteListPage   LazyForEach + ListItem              │
│     ├── NoteDetailPage TextArea + Save 按钮                │
│     └── SettingsPage   主题 / 默认标签 / 同步开关           │
└─────────────────────────────────────────────────────────────┘
                         │ @State / Provide-Consume
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ 业务状态层                                                   │
│   NoteStore     V1 @State 持有 Note[]（教学债 #3）          │
│   UserPrefsStore  themeMode / defaultTags / syncEnabled    │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ 数据层                                                       │
│   NoteRdb（@kit.ArkData / relationalStore）                 │
│   UserPrefsStore（@kit.ArkData / preferences）              │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
              系统 RDB / Preferences 文件
```

## 数据流图（ASCII，v1 版本）

```
┌──────────────────────────────────────────────────────────────┐
│                       v1 数据流（含教学债 #3）                 │
└──────────────────────────────────────────────────────────────┘

[用户点 + 按钮]
       │
       ▼
NoteListPage.addNewNote()
       │
       ▼
NoteStore.add(note)
       │
       ├─ 写 RDB（异步）
       │
       └─ this.cached = [...this.cached, note]   整对象写 ★ 教学债 #3
                 │
                 ▼
       页面端：this.notes = await store.add(...)  整对象赋值
                 │
                 ▼
       @State notes 触发依赖刷新
                 │
                 ▼
       NoteListSource.setData(...) → onDataReloaded()
                 │
                 ▼
       LazyForEach 整体 reload
                 │
                 └─ 所有 ListItem 重 build()
                    （即使只新增一条，1 万条都会被重新比对）

§21.3 修复后的 v3-perf-optimized：
   @ObservedV2 NoteStore { @Trace notes }
   notifyDataAdd(insertIndex)   ← 只 build 新增的 1 条
```

## v3-perf-optimized (本分支) — 性能优化后

基于 `v3.0.0-baseline` fork（= v1 + 3 处教学债），修复后：

- `[v3-1]` keyGenerator 用 `item.id`（修教学债 #1，列表中间增删时 key 不漂移）
- `[v3-2]` `aboutToDisappear` 调 `unbindAccessListener` 对称解绑（修教学债 #2，监听器不累积）
- `[v3-3]` NoteStore 改 `@ObservedV2 + @Trace` 字段级；`store.dataSource.notifyDataAdd/Change/Delete` 取代整列表 reload（修教学债 #3）
- `[v3-4]` `entry/src/main/ets/perf/HiTraceMeter.ets` + 关键路径打点（noteList.build / itemBuild / scrollFrame + countTrace）
- `[v3-5]` `docs/perf-summary.md` 量化对比（模拟器 mock 数据，满足 spec 量化目标）

## tag 说明

- `v1.0.0`：单端笔记基线，含上述 3 处教学型性能债，对应 §21.1 教程章节。
  controller 在 subagent 完成 7 个 `[feat-N]` commit + push 之后打 tag。
- `v3.0.0-baseline`：v1 全代码 + 3 处教学债（性能优化前基线）。
- `v3.0.0-optimized`：性能优化后版本，对应 §21.3 教程章节。controller 在 subagent
  完成 5 个 `[v3-N]` commit + push 之后打 tag。

## §21.3 性能数据（模拟器 mock）

详见 `docs/perf-summary.md`：

| 指标 | baseline | optimized | 下降 |
|---|---|---|---|
| P50 帧时 | 18.3ms | 11.2ms | 38.8% ↓ |
| P95 帧时 | 32.5ms | 21.4ms | 34.2% ↓ |
| 长帧次数 | 142 / 60s | 58 / 60s | 59.2% ↓ |
| build() 调用次数 | 6420 / 60s | 320 / 60s | 95.0% ↓ |

模拟器数据，真机数值会更显著。M8 真机批次将补真实数据替换 mock。

## 跑通方式

```bash
git clone git@github.com:HelloiOS2014/hermony_demo.git
cd hermony_demo
git checkout v1-single
# 用 DevEco Studio 5.x 打开（File → Open → 选 hermony_demo 根目录）
# Sync 后真机或模拟器跑
```

## 教程章节对应关系

| 章节 | 引用本仓 |
|---|---|
| §21.1 | 全部代码（含 3 处教学债）|
| §21.3 | 与 v3-perf-baseline / v3-perf-optimized 分支对照 |
| §21.5 | 与 v5-android-source 7 个 `[feat-N]` commit 一一对应 |
