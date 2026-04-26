// UserPrefsStore — Preferences API 封装（用户偏好持久化）
// v1 仅持久化 themeMode / defaultTags / syncEnabled
//
// ╔══════════════════════════════════════════════════════════════════════╗
// ║ §21.5 [feat-5] Android → HarmonyOS NEXT 迁移要点                      ║
// ╠══════════════════════════════════════════════════════════════════════╣
// ║ Android 原工程（v5-android-source 分支 [feat-5]）                     ║
// ║   - data/UserPrefsRepo.kt：preferencesDataStore("user_prefs")         ║
// ║       darkMode: Flow<Boolean?>（null=跟随系统 / true=强制深 / false=浅）║
// ║   - res/values-night/themes.xml：深色限定符资源                       ║
// ║   - MainActivity：collectAsState + HermonyNoteTheme(darkTheme=...)   ║
// ║       + AppCompatDelegate.setDefaultNightMode 同步窗口装饰            ║
// ║                                                                      ║
// ║ HarmonyOS 对应实现（本文件 + entry/src/main/resources/dark/）         ║
// ║   - preferences.getPreferences(ctx, STORE_NAME) 单例                  ║
// ║   - themeMode: 'light' | 'dark' | 'system'                            ║
// ║   - resources/dark/element/color.json：深色限定词资源                 ║
// ║   - 切到深色：UIAbility.onConfigurationUpdate 接 ColorMode             ║
// ║                                                                      ║
// ║ 关键映射                                                              ║
// ║   DataStore Preferences (singleton via property delegate)             ║
// ║       ↔  preferences.getPreferences(ctx, name)                       ║
// ║   Flow<Boolean?>                                                      ║
// ║       ↔  prefs.get + 自定义事件 emitter（无原生 Flow）                 ║
// ║   res/values-night/themes.xml                                         ║
// ║       ↔  resources/dark/element/color.json                            ║
// ║   AppCompatDelegate.setDefaultNightMode                               ║
// ║       ↔  app.context.config.colorMode 自动随系统                     ║
// ║         + 强制：ConfigurationConstant.ColorMode.COLOR_MODE_DARK      ║
// ║   isSystemInDarkTheme()                                               ║
// ║       ↔  this.context.config.colorMode === ColorMode.COLOR_MODE_DARK ║
// ║                                                                      ║
// ║ 注意点（迁移踩坑）                                                    ║
// ║   1. Compose 通过 CompositionLocal 自动重组；ArkTS 资源限定词由系统     ║
// ║      切换，需要监听 onConfigurationUpdate 主动 setState 触发 build     ║
// ║   2. Android valueRange 直接用 Float；ArkTS 偏好里的字号缩放建议        ║
// ║      存 Number，UI 侧用 ConfigurationConstant 或自定义 px 计算         ║
// ║   3. v1 鸿蒙工程 themeMode 是字符串枚举（'light'|'dark'|'system'），    ║
// ║      Android 用 Boolean? null 三态；语义等价但映射时要转换             ║
// ╚══════════════════════════════════════════════════════════════════════╝

import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { UserPrefs } from './Note'

const TAG = 'UserPrefsStore'
const DOMAIN = 0xFF00
const STORE_NAME = 'hermony_note_user_prefs'

const KEY_THEME = 'themeMode'
const KEY_DEFAULT_TAGS = 'defaultTags'
const KEY_SYNC = 'syncEnabled'

const DEFAULT_PREFS: UserPrefs = {
  themeMode: 'system',
  defaultTags: [],
  syncEnabled: false
}

export class UserPrefsStore {
  private pref: preferences.Preferences | null = null

  async init(context: common.UIAbilityContext): Promise<void> {
    this.pref = await preferences.getPreferences(context, STORE_NAME)
    hilog.info(DOMAIN, TAG, 'init done')
  }

  private require(): preferences.Preferences {
    if (this.pref === null) {
      throw new Error('UserPrefsStore not init')
    }
    return this.pref
  }

  async load(): Promise<UserPrefs> {
    const pref = this.require()
    const themeRaw = await pref.get(KEY_THEME, DEFAULT_PREFS.themeMode) as string
    const tagsRaw = await pref.get(KEY_DEFAULT_TAGS, '[]') as string
    const syncRaw = await pref.get(KEY_SYNC, DEFAULT_PREFS.syncEnabled) as boolean
    const theme: 'light' | 'dark' | 'system' =
      themeRaw === 'light' || themeRaw === 'dark' ? themeRaw : 'system'
    let tags: string[] = []
    try {
      tags = JSON.parse(tagsRaw) as string[]
    } catch (_e) {
      tags = []
    }
    return {
      themeMode: theme,
      defaultTags: tags,
      syncEnabled: syncRaw
    }
  }

  async save(prefs: UserPrefs): Promise<void> {
    const pref = this.require()
    await pref.put(KEY_THEME, prefs.themeMode)
    await pref.put(KEY_DEFAULT_TAGS, JSON.stringify(prefs.defaultTags))
    await pref.put(KEY_SYNC, prefs.syncEnabled)
    await pref.flush()
  }
}
