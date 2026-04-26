# §21.5 双仓 7 个功能 commit 映射表

Hermony NEXT 教程 §21.5「Android 应用迁移到 HarmonyOS NEXT」端到端 demo。
两条分支以 7 个功能编号一一对应：每个编号 1 个 Android Kotlin commit + 1 个 HarmonyOS ArkTS commit。

## 7 个 [feat-N] 配对

| 功能编号 | 描述 | Android commit | 鸿蒙 commit | 用户可见行为等价 |
|---|---|---|---|---|
| `[feat-1]` | 笔记列表渲染 | `d5d67097` | `7746d004` | 列表展示 ≥5 条笔记 + 标题 + 时间戳 |
| `[feat-2]` | 笔记详情页 | `1a677e38` | `780c5088` | 点击 item → 详情页 + 完整正文 + 编辑保存 |
| `[feat-3]` | RDB 持久化 | `03ecd9e8` | `46ff65b3` | 新建笔记后重启 App 仍可见 |
| `[feat-4]` | 权限申请 | `73c5f664` | `7e7a4dca` | **路径等价**（侧重权限不同，详见下方 ⚠ 说明）|
| `[feat-5]` | 主题切换 | `e36d67ee` | `5d5d8eb8` | 切换深色后 UI 立即变深，重启保留 |
| `[feat-6]` | 分享笔记 | `3fd2ec44` | `205b7f78` | 长按笔记 → 弹分享 sheet |
| `[feat-7]` | 设置页 | `e8a1f45f` | `4c069787` | **路径等价**（设置项侧重不同，详见下方 ⚠ 说明）|

## ⚠ [feat-4] / [feat-7] 实现侧重差异说明（spec §21.5 等价定义）

§21.5 实战的"等价"定义：**用户可见路径 + 教学意图相同；具体 API / 具体权限 / 具体设置项可有侧重差异**。
§19.1 / §19.2 迁移指南已统一讲过 Android↔HarmonyOS 权限 / 设置 API 映射；§21.5 聚焦"路径等价 + 拒绝兜底兜准"，
不强求逐字符 1:1 替换（那会让读者误以为"迁移就是逐行翻译"）。

### `[feat-4]` 权限申请

| | Android (`73c5f66`) | HarmonyOS (`7e7a4dc`) |
|---|---|---|
| 演示权限 | `CAMERA`（拍照笔记附件） | `READ_CONTACTS`（通讯录导入笔记联系人）|
| 路径 | `requestPermissions` → `onRequestPermissionsResult` → 拒绝兜底 UI | `atManager.requestPermissionsFromUser` → 拒绝兜底 UI |
| 路径等价点 | 用户视角：需要权限 → 弹窗 → 同意/拒绝 → 业务降级 UI | 同 |

### `[feat-7]` 设置页

| | Android (`e8a1f45`) | HarmonyOS (`4c06978`) |
|---|---|---|
| 设置项 | dark 模式 / fontScale / sortDesc | themeMode / defaultTags / syncEnabled |
| 路径 | SettingsScreen + DataStore + 重启保留 | SettingsPage + preferences + 重启保留 |
| 路径等价点 | 设置页 → 切换 → 持久化 → 重启保留 | 同 |

> **设置项侧重原因**：两端 v1 的 `UserPrefs` schema 不同（鸿蒙 v1 的 `defaultTags` / `syncEnabled` 是为 v2 多端协同铺路，
> Android 工程不需要这俩字段）。共同点：3 个设置项 + 持久化 + 重启保留这一路径完全等价。

> 完整 hash 见 `docs/feature-commits-android.txt`（Android 侧）和
> `docs/feature-commits-harmony.txt`（鸿蒙侧）。

## 校验：每个 [feat-N] 在两个分支上各仅有 1 个 commit

```bash
# 一行命令校验所有 7 个 [feat-N] 在两侧均唯一：
for n in 1 2 3 4 5 6 7; do
  a=$(git log v5-android-source --format="%H" --grep="^\[feat-$n\]" | wc -l | tr -d ' ')
  h=$(git log v5-arkts-final  --format="%H" --grep="^\[feat-$n\]" | wc -l | tr -d ' ')
  echo "feat-$n: android=$a harmony=$h (must be 1 each)"
done
```

预期输出：

```
feat-1: android=1 harmony=1 (must be 1 each)
feat-2: android=1 harmony=1 (must be 1 each)
feat-3: android=1 harmony=1 (must be 1 each)
feat-4: android=1 harmony=1 (must be 1 each)
feat-5: android=1 harmony=1 (must be 1 each)
feat-6: android=1 harmony=1 (must be 1 each)
feat-7: android=1 harmony=1 (must be 1 each)
```

## Android↔HarmonyOS 关键 API 映射汇总（教学 cheat sheet）

| 维度 | Android Kotlin | HarmonyOS ArkTS |
|---|---|---|
| 入口 | `ComponentActivity` + `setContent { ... }` | `UIAbility` + `windowStage.loadContent('MainPage')` |
| 列表 | `LazyColumn { items(list, key = {id}) {} }` | `List + LazyForEach(list, item=>..., (it)=>it.id)` |
| 状态管理 | `ViewModel` + `StateFlow` + `collectAsState` | `@Observed` + `@ObjectLink` + AppStorage |
| 路由 | `NavHost + composable("name") { ... }` | `Navigation + NavPathStack + navDestination(PageMap)` |
| 路由参数 | `navArgument("id"){ type=NavType.LongType }` | `pushPathByName(name, param)` + `getParamByName` |
| 持久化（DB） | Room `@Entity + @Dao + Flow` | `relationalStore.RdbStore` + 手写 SQL |
| 持久化（KV） | DataStore Preferences `Flow<T>` | `@ohos.data.preferences` + 手动事件分发 |
| 权限声明 | `AndroidManifest <uses-permission>` | `module.json5 requestPermissions[]` + reason |
| 权限申请 | `ActivityResultContracts.RequestPermission` | `atManager.requestPermissionsFromUser` |
| 深色主题 | `values-night/themes.xml` + `setDefaultNightMode` | `resources/dark/element/*` + `setColorMode` |
| 系统分享 | `Intent.ACTION_SEND` + `Intent.createChooser` | `systemShare.ShareController` + `utd.UDT` |
| 长按手势 | `Modifier.combinedClickable(onLongClick=..)` | `.gesture(LongPressGesture().onAction(..))` |

## 教程章节绑定

- `v5-android-source` 分支：§21.5 Android 原工程
- `v5-arkts-final` 分支：§21.5 HarmonyOS 迁移版
- 两分支均打 tag `v5.0.0`

## 自动重生成

```bash
# 在仓根执行：
bash scripts/cross-repo-feature-map.sh
# 输出 docs/feature-commit-map-auto.md（仅含 hash 表，便于 CI 校验）
```
