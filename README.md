# v5-android-source — §21.5 Android 原工程

Hermony NEXT 教程 §21.5「Android 应用迁移到 HarmonyOS NEXT」配套 Android 原工程。

## 工程栈

- **Kotlin** + **Jetpack Compose**（UI）
- **Material3**（组件库）
- **Room**（持久化，feat-3 引入）
- **DataStore Preferences**（设置 / 主题持久化，feat-5/feat-7 引入）
- **Navigation Compose**（多页面，feat-2 引入）

## 7 个 [feat-N] commit 单元

与 `v5-arkts-final` 分支的 7 个鸿蒙迁移 commit 一一对应（同 `[feat-N]` 编号）：

| 编号 | 功能 | 用户可见行为 |
|---|---|---|
| `[feat-1]` | 笔记列表渲染 | LazyColumn 展示 5 条预置笔记 + 空态 |
| `[feat-2]` | 笔记详情页 | NavHost 跳转 + 编辑标题 / 正文 + 保存 |
| `[feat-3]` | RDB 持久化 | Room @Entity + DAO Flow，重启保留数据 |
| `[feat-4]` | 权限申请 | runtime CAMERA 权限 + 拒绝兜底 UI |
| `[feat-5]` | 主题切换 | values-night + setDefaultNightMode + DataStore 持久化 |
| `[feat-6]` | 分享笔记 | Intent.ACTION_SEND + Intent.createChooser |
| `[feat-7]` | 设置页 | SettingsScreen + DataStore 持久化字号 / 排序 |

每个 commit 的 hash 见 `docs/feature-commits-android.txt`。

## 构建

```bash
./gradlew :app:assembleDebug          # 真机调试包
./gradlew :app:lint                    # Lint 检查
```

> 教学项目，无 Gradle wrapper（学员请用 Android Studio 自带 wrapper 或本机 `gradle`）。

## 与鸿蒙版（v5-arkts-final）对照

```bash
# 仓内：
git log v5-android-source --grep '^\[feat-' --oneline
git log v5-arkts-final  --grep '^\[feat-' --oneline
```

完整映射表：`docs/feature-commit-map.md`（在 v5-arkts-final 分支生成）。

## tag

`v5.0.0`：与 §21.5 教程章节绑定。

---

完整 7 分支地图请见 [`main` 分支 README](https://github.com/HelloiOS2014/hermony_demo/blob/main/README.md)。
