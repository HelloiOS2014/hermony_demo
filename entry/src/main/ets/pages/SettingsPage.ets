// SettingsPage — 设置页
//
// 三项设置：
//   1. themeMode  light / dark / system  → 立即应用 + UserPrefs.flush()
//   2. defaultTags 逗号分隔输入框，新建笔记时会预填
//   3. syncEnabled v1 默认关闭 + 灰显（v2-multidevice 起接 distributedDataObject）
//
// ╔══════════════════════════════════════════════════════════════════════╗
// ║ §21.5 [feat-7] Android → HarmonyOS NEXT 迁移要点                      ║
// ╠══════════════════════════════════════════════════════════════════════╣
// ║ Android 原工程（v5-android-source 分支 [feat-7]）                     ║
// ║   - ui/SettingsScreen.kt：                                            ║
// ║       SettingsViewModel(AndroidViewModel) 暴露 darkMode/fontScale/    ║
// ║       sortDesc 三个 StateFlow                                          ║
// ║   - SwitchRow（Material3 Switch）+ SliderRow（Slider 0.85~1.30 步进） ║
// ║   - DataStore Preferences 即时写入，重启保留                          ║
// ║   - NavHost composable("settings") 注册                              ║
// ║                                                                      ║
// ║ HarmonyOS 对应实现（本文件）                                          ║
// ║   - 通过 navPathStack.pushPathByName('SettingsPage') 进入             ║
// ║   - 直接调用 UserPrefsStore.set...() / flush() 持久化                 ║
// ║   - Toggle / TextInput / Button 组合 ArkUI 组件                       ║
// ║   - 主题切换走 UIAbility.context.setColorMode（见 [feat-5]）         ║
// ║                                                                      ║
// ║ 关键映射                                                              ║
// ║   PreferenceFragmentCompat（旧）/ SettingsScreen Composable           ║
// ║       ↔  @Component SettingsPage                                      ║
// ║   ViewModel + StateFlow                                               ║
// ║       ↔  @State + UserPrefsStore（手动 read 然后 flush）              ║
// ║   Material3 Switch                                                    ║
// ║       ↔  Toggle({ type: ToggleType.Switch })                          ║
// ║   Material3 Slider                                                    ║
// ║       ↔  Slider({ value, min, max, step })                            ║
// ║   NavHost composable("settings")                                      ║
// ║       ↔  Navigation + navDestination + PageMap('SettingsPage')        ║
// ║   DataStore Preferences (suspend write)                               ║
// ║       ↔  preferences.put + preferences.flush                          ║
// ║                                                                      ║
// ║ 注意点（迁移踩坑）                                                    ║
// ║   1. DataStore 写入在 Coroutine 内自动 fsync；ArkTS preferences 必须    ║
// ║      显式 await flush()，否则进程崩溃可能丢数据                       ║
// ║   2. Compose 重组细粒度（rememberSaveable + StateFlow）；ArkTS @State ║
// ║      字段级触发也很轻，但跨组件共享要走 AppStorage / @Provide-@Consume║
// ║   3. Slider valueRange Float vs Number：鸿蒙 Slider 的 step 不会自动  ║
// ║      取整，UI 显示时需要 Math.round(*100)/100 防抖                     ║
// ║   4. v1 鸿蒙 SettingsPage 多了 syncEnabled（v2 起启用），              ║
// ║      Android 一侧 §21.5 demo 没做这一项（v5 不涉及多端协同）           ║
// ╚══════════════════════════════════════════════════════════════════════╝

import { UserPrefs } from '../data/Note'
import { UserPrefsStore } from '../data/UserPrefsStore'
import { ConfigurationConstant, common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'

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

              // 同步开关（v1 灰显）
              Column() {
                Text($r('app.string.settings_sync'))
                  .fontSize(13)
                  .fontColor($r('app.color.secondary_text'))
                  .width('100%')
                  .padding({ left: 16, top: 4, bottom: 8 })
                Row() {
                  Text('多端同步（v2 起支持）')
                    .fontSize(15)
                    .fontColor($r('app.color.primary_text'))
                    .layoutWeight(1)
                    .opacity(0.5)
                  Toggle({ type: ToggleType.Switch, isOn: this.syncEnabled })
                    .enabled(false)   // v1 始终灰显；v2-multidevice 启用
                    .onChange((on) => {
                      this.syncEnabled = on
                      this.persist()
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
