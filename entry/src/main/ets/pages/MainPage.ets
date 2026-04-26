// MainPage — Navigation 容器（NavPathStack）
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
