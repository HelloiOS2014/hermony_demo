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
//
// v2-multidevice 增量：
//   - 列表用 GridRow + GridCol 包裹，按断点 sm/md/lg/xl 自动切 1/2/3/4 列布局
//     （手机竖屏 sm → 1 列，平板 md → 2 列，2in1 lg → 3 列，超大屏 xl → 4 列）
//   - 仍走 LazyForEach + IDataSource，断点变化只影响每行 GridCol 的 span，
//     不重建 LazyForEach 的子节点（与 §17.x 渲染性能规范兼容）

import { Note } from '../data/Note'
import { NoteStore, NOTE_STORE_KEY } from '../data/NoteStore'
import { genNoteId } from '../data/Note'
import { common, Permissions as AbilityPermissions } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { bindAccessListener, requestPermission, GrantStatus } from '../utils/Permissions'
import { shareNote } from '../utils/ShareNote'
import {
  DistributedNoteStore,
  DISTRIBUTED_STORE_KEY,
  DistributedSyncListener
} from '../data/DistributedNoteStore'

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
  @State contactsDeniedForbidden: boolean = false
  @State remotePeerOnline: boolean = false   // v2-multidevice：对端在线状态指示
  private dataSource: NoteListSource = new NoteListSource()

  async aboutToAppear(): Promise<void> {
    const store = AppStorage.get<NoteStore>(NOTE_STORE_KEY)
    if (store !== undefined) {
      this.notes = await store.loadAll()
      this.dataSource.setData(this.notes)
    }
    this.loading = false

    // 教学债 #2 触发点：在 aboutToAppear 注册 abilityAccessCtrl 监听器
    // 但 aboutToDisappear **不**调用对称的 unbind，反复进出列表会累积监听器引用。
    // §21.3 修复后会在 aboutToDisappear 加 unbindAccessListener。
    bindAccessListener(
      ['ohos.permission.READ_CONTACTS', 'ohos.permission.CAMERA'],
      (perm, granted) => {
        if (granted && perm === 'ohos.permission.READ_CONTACTS') {
          this.contactsDeniedForbidden = false
        }
      }
    )

    // v2-multidevice：分布式同步监听
    // 同步开启的会话由 EntryAbility / SettingsPage 控制；本页只负责"对端来变更时刷新 UI"
    const distStore = AppStorage.get<DistributedNoteStore>(DISTRIBUTED_STORE_KEY)
    if (distStore !== undefined && distStore.isJoined()) {
      const listener: DistributedSyncListener = {
        onChange: async (_remoteNotes: Note[], _fields: string[]) => {
          // distStore 已经把对端 notes 写回本地 NoteStore；UI 这层只重新拉一次列表
          const s = AppStorage.get<NoteStore>(NOTE_STORE_KEY)
          if (s !== undefined) {
            this.notes = await s.loadAll()
            this.dataSource.setData(this.notes)
          }
        },
        onStatus: (_networkId: string, status: 'online' | 'offline') => {
          this.remotePeerOnline = status === 'online'
        }
      }
      distStore.joinSession(distStore.getSessionId(), listener)
      // 进列表页时把本地最新数据 mirror 一次给对端（防对端启动晚于本端）
      distStore.mirrorLocalToRemote()
    }
  }

  // ⚠️ 教学债 #2：v1 故意**不实现** aboutToDisappear 解绑监听器
  // aboutToDisappear(): void { unbindAccessListener(...) }   ← v3 修复后启用

  private formatTime(ts: number): string {
    const d = new Date(ts)
    const pad = (n: number): string => n < 10 ? '0' + n : '' + n
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate())
        + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes())
  }

  private async importContacts(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const perm: AbilityPermissions = 'ohos.permission.READ_CONTACTS'
    const status: GrantStatus = await requestPermission(ctx, perm)
    if (status === 'granted') {
      // 演示用：把"通讯录联系人"作为标签写入新笔记
      // 真实实现请用 @kit.ContactsKit；此处用 mock 数据避免引入额外 SDK
      const mockContacts = ['张三', '李四', '王五']
      const store = AppStorage.get<NoteStore>(NOTE_STORE_KEY)
      if (store === undefined) {
        return
      }
      const now = Date.now()
      const newNote: Note = {
        id: genNoteId(),
        title: '通讯录导入 · ' + this.formatTime(now),
        content: '从通讯录导入了 ' + mockContacts.length + ' 位联系人作为标签。',
        createdAt: now,
        updatedAt: now,
        tags: mockContacts
      }
      this.notes = await store.add(newNote)
      this.dataSource.setData(this.notes)
      this.contactsDeniedForbidden = false
      // v2-multidevice：本地写完同步到分布式对象，对端 onChange 会拿到新笔记
      this.mirrorIfSyncing()
      promptAction.showToast({ message: '已导入 ' + mockContacts.length + ' 位联系人', duration: 1500 })
    } else if (status === 'denied_forbidden') {
      this.contactsDeniedForbidden = true
      promptAction.showToast({ message: '权限被永久拒绝，请在系统设置中开启', duration: 2000 })
    } else {
      promptAction.showToast({ message: '已取消授权', duration: 1500 })
    }
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
    // v2-multidevice：本地新建笔记 → 镜像到分布式对象
    this.mirrorIfSyncing()
    // 直接进入详情页编辑
    this.navPathStack.pushPathByName('NoteDetailPage', newNote.id)
  }

  // v2-multidevice：把本地 NoteStore 当前快照镜像给分布式对象（仅当前在会话中时）
  // 列表页所有"会写本地"的入口（add / importContacts）都要在落盘后调一次
  private mirrorIfSyncing(): void {
    const distStore = AppStorage.get<DistributedNoteStore>(DISTRIBUTED_STORE_KEY)
    if (distStore !== undefined && distStore.isJoined()) {
      distStore.mirrorLocalToRemote()
    }
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
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction(async () => {
          const ctx = getContext(this) as common.UIAbilityContext
          try {
            await shareNote(ctx, note)
          } catch (_e) {
            promptAction.showToast({ message: '分享失败，请稍后重试', duration: 1500 })
          }
        })
    )
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
          // v2-multidevice：对端在线状态指示（绿点 = online，灰点 = offline）
          if (this.remotePeerOnline) {
            Text('● 已连')
              .fontSize(11)
              .fontColor('#1ABC9C')
              .padding({ left: 6, right: 6 })
          }
          Text('👥')
            .fontSize(22)
            .padding(8)
            .onClick(() => this.importContacts())
          Text('⚙')
            .fontSize(22)
            .padding(8)
            .onClick(() => {
              this.navPathStack.pushPathByName('SettingsPage', null)
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        // 拒绝兜底 banner（denied_forbidden 状态展示）
        if (this.contactsDeniedForbidden) {
          Row({ space: 8 }) {
            Text('⚠')
              .fontSize(16)
              .fontColor($r('app.color.danger'))
            Text($r('app.string.perm_denied_hint'))
              .fontSize(13)
              .fontColor($r('app.color.primary_text'))
              .layoutWeight(1)
            Text('知道了')
              .fontSize(13)
              .fontColor($r('app.color.accent'))
              .padding(4)
              .onClick(() => {
                this.contactsDeniedForbidden = false
              })
          }
          .width('90%')
          .padding(12)
          .backgroundColor('#FFF3E0')
          .borderRadius(8)
          .margin({ left: 16, right: 16, bottom: 8 })
        }

        if (this.loading) {
          LoadingProgress()
            .width(40)
            .height(40)
            .margin({ top: 80 })
        } else if (this.notes.length === 0) {
          this.EmptyView()
        } else {
          // v2-multidevice 响应式断点：
          //   sm（手机竖屏  < 600vp）→ 1 列（GridCol span 12，相当于占满 12 格）
          //   md（平板 / 2in1 600..840vp）→ 2 列（每个 GridCol span 6）
          //   lg（大屏 840..1440vp）→ 3 列（每个 GridCol span 4）
          //   xl（超大屏 ≥ 1440vp）→ 4 列（每个 GridCol span 3）
          // 注意：GridRow 自身只负责"列轨道 + 间距"，不替换 LazyForEach。
          // LazyForEach 仍是底层渲染入口（断点切换时 GridCol span 改，子节点不重建）。
          GridRow({
            columns: { sm: 12, md: 12, lg: 12, xl: 12 },
            gutter: { x: 12, y: 8 },
            breakpoints: { value: ['600vp', '840vp', '1440vp'], reference: BreakpointsReference.WindowSize }
          }) {
            GridCol({ span: 12 }) {
              List({ space: 0 }) {
                LazyForEach(this.dataSource, (note: Note) => {
                  ListItem() {
                    GridRow({
                      columns: { sm: 12, md: 12, lg: 12, xl: 12 },
                      breakpoints: {
                        value: ['600vp', '840vp', '1440vp'],
                        reference: BreakpointsReference.WindowSize
                      }
                    }) {
                      GridCol({ span: { sm: 12, md: 6, lg: 4, xl: 3 } }) {
                        this.NoteCard(note)
                      }
                    }
                  }
                },
                // ⚠️ 教学债 #1：用 index 作 key（应用 item.id）
                (_note: Note, idx: number) => idx.toString())
              }
              .width('100%')
              .layoutWeight(1)
              .scrollBar(BarState.Off)
              .cachedCount(3)
            }
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
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
