# §21.5 双仓 7 个功能 commit 映射表

Hermony NEXT 教程 §21.5「Android 应用迁移到 HarmonyOS NEXT」端到端 demo。
两条分支以 7 个功能编号一一对应：每个编号 1 个 Android Kotlin commit + 1 个 HarmonyOS ArkTS commit。

## 7 个 [feat-N] 配对

| 功能编号 | 描述 | Android commit | 鸿蒙 commit | 用户可见行为等价 |
|---|---|---|---|---|
| `[feat-1]` | 笔记列表渲染 | `d5d67097` | `7746d004` | 列表展示 ≥5 条笔记 + 标题 + 时间戳 |
| `[feat-2]` | 笔记详情页 | `1a677e38` | `780c5088` | 点击 item → 详情页 + 完整正文 + 编辑保存 |
| `[feat-3]` | RDB 持久化 | `03ecd9e8` | `46ff65b3` | 新建笔记后重启 App 仍可见 |
| `[feat-4]` | 权限申请 | `73c5f664` | `7e7a4dca` | 进通讯录功能弹权限弹窗 + 拒绝兜底 |
| `[feat-5]` | 主题切换 | `e36d67ee` | `5d5d8eb8` | 切换深色后 UI 立即变深，重启保留 |
| `[feat-6]` | 分享笔记 | `3fd2ec44` | `205b7f78` | 长按笔记 → 弹分享 sheet |
| `[feat-7]` | 设置页 | `e8a1f45f` | `4c069787` | 设置项保存 + 重启后保留 |

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
