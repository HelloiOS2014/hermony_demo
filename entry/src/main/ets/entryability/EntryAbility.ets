// EntryAbility — 应用入口（UIAbility）
//
// §21.5 [feat-5] 迁移注释（深色主题）：
//   Android 一侧（v5-android-source [feat-5]）的入口是 MainActivity（ComponentActivity），
//   通过 AppCompatDelegate.setDefaultNightMode + isSystemInDarkTheme()
//   决定整个应用的颜色基调；切换时 Activity 会自动重建。
//   HarmonyOS NEXT 的颜色模式由 UIAbility.onConfigurationUpdate 通知，
//   切换深色 / 浅色时 ConfigurationConstant.ColorMode 变化，
//   resources/dark/element/* 限定词自动生效，无需手动重建窗口。
//   强制深色可用 setColorMode(COLOR_MODE_DARK)，对应 Android 的 MODE_NIGHT_YES。

import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { NoteRdb } from '../data/NoteRdb'
import { NoteStore, NOTE_STORE_KEY } from '../data/NoteStore'
import { UserPrefsStore } from '../data/UserPrefsStore'
import { seedNotes, UserPrefs } from '../data/Note'

const TAG = 'EntryAbility'
const DOMAIN = 0xFF00

export default class EntryAbility extends UIAbility {
  async onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onCreate')

    // 1. 初始化 RDB + 首次启动注入 5 条预置笔记
    const rdb = new NoteRdb()
    await rdb.init(this.context)
    const existing = await rdb.count()
    if (existing === 0) {
      const seeds = seedNotes()
      for (const n of seeds) {
        await rdb.insert(n)
      }
      hilog.info(DOMAIN, TAG, 'seeded %{public}d notes', seeds.length)
    }

    // 2. 用 NoteStore 包一层；通过 AppStorage 暴露给页面
    const store = new NoteStore(rdb)
    await store.loadAll()
    AppStorage.setOrCreate(NOTE_STORE_KEY, store)

    // 3. UserPrefs（主题等）
    const prefsStore = new UserPrefsStore()
    await prefsStore.init(this.context)
    AppStorage.setOrCreate('userPrefsStore', prefsStore)
    const prefs = await prefsStore.load()
    AppStorage.setOrCreate('themeMode', prefs.themeMode)
    this.applyColorMode(prefs.themeMode)
  }

  applyColorMode(mode: 'light' | 'dark' | 'system'): void {
    let target: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
    if (mode === 'light') {
      target = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
    } else if (mode === 'dark') {
      target = ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    }
    this.context.getApplicationContext().setColorMode(target)
    hilog.info(DOMAIN, TAG, 'applyColorMode mode=%{public}s', mode)
  }

  async saveAndApplyTheme(mode: 'light' | 'dark' | 'system'): Promise<void> {
    const prefsStore = AppStorage.get<UserPrefsStore>('userPrefsStore')
    if (prefsStore !== undefined) {
      const cur: UserPrefs = await prefsStore.load()
      cur.themeMode = mode
      await prefsStore.save(cur)
    }
    AppStorage.setOrCreate('themeMode', mode)
    this.applyColorMode(mode)
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/MainPage', (err) => {
      if (err.code !== 0) {
        hilog.error(DOMAIN, TAG, 'loadContent failed code=%{public}d', err.code)
      }
    })
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'onForeground')
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'onBackground')
  }
}
