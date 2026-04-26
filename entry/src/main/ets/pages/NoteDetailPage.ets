// NoteDetailPage — 笔记详情 / 编辑页
//
// 路由参数：noteId: string —— 通过 navPathStack.pushPathByName('NoteDetailPage', noteId)
// 保存策略：
//   - "保存"按钮 → 写 RDB + 触发 store.update（整对象写，对应教学债 #3）
//   - 物理返回 → 自动保存（避免用户编辑后误退）
//   - 空标题自动用首行内容前 20 字代替
//
// v2-multidevice 增量：
//   - 编辑态实时镜像到 AppStorage[CONTINUED_DRAFT_KEY]，让 EntryAbility.onContinue
//     / onSaveState 能拿到当前正在编辑的草稿（流转走系统级回调，无法直接读 @State）
//   - aboutToAppear 优先读 CONTINUED_DRAFT_KEY 兜底（被流转拉起 + noteId 命中时）

import { Note } from '../data/Note'
import { NoteStore, NOTE_STORE_KEY } from '../data/NoteStore'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { shareNote } from '../utils/ShareNote'
import EntryAbility, { ContinuedDraft, CONTINUED_DRAFT_KEY } from '../entryability/EntryAbility'
import { DistributedNoteStore, DISTRIBUTED_STORE_KEY } from '../data/DistributedNoteStore'

@Component
export struct NoteDetailPage {
  @Consume('navPathStack') navPathStack: NavPathStack
  @State title: string = ''
  @State content: string = ''
  @State tagsText: string = ''  // 逗号分隔的标签字符串
  @State noteId: string = ''
  @State createdAt: number = 0
  @State dirty: boolean = false
  @State loading: boolean = true
  @State continuedFromRemote: boolean = false  // v2：标识当前数据来源是流转包

  aboutToAppear(): void {
    const params = this.navPathStack.getParamByName('NoteDetailPage') as Object[]
    const id = (params !== undefined && params.length > 0) ? (params[params.length - 1] as string) : ''
    this.noteId = id
    this.loadNote(id)
  }

  aboutToDisappear(): void {
    // 离开编辑页 → 清掉流转草稿镜像，避免下次 onContinue 误打包过期数据
    EntryAbility.clearContinuedDraft()
  }

  private loadNote(id: string): void {
    const store = AppStorage.get<NoteStore>(NOTE_STORE_KEY)
    if (store === undefined) {
      this.loading = false
      return
    }

    // v2-multidevice：先看 AppStorage 里有没有流转过来的草稿（noteId 必须命中）
    const draft = AppStorage.get<ContinuedDraft>(CONTINUED_DRAFT_KEY)
    if (draft !== undefined && draft.noteId === id && draft.noteId !== '') {
      this.title = draft.title
      this.content = draft.content
      this.tagsText = draft.tags.join(',')
      this.continuedFromRemote = true
      const existing = store.getById(id)
      this.createdAt = existing !== undefined ? existing.createdAt : Date.now()
      this.dirty = true   // 默认标脏 → 退出时自动落盘
      this.loading = false
      this.mirrorEditingState()
      return
    }

    const n = store.getById(id)
    if (n !== undefined) {
      this.title = n.title
      this.content = n.content
      this.tagsText = n.tags.join(',')
      this.createdAt = n.createdAt
    }
    this.loading = false
    this.mirrorEditingState()
  }

  private parseTags(text: string): string[] {
    return text.split(/[,，]/)
      .map((t) => t.trim())
      .filter((t) => t.length > 0)
  }

  // v2-multidevice：把当前编辑态镜像到 AppStorage[CONTINUED_DRAFT_KEY]
  // EntryAbility.onContinue / onSaveState 在系统回调线程读这份镜像
  private mirrorEditingState(cursor: number = 0): void {
    if (this.noteId === '') {
      return
    }
    EntryAbility.updateContinuedDraft({
      noteId: this.noteId,
      title: this.title,
      content: this.content,
      tags: this.parseTags(this.tagsText),
      cursor,
      schemaVersion: 1
    })
  }

  private async save(): Promise<void> {
    const store = AppStorage.get<NoteStore>(NOTE_STORE_KEY)
    if (store === undefined || this.noteId === '') {
      return
    }
    const finalTitle = this.title.length > 0
      ? this.title
      : (this.content.split('\n')[0].slice(0, 20) || '无标题')
    const note: Note = {
      id: this.noteId,
      title: finalTitle,
      content: this.content,
      createdAt: this.createdAt > 0 ? this.createdAt : Date.now(),
      updatedAt: Date.now(),
      tags: this.parseTags(this.tagsText)
    }
    // 流转过来但本地 RDB 不存在 → 走 add 而非 update（保证笔记落盘）
    const existing = store.getById(this.noteId)
    if (existing === undefined) {
      await store.add(note)
    } else {
      await store.update(note)
    }
    this.dirty = false
    this.continuedFromRemote = false

    // v2-multidevice：保存后镜像到分布式对象（仅当前在会话中）
    const distStore = AppStorage.get<DistributedNoteStore>(DISTRIBUTED_STORE_KEY)
    if (distStore !== undefined && distStore.isJoined()) {
      distStore.mirrorLocalToRemote()
    }

    promptAction.showToast({ message: '已保存', duration: 1200 })
  }

  private async saveAndBack(): Promise<void> {
    if (this.dirty) {
      await this.save()
    }
    this.navPathStack.pop()
  }

  private async share(): Promise<void> {
    const store = AppStorage.get<NoteStore>(NOTE_STORE_KEY)
    if (store === undefined || this.noteId === '') {
      return
    }
    // 分享前先把当前编辑内容固化（防"看到的不是分享出去的"）
    if (this.dirty) {
      await this.save()
    }
    const note = store.getById(this.noteId)
    if (note === undefined) {
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    try {
      await shareNote(ctx, note)
    } catch (_e) {
      promptAction.showToast({ message: '分享失败，请稍后重试', duration: 1500 })
    }
  }

  private async deleteNote(): Promise<void> {
    const store = AppStorage.get<NoteStore>(NOTE_STORE_KEY)
    if (store === undefined || this.noteId === '') {
      return
    }
    await store.remove(this.noteId)
    // v2-multidevice：删除后镜像到分布式对象，对端 onChange 触发"远端没有的笔记"判定
    // （注意：DistributedNoteStore.applyRemoteToLocal 不主动删本地——避免离线端清空对端，
    //  真实业务请走墓碑表，详见 DistributedNoteStore.ets 注释）
    const distStore = AppStorage.get<DistributedNoteStore>(DISTRIBUTED_STORE_KEY)
    if (distStore !== undefined && distStore.isJoined()) {
      distStore.mirrorLocalToRemote()
    }
    promptAction.showToast({ message: '已删除', duration: 1200 })
    this.navPathStack.pop()
  }

  build() {
    NavDestination() {
      Column() {
        // 顶部栏：返回 / 删除 / 保存
        Row() {
          Text('‹ 返回')
            .fontSize(16)
            .fontColor($r('app.color.accent'))
            .padding(8)
            .onClick(() => this.saveAndBack())
          Blank()
          Text($r('app.string.action_share'))
            .fontSize(15)
            .fontColor($r('app.color.accent'))
            .padding(8)
            .onClick(() => this.share())
          Text($r('app.string.action_delete'))
            .fontSize(15)
            .fontColor($r('app.color.danger'))
            .padding(8)
            .onClick(() => this.deleteNote())
          Text($r('app.string.action_save'))
            .fontSize(15)
            .fontColor($r('app.color.accent'))
            .padding(8)
            .onClick(() => this.save())
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })

        // v2-multidevice：流转过来的草稿 banner，提醒用户"这是从其他设备接过来的编辑"
        if (this.continuedFromRemote) {
          Row({ space: 8 }) {
            Text('🔁')
              .fontSize(14)
            Text('已从其他设备接续，保存后会落到本机 RDB')
              .fontSize(12)
              .fontColor($r('app.color.accent'))
              .layoutWeight(1)
          }
          .width('92%')
          .padding(10)
          .backgroundColor('#E8F4FD')
          .borderRadius(8)
          .margin({ left: 16, right: 16, bottom: 6 })
        }

        if (this.loading) {
          LoadingProgress()
            .width(40)
            .height(40)
            .margin({ top: 80 })
        } else {
          // 标题
          TextInput({ placeholder: '标题', text: this.title })
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Color.Transparent)
            .padding({ left: 16, right: 16, top: 12, bottom: 8 })
            .onChange((v) => {
              this.title = v
              this.dirty = true
              this.mirrorEditingState()
            })

          // 标签
          TextInput({ placeholder: '标签（用逗号分隔）', text: this.tagsText })
            .fontSize(13)
            .fontColor($r('app.color.secondary_text'))
            .backgroundColor(Color.Transparent)
            .padding({ left: 16, right: 16, top: 4, bottom: 4 })
            .onChange((v) => {
              this.tagsText = v
              this.dirty = true
              this.mirrorEditingState()
            })

          Divider()
            .strokeWidth(0.5)
            .color($r('app.color.secondary_text'))
            .opacity(0.3)
            .margin({ left: 16, right: 16 })

          // 正文
          TextArea({ placeholder: '在这里写下你的笔记…', text: this.content })
            .fontSize(16)
            .layoutWeight(1)
            .backgroundColor(Color.Transparent)
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .onChange((v) => {
              this.content = v
              this.dirty = true
              this.mirrorEditingState(v.length)
            })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
    }
    .title($r('app.string.title_note_detail'))
    .hideTitleBar(true)
    .onBackPressed(() => {
      this.saveAndBack()
      return true
    })
  }
}
