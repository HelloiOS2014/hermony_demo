// NoteListPage — 笔记列表
//
// ⚠️ 教学型性能债 #1（§21.3 演示修复用）：
//   LazyForEach 的 keyGenerator 用 index 作 key。当列表中间删除 / 插入时，所有
//   后续 item 的 index 变化 → 所有 key 失效 → 全部 item 重建。
//   v3-perf-optimized 改：(item) => item.id
//
// ⚠️ 教学型性能债 #3（在 NoteStore 模块）：
//   add/update/remove 都返回新数组，调用方只能 this.notes = [...]，触发整列表 build()。
//   v3-perf-optimized 改：V2 @ObservedV2 + @Trace 字段级触发。

import { Note } from '../data/Note'
import { NoteStore, NOTE_STORE_KEY } from '../data/NoteStore'
import { genNoteId } from '../data/Note'

// IDataSource 实现：v1 版做最简实现，每次外部数据改动都整体 reload
class NoteListSource implements IDataSource {
  private listeners: DataChangeListener[] = []
  private items: Note[] = []

  setData(items: Note[]): void {
    this.items = items
    // 整体通知（v1 版本，对应教学债 #3 整列表 build()）
    this.listeners.forEach((l) => l.onDataReloaded())
  }

  totalCount(): number {
    return this.items.length
  }

  getData(index: number): Note {
    return this.items[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const i = this.listeners.indexOf(listener)
    if (i >= 0) {
      this.listeners.splice(i, 1)
    }
  }
}

@Component
export struct NoteListPage {
  @Consume('navPathStack') navPathStack: NavPathStack
  // 教学债 #3 触发点：整对象赋值
  @State notes: Note[] = []
  @State loading: boolean = true
  private dataSource: NoteListSource = new NoteListSource()

  async aboutToAppear(): Promise<void> {
    const store = AppStorage.get<NoteStore>(NOTE_STORE_KEY)
    if (store !== undefined) {
      this.notes = await store.loadAll()
      this.dataSource.setData(this.notes)
    }
    this.loading = false
  }

  private formatTime(ts: number): string {
    const d = new Date(ts)
    const pad = (n: number): string => n < 10 ? '0' + n : '' + n
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate())
        + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes())
  }

  private async addNewNote(): Promise<void> {
    const store = AppStorage.get<NoteStore>(NOTE_STORE_KEY)
    if (store === undefined) {
      return
    }
    const now = Date.now()
    const newNote: Note = {
      id: genNoteId(),
      title: '新建笔记',
      content: '',
      createdAt: now,
      updatedAt: now,
      tags: []
    }
    // 教学债 #3：整对象写
    this.notes = await store.add(newNote)
    this.dataSource.setData(this.notes)
    // 直接进入详情页编辑
    this.navPathStack.pushPathByName('NoteDetailPage', newNote.id)
  }

  @Builder
  EmptyView() {
    Column() {
      Text('📝')
        .fontSize(64)
        .margin({ bottom: 16 })
      Text($r('app.string.empty_note_hint'))
        .fontSize(16)
        .fontColor($r('app.color.secondary_text'))
    }
    .width('100%')
    .height('60%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  NoteCard(note: Note) {
    Column({ space: 6 }) {
      Text(note.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary_text'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      if (note.content.length > 0) {
        Text(note.content)
          .fontSize(14)
          .fontColor($r('app.color.secondary_text'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      Row({ space: 8 }) {
        Text(this.formatTime(note.updatedAt))
          .fontSize(12)
          .fontColor($r('app.color.secondary_text'))
        if (note.tags.length > 0) {
          Text('· ' + note.tags.join(' · '))
            .fontSize(12)
            .fontColor($r('app.color.accent'))
        }
      }
      .width('100%')
    }
    .padding(16)
    .width('100%')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ bottom: 8 })
    .onClick(() => {
      this.navPathStack.pushPathByName('NoteDetailPage', note.id)
    })
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // Top bar
        Row() {
          Text($r('app.string.title_note_list'))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
          Text('⚙')
            .fontSize(22)
            .padding(8)
            .onClick(() => {
              this.navPathStack.pushPathByName('SettingsPage', null)
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        if (this.loading) {
          LoadingProgress()
            .width(40)
            .height(40)
            .margin({ top: 80 })
        } else if (this.notes.length === 0) {
          this.EmptyView()
        } else {
          List({ space: 0 }) {
            LazyForEach(this.dataSource, (note: Note) => {
              ListItem() {
                this.NoteCard(note)
              }
            },
            // ⚠️ 教学债 #1：用 index 作 key（应用 item.id）
            (_note: Note, idx: number) => idx.toString())
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
          .scrollBar(BarState.Off)
          .cachedCount(3)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))

      // FAB 新建按钮
      Button() {
        Text('+')
          .fontSize(28)
          .fontColor(Color.White)
      }
      .width(56)
      .height(56)
      .backgroundColor($r('app.color.accent'))
      .borderRadius(28)
      .margin({ right: 24, bottom: 24 })
      .onClick(() => this.addNewNote())
    }
    .width('100%')
    .height('100%')
  }
}
