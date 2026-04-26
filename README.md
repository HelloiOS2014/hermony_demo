# hermony-note-v2（§21.2 多端协同）

Hermony NEXT 教程站 §21.2 实战 II 对应代码。本工程是 5 实战累积演进的第二站，
基于 v1.0.0 fork 加多端协同能力。

> v1 已 ship 的 7 处 `[feat-N]` 业务和 3 处教学型性能债**完整保留**（教学债是
> §21.3 演示样本，与 v2 多端能力解耦，不在 v2 修复范围内）。

## v2-multidevice (本分支) — 多端协同

基于 v1 fork，加：

- **响应式断点**（GridRow / GridCol / sm/md/lg/xl）：手机竖屏 1 列、平板 2 列、
  2in1 3 列、超大屏 4 列；GridRow 只改列轨道，LazyForEach 子节点不重建
- **自由流转**（continueAbility / onContinue / onSaveState）：在编辑笔记时调
  系统流转入口，对端拉起同名 Ability 的 onCreate 接续编辑
- **分布式数据**（distributedDataObject）：DistributedNoteStore.ets 新增，
  setSessionId 加入会话后跨设备同步整个 notes 数组 + onChange 监听对端变更
- **设置页同步开关**：v1 灰显的开关在 v2 启用，默认 false；用户主动开启 →
  joinSession + 把本地笔记 mirror 给对端；UserPrefs 持久化，重启后自动 rejoin
- **module.json5 加 distributedDatasync 权限**：软总线通信放行

## fork 关系

- 本分支基于 v1.0.0 tag（v1-single 分支）
- 7 个 `[feat-N]` commit 来自 v1（业务全保留）
- v2 增量 commit 用 `[v2-X]` 前缀（5 个）

## 5 个 `[v2-X]` 增量 commit

| 编号 | 增量 | 引入 / 改动 |
|---|---|---|
| `[v2-1]` | 响应式断点 | NoteListPage 加 GridRow / GridCol（sm/md/lg/xl）|
| `[v2-2]` | 自由流转 | EntryAbility.onContinue / onSaveState + NoteDetailPage 镜像编辑态到 AppStorage |
| `[v2-3]` | 分布式数据 | DistributedNoteStore.ets 新增（distributedDataObject + setSessionId + onChange）+ Note* 页面调 mirrorLocalToRemote |
| `[v2-4]` | 设置页同步开关 | SettingsPage 同步开关启用 + applySyncToggle 调 join/leaveSession |
| `[v2-5]` | 权限 | module.json5 加 `ohos.permission.DISTRIBUTED_DATASYNC` |

## v2 增量架构图（ASCII）

```
┌────────────────────────────────────────────────────────────────┐
│ UI 层（v1 不变 + v2 加响应式）                                   │
│   MainPage（NavPathStack）                                      │
│     ├── NoteListPage   GridRow + GridCol + LazyForEach (v2)    │
│     ├── NoteDetailPage TextArea + 镜像编辑态到 AppStorage (v2)  │
│     └── SettingsPage   同步开关启用 (v2)                         │
└────────────────────────────────────────────────────────────────┘
                                │
              ┌─────────────────┴────────────────┐
              ▼                                  ▼
┌──────────────────────────┐     ┌────────────────────────────────┐
│ NoteStore（v1 不变）      │     │ DistributedNoteStore (v2 新增) │
│   RDB 持久化（真源）       │←────│   distributedDataObject        │
│   含教学债 #3              │     │   setSessionId / on('change')  │
└──────────────────────────┘     └────────────────────────────────┘
                                                │
                                                ▼
                                  鸿蒙分布式软总线（直连优先）
                                                │
                                                ▼
                                          其他鸿蒙设备
```

## v2 数据流图（流转 + 分布式同步）

```
┌──────────────────────────────────────────────────────────────┐
│  自由流转（用户主动发起，A 端 → B 端）                          │
└──────────────────────────────────────────────────────────────┘

[A 端用户在 NoteDetailPage 编辑]
       │
       │ TextArea.onChange → NoteDetailPage.mirrorEditingState()
       ▼
AppStorage[CONTINUED_DRAFT_KEY] = ContinuedDraft 草稿镜像
       │
       │ 用户在通知中心 / 多设备菜单选"流转到 B"
       ▼
EntryAbility.onContinue（系统调）
       │  读 AppStorage[CONTINUED_DRAFT_KEY] → wantParam[*]
       │  tags 用 JSON.stringify 序列化（绕开嵌套数组限制）
       │  return AGREE
       ▼
鸿蒙分布式软总线：把 wantParam 送到 B 端
       │
       ▼
B 端 EntryAbility.onCreate（launchReason = CONTINUATION）
       │  parseContinuedDraft(want) → ContinuedDraft
       │  AppStorage.setOrCreate(CONTINUED_DRAFT_KEY, draft)
       ▼
B 端 NoteDetailPage.aboutToAppear 优先读 CONTINUED_DRAFT_KEY
       │  banner 提示"已从其他设备接续，保存后会落到本机 RDB"
       ▼
[B 端用户接着改 → 保存 → store.add/update + mirrorLocalToRemote]


┌──────────────────────────────────────────────────────────────┐
│  分布式数据同步（用户开启同步开关后，A ⇄ B 双向）              │
└──────────────────────────────────────────────────────────────┘

[A 端 SettingsPage 开关 syncEnabled = true]
       │
       ▼
DistributedNoteStore.joinSession('hermony_notes_session', listener)
       │
       │ obj = distributedObject.create(ctx, initialState)
       │ obj.setSessionId('hermony_notes_session')
       │ obj.on('change', cb) / obj.on('status', cb)
       ▼
A 端的 obj.notes = NoteStore.snapshot()  ← mirrorLocalToRemote
       │
       │ 软总线 fan-out（同 sessionId 设备订阅同一份数据）
       ▼
B 端 obj.on('change') 触发  → fields = ['notes', 'totalCount', ...]
       │
       │ DistributedNoteStore.applyRemoteToLocal(obj.notes)
       │   suppressMirror = true（防回灌循环）
       │   遍历 remoteNotes：本地无 → store.add；updatedAt 更新 → store.update
       ▼
NoteListPage.aboutToAppear 注册的 listener.onChange
       │
       │ this.notes = await store.loadAll() + dataSource.setData
       ▼
LazyForEach 重新渲染（仍走 v1 IDataSource，对应教学债 #3 整列表 reload）
```

## 教学型性能债清单（v1 起保留至 §21.3 演示）

v1 的 3 处教学债**在 v2 完整保留**，原因：

1. 教学债是 §21.3 性能优化章节的演示样本（v3 fork 自 v2，再演示修复）
2. v2 多端能力（响应式 / 流转 / 分布式）与渲染性能债解耦，分别教学
3. 强行在 v2 修复会造成"演示路径被踩"——§21.3 教程拿不到 baseline 数据

参见 v1 README 内"教学型性能债清单"段（git show v1.0.0:README.md）：

- 教学债 #1：LazyForEach keyGenerator 用 index（NoteListPage.ets）
- 教学债 #2：abilityAccessCtrl 监听器漏对称解绑（NoteListPage.ets / Permissions.ets）
- 教学债 #3：V1 @State + 整对象写（NoteStore.ets / NoteListPage.ets）

注意：v2 新增的 DistributedNoteStore **不**沿用教学债 #3——distributedDataObject
的同步层本身就要求 set 整字段（push 在部分系统版本下不一定触发 fan-out），
这是 API 约束而非"教学债"。

## tag 说明

- `v1.0.0`：单端笔记基线（v1-single 分支），含 3 处教学型性能债，对应 §21.1
- `v2.0.0`：多端协同版（v2-multidevice 分支），加响应式 / 流转 / 分布式同步，
  对应 §21.2 教程章节。controller 在 subagent 完成 5 个 `[v2-X]` commit + push
  之后打 tag。

## 跑通方式（双设备演示）

```bash
git clone git@github.com:HelloiOS2014/hermony_demo.git
cd hermony_demo
git checkout v2-multidevice
# 用 DevEco Studio 5.x 打开（File → Open → 选 hermony_demo 根目录）
# 真机推荐：1 手机 + 1 平板（同 WLAN + 同账号），HUAWEI Share P2P 也可
# 模拟器：DevEco Previewer 单设备测响应式断点 + 单端流转 / 分布式 API 调用
```

## 教程章节对应关系

| 章节 | 引用本仓 |
|---|---|
| §21.2 | v2.0.0 全部代码（含 v1 + v2 增量）|
| §21.3 | v3-perf-baseline / v3-perf-optimized 基于 v2 fork（教学债延续到 v3）|
| §21.4 | v4-test-ci 基于 v2 fork |
| §9.4 自由流转 | EntryAbility.onContinue / onSaveState 是教程 §9.4 snippet 的实战版 |
| §9.5 分布式数据对象 | DistributedNoteStore.ets 是教程 §9.5 snippet 的实战版 |
