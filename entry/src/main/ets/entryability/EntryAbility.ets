import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { NoteRdb } from '../data/NoteRdb'
import { NoteStore, NOTE_STORE_KEY } from '../data/NoteStore'
import { UserPrefsStore } from '../data/UserPrefsStore'
import { seedNotes } from '../data/Note'

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
