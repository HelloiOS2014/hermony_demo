// SettingsPage — 设置页
//
// 三项设置：
//   1. themeMode  light / dark / system  → 立即应用 + UserPrefs.flush()
//   2. defaultTags 逗号分隔输入框，新建笔记时会预填
//   3. syncEnabled v2-multidevice 起：默认 false；用户开启后调用
//      DistributedNoteStore.joinSession 加入分布式会话（关闭走 leaveSession）

import { UserPrefs } from '../data/Note'
import { UserPrefsStore } from '../data/UserPrefsStore'
import { ConfigurationConstant, common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  DistributedNoteStore,
  DISTRIBUTED_STORE_KEY,
  DistributedSyncListener
} from '../data/DistributedNoteStore'

// v2-multidevice：sessionId 简化为常量（demo 无账号体系）
// 真实业务请用 `<userId>_notes` 这种业务级唯一标识
const SYNC_SESSION_ID = 'hermony_notes_session'

@Component
export struct SettingsPage {
  @Consume('navPathStack') navPathStack: NavPathStack
  @State themeMode: 'light' | 'dark' | 'system' = 'system'
  @State defaultTagsText: string = ''
  @State syncEnabled: boolean = false
  @State loading: boolean = true

  async aboutToAppear(): Promise<void> {
    const store = AppStorage.get<UserPrefsStore>('userPrefsStore')
    if (store !== undefined) {
      const prefs = await store.load()
      this.themeMode = prefs.themeMode
      this.defaultTagsText = prefs.defaultTags.join(',')
      this.syncEnabled = prefs.syncEnabled
    }
    this.loading = false
  }

  private async persist(): Promise<void> {
    const store = AppStorage.get<UserPrefsStore>('userPrefsStore')
    if (store === undefined) {
      return
    }
    const tags = this.defaultTagsText
      .split(/[,，]/)
      .map((t) => t.trim())
      .filter((t) => t.length > 0)
    const next: UserPrefs = {
      themeMode: this.themeMode,
      defaultTags: tags,
      syncEnabled: this.syncEnabled
    }
    await store.save(next)
    AppStorage.setOrCreate('themeMode', this.themeMode)
  }

  // v2-multidevice：同步开关切换 → 调用分布式 store 加入 / 退出会话
  // 开启 → joinSession + 把本地笔记 mirror 给对端
  // 关闭 → leaveSession（本地缓存保留，但不再 fan-out）
  private applySyncToggle(on: boolean): void {
    const distStore = AppStorage.get<DistributedNoteStore>(DISTRIBUTED_STORE_KEY)
    if (distStore === undefined) {
      promptAction.showToast({ message: '分布式 store 未初始化', duration: 1500 })
      return
    }
    if (on) {
      const listener: DistributedSyncListener = {
        onChange: (_notes, _fields) => {
          // 设置页本身不消费 onChange；列表页 aboutToAppear 会重绑 listener
        },
        onStatus: (_id, _status) => {}
      }
      distStore.joinSession(SYNC_SESSION_ID, listener)
      distStore.mirrorLocalToRemote()
      promptAction.showToast({ message: '同步已开启', duration: 1500 })
    } else {
      distStore.leaveSession()
      promptAction.showToast({ message: '同步已关闭', duration: 1500 })
    }
  }

  private applyColorMode(mode: 'light' | 'dark' | 'system'): void {
    let target: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
    if (mode === 'light') {
      target = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
    } else if (mode === 'dark') {
      target = ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    }
    const ctx = getContext(this) as common.UIAbilityContext
    ctx.getApplicationContext().setColorMode(target)
  }

  @Builder
  ThemeRow(label: string, value: 'light' | 'dark' | 'system') {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.primary_text'))
        .layoutWeight(1)
      if (this.themeMode === value) {
        Text('✓')
          .fontSize(18)
          .fontColor($r('app.color.accent'))
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick(async () => {
      this.themeMode = value
      this.applyColorMode(value)
      await this.persist()
      promptAction.showToast({ message: '主题已切换', duration: 1000 })
    })
  }

  build() {
    NavDestination() {
      Column() {
        // Top bar
        Row() {
          Text('‹ 返回')
            .fontSize(16)
            .fontColor($r('app.color.accent'))
            .padding(8)
            .onClick(() => this.navPathStack.pop())
          Blank()
          Text($r('app.string.title_settings'))
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
          Blank()
          // 占位保持视觉对称
          Text('   ').padding(8)
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })

        if (this.loading) {
          LoadingProgress()
            .width(40)
            .height(40)
            .margin({ top: 80 })
        } else {
          Scroll() {
            Column({ space: 16 }) {
              // 主题
              Column() {
                Text($r('app.string.settings_theme'))
                  .fontSize(13)
                  .fontColor($r('app.color.secondary_text'))
                  .width('100%')
                  .padding({ left: 16, top: 12, bottom: 8 })
                Column() {
                  this.ThemeRow('跟随系统', 'system')
                  Divider().strokeWidth(0.3).color($r('app.color.secondary_text')).opacity(0.3)
                    .margin({ left: 16, right: 16 })
                  this.ThemeRow('浅色', 'light')
                  Divider().strokeWidth(0.3).color($r('app.color.secondary_text')).opacity(0.3)
                    .margin({ left: 16, right: 16 })
                  this.ThemeRow('深色', 'dark')
                }
                .width('100%')
                .backgroundColor($r('app.color.card_background'))
                .borderRadius(12)
              }

              // 默认标签
              Column() {
                Text($r('app.string.settings_default_tags'))
                  .fontSize(13)
                  .fontColor($r('app.color.secondary_text'))
                  .width('100%')
                  .padding({ left: 16, top: 4, bottom: 8 })
                TextInput({ placeholder: '逗号分隔，例：工作,日记', text: this.defaultTagsText })
                  .fontSize(15)
                  .backgroundColor($r('app.color.card_background'))
                  .borderRadius(12)
                  .padding(16)
                  .onChange((v) => {
                    this.defaultTagsText = v
                  })
                  .onBlur(() => {
                    this.persist()
                  })
              }

              // 同步开关（v2-multidevice 启用）
              // 默认 false：用户主动开启后才加入分布式会话；UserPrefs 持久化，
              // 重启后 EntryAbility.onCreate 会按持久化值自动 rejoin（见 EntryAbility）
              Column() {
                Text($r('app.string.settings_sync'))
                  .fontSize(13)
                  .fontColor($r('app.color.secondary_text'))
                  .width('100%')
                  .padding({ left: 16, top: 4, bottom: 8 })
                Row() {
                  Column({ space: 2 }) {
                    Text('多端同步')
                      .fontSize(15)
                      .fontColor($r('app.color.primary_text'))
                      .width('100%')
                    Text(this.syncEnabled
                      ? 'distributedDataObject 已加入会话'
                      : '关闭中（默认）；开启后笔记跨设备同步')
                      .fontSize(11)
                      .fontColor($r('app.color.secondary_text'))
                      .width('100%')
                  }
                  .layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: this.syncEnabled })
                    .onChange(async (on) => {
                      this.syncEnabled = on
                      await this.persist()
                      this.applySyncToggle(on)
                    })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .backgroundColor($r('app.color.card_background'))
                .borderRadius(12)
              }
            }
            .padding({ left: 16, right: 16, top: 8, bottom: 24 })
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
    }
    .title($r('app.string.title_settings'))
    .hideTitleBar(true)
  }
}
