// NoteDetailPage — 笔记详情 / 编辑页
//
// 路由参数：noteId: string —— 通过 navPathStack.pushPathByName('NoteDetailPage', noteId)
// 保存策略：
//   - "保存"按钮 → 写 RDB + 触发 store.update（整对象写，对应教学债 #3）
//   - 物理返回 → 自动保存（避免用户编辑后误退）
//   - 空标题自动用首行内容前 20 字代替

import { Note } from '../data/Note'
import { NoteStore, NOTE_STORE_KEY } from '../data/NoteStore'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { shareNote } from '../utils/ShareNote'

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

  aboutToAppear(): void {
    const params = this.navPathStack.getParamByName('NoteDetailPage') as Object[]
    const id = (params !== undefined && params.length > 0) ? (params[params.length - 1] as string) : ''
    this.noteId = id
    this.loadNote(id)
  }

  private loadNote(id: string): void {
    const store = AppStorage.get<NoteStore>(NOTE_STORE_KEY)
    if (store === undefined) {
      this.loading = false
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
  }

  private parseTags(text: string): string[] {
    return text.split(/[,，]/)
      .map((t) => t.trim())
      .filter((t) => t.length > 0)
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
      createdAt: this.createdAt,
      updatedAt: Date.now(),
      tags: this.parseTags(this.tagsText)
    }
    await store.update(note)
    this.dirty = false
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
