// UserPrefsStore — Preferences API 封装（用户偏好持久化）
// v1 仅持久化 themeMode / defaultTags / syncEnabled

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
