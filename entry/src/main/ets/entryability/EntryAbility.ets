import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { NoteRdb } from '../data/NoteRdb'
import { NoteStore, NOTE_STORE_KEY } from '../data/NoteStore'
import { UserPrefsStore } from '../data/UserPrefsStore'
import { seedNotes, UserPrefs, Note } from '../data/Note'

const TAG = 'EntryAbility'
const DOMAIN = 0xFF00

// ── v2-multidevice：自由流转 wantParam 字段 key（命名空间避免与系统字段冲突） ──
// 与 §9.4 教程"onContinue 状态打包"小节命名一致
const WP_NOTE_ID = 'note.editing.id'
const WP_NOTE_TITLE = 'note.editing.title'
const WP_NOTE_CONTENT = 'note.editing.content'
const WP_NOTE_TAGS = 'note.editing.tags'         // 序列化为 JSON 字符串（wantParam 不支持 string[] 嵌套）
const WP_NOTE_CURSOR = 'note.editing.cursor'
const WP_SCHEMA_VERSION = 'note.editing.schemaVersion'
const SCHEMA_VERSION = 1

export interface ContinuedDraft {
  noteId: string
  title: string
  content: string
  tags: string[]
  cursor: number
  schemaVersion: number
}

export const CONTINUED_DRAFT_KEY = 'continuedDraft'

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onCreate launchReason=%{public}d', launchParam.launchReason)

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

    // 4. v2-multidevice：被自由流转拉起时，want.parameters 内含源端 onContinue 打包的状态
    //    LaunchReason.CONTINUATION = 4（系统枚举），目标端用 launchParam 判定
    if (launchParam.launchReason === AbilityConstant.LaunchReason.CONTINUATION) {
      const draft = this.parseContinuedDraft(want)
      if (draft !== null) {
        AppStorage.setOrCreate(CONTINUED_DRAFT_KEY, draft)
        hilog.info(DOMAIN, TAG, 'continuation accepted noteId=%{public}s', draft.noteId)
      } else {
        hilog.warn(DOMAIN, TAG, 'continuation want missing draft fields')
      }
    }
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

  // ── v2-multidevice：自由流转回调 ──
  //
  // onContinue（源端）：
  //   用户主动发起跨设备流转后系统回调，业务侧把"正在编辑的笔记草稿"打包进 wantParam，
  //   wantParam 是 Record<string, Object>，序列化语义≈JSON，所以：
  //     - tags（string[]）必须 JSON.stringify 转字符串再放进去（嵌套数组在部分系统版本下会丢类型）
  //     - 不能直接放 Date / Map / 自定义类实例
  //
  // 返回值：
  //   AGREE                 → 源端 ability 在流转完成后销毁（默认）
  //   AGREE_WITH_KEEP_ALIVE → 源端保留实例（少数场景：希望源端继续可见）
  //   REJECT                → 拒绝流转（业务自定）
  //   MISMATCH              → 检测到版本 / 能力不匹配
  //
  // 与 §9.4 教程"流转 vs 协同"对照：流转走 onContinue → 对端 onCreate（CONTINUATION），
  // 协同走 connectServiceExtensionAbility → 对端 onConnect（不走 Ability 生命周期）。
  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult {
    const draft = AppStorage.get<ContinuedDraft>(CONTINUED_DRAFT_KEY)
    if (draft === undefined || draft.noteId === '') {
      // 没有正在编辑的笔记 → 拒绝流转，避免对端拉起一个空白详情页
      hilog.warn(DOMAIN, TAG, 'onContinue rejected: no editing draft')
      return AbilityConstant.OnContinueResult.REJECT
    }

    wantParam[WP_NOTE_ID] = draft.noteId
    wantParam[WP_NOTE_TITLE] = draft.title
    wantParam[WP_NOTE_CONTENT] = draft.content
    wantParam[WP_NOTE_TAGS] = JSON.stringify(draft.tags)
    wantParam[WP_NOTE_CURSOR] = draft.cursor
    wantParam[WP_SCHEMA_VERSION] = SCHEMA_VERSION

    hilog.info(DOMAIN, TAG, 'onContinue agree noteId=%{public}s contentLen=%{public}d',
      draft.noteId, draft.content.length)
    return AbilityConstant.OnContinueResult.AGREE
  }

  // onSaveState（系统级状态保存回调）：
  //   两种触发路径：
  //     1. 流转入口（reason = CONTINUATION）：与 onContinue 互补，拿不到 wantParam 时兜底
  //     2. 进程被回收前（reason = APP_RECOVERY，配合 errorManager.setOnAppRecovery）：
  //        系统在 OOM / Crash 后重启同 ability 时再用此 state 恢复
  //   返回值同 onContinue（AGREE / REJECT 等）。
  //
  //   v2 demo 仅做最简实现：把 ContinuedDraft 平铺写进 wantParam，与 onContinue 同 schema。
  onSaveState(reason: AbilityConstant.StateType, wantParam: Record<string, Object>):
    AbilityConstant.OnSaveResult {
    hilog.info(DOMAIN, TAG, 'onSaveState reason=%{public}d', reason)
    const draft = AppStorage.get<ContinuedDraft>(CONTINUED_DRAFT_KEY)
    if (draft === undefined || draft.noteId === '') {
      return AbilityConstant.OnSaveResult.ALL_REJECT
    }
    wantParam[WP_NOTE_ID] = draft.noteId
    wantParam[WP_NOTE_TITLE] = draft.title
    wantParam[WP_NOTE_CONTENT] = draft.content
    wantParam[WP_NOTE_TAGS] = JSON.stringify(draft.tags)
    wantParam[WP_NOTE_CURSOR] = draft.cursor
    wantParam[WP_SCHEMA_VERSION] = SCHEMA_VERSION
    if (reason === AbilityConstant.StateType.CONTINUATION) {
      return AbilityConstant.OnSaveResult.CONTINUATION_AGREE
    }
    return AbilityConstant.OnSaveResult.RECOVERY_AGREE
  }

  // 解析对端 onCreate 收到的 want.parameters，校验 schemaVersion 兼容
  private parseContinuedDraft(want: Want): ContinuedDraft | null {
    const params = want.parameters
    if (params === undefined) {
      return null
    }
    const noteId = String(params[WP_NOTE_ID] ?? '')
    if (noteId === '') {
      return null
    }
    let tags: string[] = []
    try {
      const raw = String(params[WP_NOTE_TAGS] ?? '[]')
      const parsed = JSON.parse(raw) as string[]
      if (Array.isArray(parsed)) {
        tags = parsed
      }
    } catch (_e) {
      tags = []
    }
    return {
      noteId,
      title: String(params[WP_NOTE_TITLE] ?? ''),
      content: String(params[WP_NOTE_CONTENT] ?? ''),
      tags,
      cursor: Number(params[WP_NOTE_CURSOR] ?? 0),
      schemaVersion: Number(params[WP_SCHEMA_VERSION] ?? SCHEMA_VERSION)
    }
  }

  // 业务工具：详情页编辑时调用，把当前编辑态镜像到 AppStorage
  // 这样 onContinue / onSaveState 都能读到最新状态
  static updateContinuedDraft(draft: ContinuedDraft): void {
    AppStorage.setOrCreate(CONTINUED_DRAFT_KEY, draft)
  }

  static clearContinuedDraft(): void {
    AppStorage.setOrCreate(CONTINUED_DRAFT_KEY, {
      noteId: '',
      title: '',
      content: '',
      tags: [] as string[],
      cursor: 0,
      schemaVersion: SCHEMA_VERSION
    } as ContinuedDraft)
  }

  // 让流转后目标端可读：把流转拉起时缓存的 draft 同步落到 RDB
  // （未落盘时仅在 AppStorage，便于详情页 aboutToAppear 直接读）
  async hydrateContinuedDraftIfAny(): Promise<void> {
    const draft = AppStorage.get<ContinuedDraft>(CONTINUED_DRAFT_KEY)
    if (draft === undefined || draft.noteId === '') {
      return
    }
    const store = AppStorage.get<NoteStore>(NOTE_STORE_KEY)
    if (store === undefined) {
      return
    }
    const existing = store.getById(draft.noteId)
    const now = Date.now()
    const note: Note = {
      id: draft.noteId,
      title: draft.title.length > 0 ? draft.title : '流转草稿',
      content: draft.content,
      createdAt: existing !== undefined ? existing.createdAt : now,
      updatedAt: now,
      tags: draft.tags
    }
    if (existing !== undefined) {
      await store.update(note)
    } else {
      await store.add(note)
    }
    hilog.info(DOMAIN, TAG, 'hydrateContinuedDraft done noteId=%{public}s', draft.noteId)
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
