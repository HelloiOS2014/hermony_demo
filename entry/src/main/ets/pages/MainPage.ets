// MainPage — Navigation 容器（NavPathStack）
//
// §21.5 [feat-2] 迁移注释：
//   Android 一侧的路由表写在 MainActivity 的 NavHost 里：
//       NavHost(navController = nav, startDestination = "list") {
//         composable("list")               { NoteListScreen(...) }
//         composable("detail/{id}")        { NoteDetailScreen(...) }
//         composable("settings")           { SettingsScreen(...) }   // [feat-7]
//       }
//   HarmonyOS NEXT 由 Navigation + NavPathStack + @Builder PageMap 表达：
//       Navigation(this.navPathStack) { NoteListPage() }              // 默认目的地
//         .navDestination(this.PageMap)                               // name → 组件
//   两边在概念上完全对应：startDestination ↔ 默认子组件，
//   composable("name") ↔ PageMap 的 if 分支。
//
// 路由结构：
//   NoteListPage（默认）
//   ├── NoteDetailPage  参数 { noteId: string }
//   └── SettingsPage

import { NoteListPage } from './NoteListPage'
import { NoteDetailPage } from './NoteDetailPage'
import { SettingsPage } from './SettingsPage'

@Entry
@Component
struct MainPage {
  @Provide('navPathStack') navPathStack: NavPathStack = new NavPathStack()

  // 三个 NavDestination 都用 Builder 形式注册到 Navigation.navDestination
  @Builder
  PageMap(name: string) {
    if (name === 'NoteDetailPage') {
      NoteDetailPage()
    } else if (name === 'SettingsPage') {
      SettingsPage()
    }
  }

  build() {
    Navigation(this.navPathStack) {
      // 默认页内容：直接渲染 NoteListPage
      NoteListPage()
    }
    .title($r('app.string.title_note_list'))
    .titleMode(NavigationTitleMode.Mini)
    .mode(NavigationMode.Stack)
    .navDestination(this.PageMap)
    .hideTitleBar(true)
  }
}
