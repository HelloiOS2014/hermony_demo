# hermony-note-v4（§21.4 测试 + CI）

Hermony NEXT 教程站 §21.4 实战 IV 对应代码。本工程是 5 实战累积演进的第四站，
基于 **v2.0.0 fork**（含 v1 业务 + v2 多端协同），加 Hypium 测试 + UI 自动化 + AGC CI 流水线。

> v1 / v2 已 ship 业务 + 3 处教学型性能债**完整保留**（教学债是 §21.3 演示样本，
> v3-perf-* 分支负责修复，本分支不动业务代码，只加测试 + CI）。

## v4-test-ci (本分支) — 测试 + CI

基于 v2.0.0 fork，加：

- **[v4-1] Hypium 单元测试**（NoteRdb / NoteStore / UserPrefsStore）
  - 真 RDB 链路：init / insert / query / update / delete / count（NoteRdb）
  - MockKit ordinary mock：替换 NoteRdb 依赖测 NoteStore（add / update / remove / loadAll）
  - 真 Preferences 链路：roundtrip / 重启持久化 / 非法值归一 / 损坏 JSON 兜底（UserPrefsStore）
  - 异步用例统一 `done callback + try/catch + done(error) + timeout 10000`
    （见 hermony §16.5 反例 1：默认 5s 在 CI 不够 / 异常路径漏 done 撑爆超时）
  - jacoco 覆盖率门槛：`data/** ≥ 80% line` / `utils/** ≥ 50% line`
  - `module.json5` 加 testRunner 配置 + `build-profile.json5` 加 testCompileMode = mixed
- **[v4-2] UI 自动化**（driver.findComponent + click + assertVisible）
  - 4 个用例：list_page 渲染（LEVEL0 smoke）/ click_fab 跳转详情（LEVEL0）
    / long_press 触发分享（LEVEL1 regression）/ click_gear 进设置页（LEVEL1）
  - `retryOnFlaky` helper：仅对 component-not-found / timeout retry 上限 2 次，
    业务 assertion fail / crash 一律不 retry（见 §16.5b 反模式 A）
  - `TestType.FUNCTION | Level.LEVEL0/LEVEL1 | Size.SMALLTEST/MEDIUMTEST` 三件套分级
- **[v4-3] .agc-pipeline.yaml**（6 阶段 CI）
  - lint → test（jacoco 门禁）→ build（mktemp + chmod 600 + trap rm）
    → sign（独立阶段便于回查）→ distribute（manual gate）→ ui-test（4 路 sharding 并行）
  - 失败 dual channel 通知：飞书 webhook + 邮件
  - 触发规则：`on_push` 跑到 sign / `on_schedule` cron 0 2 * * * 跑 ui-test / `on_tag` 全流水线
- **[v4-4] 制品 hash + AGC Hosting 链接**（`docs/`，mock 数据）
  - `docs/artifact-hash.txt`：mock sha256 + 构建 / 签名命令（M8 真机批次替换为真实 hash）
  - `docs/agc-hosting-link.txt`：mock AGC 链接 + 灰度计划（5% → 5% → 20% → 50% → 100%）
    + 回滚预案（rollback_target = v3.0.0-optimized）
- **[v4-5] README 更新**（本文件）

## CI 凭证依赖

`.agc-pipeline.yaml` 用 4 个签名相关环境变量 + 2 个发布 / 通知变量：

| 变量名 | 用途 | 来源 |
|---|---|---|
| `KEYSTORE_BASE64` | release.p12 base64（`cat release.p12 \| base64`）| AGC pipeline Secret |
| `KEYSTORE_PWD`    | keystore 主密码 | AGC pipeline Secret |
| `KEY_ALIAS`       | 签名 key alias | AGC pipeline Secret |
| `KEY_PWD`         | 签名 key 密码 | AGC pipeline Secret |
| `AGC_TOKEN`       | AGC Hosting 上传 token | AGC console → API token |
| `FEISHU_BOT_URL`  | 失败通知飞书机器人 webhook | 飞书机器人配置 |

CI 凭证准备清单详见 hermony 主仓 `docs/superpowers/practice/m7-ci-credentials-checklist.md`
（含 keystore 生成命令 / AGC API token 申请路径 / 飞书机器人创建路径 / 双 admin
变更 RELEASE_KEYSTORE_BASE64 的工作流约束）。

> ⚠️ **永远不要把 keystore 文件 commit 进仓库**，即使加了 `.gitignore` 注释——文件已经在
> git 历史里就永远在历史里，任何拿到仓库 read 权限的人都能翻出来。修复方式见 hermony §16.6
> "keystore commit 误入" 反例。

## tag 说明

- `v1.0.0`：单端笔记基线（v1-single 分支），含 3 处教学型性能债，对应 §21.1
- `v2.0.0`：多端协同版（v2-multidevice 分支），加响应式 / 流转 / 分布式同步，对应 §21.2
- `v3.0.0-baseline`：性能基线版（v3-perf-baseline 分支），与 v1 等价 + hiTraceMeter 打点占位，对应 §21.3 baseline；
  `v3.0.0-optimized`：性能优化版（v3-perf-optimized 分支），修教学债 #1/#2/#3，对应 §21.3 optimized
- `v4.0.0`：**测试 + CI 版本**（**本分支**），加 Hypium 测试 + UI 自动化 + .agc-pipeline.yaml，
  对应 **§21.4 教程章节**。controller 在 5 个 `[v4-X]` commit + push 之后打 tag。
- `v5.0.0`：跨平台版（v5-arkts-final 分支），对应 §21.5

## 跑通方式（CI 流水线本地预演）

```bash
git clone git@github.com:HelloiOS2014/hermony_demo.git
cd hermony_demo
git checkout v4-test-ci

# 单元测试（debug 包测试制品）
hvigorw test --coverage --mode debug
# 覆盖率报告：entry/build/default/outputs/test/jacoco-report.html

# UI 自动化（smoke，单台模拟器或真机）
hvigorw uitest --filter "TestCaseLevel=LEVEL0"

# 完整流水线（CI 跑，本地需配 KEYSTORE_BASE64 等环境变量）
# 见 .agc-pipeline.yaml stages 节
```

---

## v2-multidevice (上游分支) — 多端协同

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

## fork 关系（v2-multidevice）

- 本分支基于 v1.0.0 tag（v1-single 分支）
- 7 个 `[feat-N]` commit 来自 v1（业务全保留）
- v2 增量 commit 用 `[v2-X]` 前缀（5 个）

## fork 关系（v4-test-ci）

- v4-test-ci 分支基于 **v2.0.0 tag** fork（v1 + v2 业务全保留）
- 5 个 `[v4-X]` commit 不动 v1 / v2 业务代码，只加测试 + CI
- v4 修改清单（仅本分支独有）：
  - 新增 `entry/src/test/` 目录（5 个 .ets 文件：Note.test / UserPrefs.test / UiTestList.test
    / UiTestAbility / OhosTestRunner + List.test 入口）
  - 修 `entry/src/main/module.json5` 加 testRunner 配置
  - 修 `entry/build-profile.json5` 加 testCompileMode = mixed + jacoco 阈值
  - 新增 `.agc-pipeline.yaml`（仓库根）
  - 新增 `docs/artifact-hash.txt` + `docs/agc-hosting-link.txt`

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
