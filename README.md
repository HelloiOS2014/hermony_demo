# v5-arkts-final — §21.5 Android 迁移后的鸿蒙工程

Hermony NEXT 教程 §21.5「Android 应用迁移到 HarmonyOS NEXT」配套鸿蒙迁移版。

基于 v1.0.0 fork，按 `v5-android-source` 分支 7 个 `[feat-N]` commit 一一对应：

- 7 个鸿蒙 commit 的 message 与 Android 仓 commit 完全对应（同 `[feat-N]` 编号）
- 每个 commit 改动 1-2 文件 + 加详细 Android↔HarmonyOS 映射注释（页面顶部大块）

## 工程栈（沿用 v1 鸿蒙工程）

- **ArkTS** + **ArkUI**（声明式 UI）
- **V1 装饰器**（@State / @Observed / @ObjectLink / @Provide / @Consume）
- **relationalStore**（持久化）
- **preferences**（用户偏好）
- **shareKit**（系统分享）
- **AbilityKit + abilityAccessCtrl**（权限）

## 7 个 `[feat-N]` commit 单元（与 v5-android-source 一一对应）

| 编号 | 功能 | Android 实现要点 | HarmonyOS 实现要点 |
|---|---|---|---|
| `[feat-1]` | 笔记列表渲染 | LazyColumn + ViewModel StateFlow | List + LazyForEach + AppStorage NoteStore |
| `[feat-2]` | 笔记详情页 | NavHost composable("detail/{id}") | Navigation + NavPathStack pushPathByName |
| `[feat-3]` | RDB 持久化 | Room @Entity + DAO Flow | relationalStore.RdbStore + 手写 SQL |
| `[feat-4]` | 权限申请 | runtime permission + 拒绝兜底 | atManager.requestPermissionsFromUser + ACL |
| `[feat-5]` | 主题切换 | values-night + setDefaultNightMode | resources/dark + setColorMode |
| `[feat-6]` | 分享笔记 | Intent.ACTION_SEND + createChooser | systemShare.ShareController + utd.UDT |
| `[feat-7]` | 设置页 | SettingsScreen + DataStore | SettingsPage + preferences |

每个 commit 的 hash 见 `docs/feature-commits-harmony.txt`。

## 双仓 commit pair

详见 [`docs/feature-commit-map.md`](./docs/feature-commit-map.md)（功能编号 / Android hash / 鸿蒙 hash 三列 + 关键 API 对照 cheat sheet）。

自动重生成：

```bash
bash scripts/cross-repo-feature-map.sh   # 输出 docs/feature-commit-map-auto.md
```

## tag

`v5.0.0`：与 §21.5 教程章节绑定。`v5-android-source` 同步打 tag。

## v5-android-source 分支

§21.5 Android 原工程，与本分支 commit 一一对应。

```bash
git checkout v5-android-source
# 用 Android Studio 打开
```

---

完整 7 分支地图请见 [`main` 分支 README](https://github.com/HelloiOS2014/hermony_demo/blob/main/README.md)。
