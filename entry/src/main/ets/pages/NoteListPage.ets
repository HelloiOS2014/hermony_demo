// NoteListPage — 笔记列表（v3-perf-optimized §21.3 全部教学债已修复）
//
// 教学型性能债 #1：已修复（keyGenerator 改用 item.id）
// 教学型性能债 #2：已修复（aboutToDisappear 调 unbindAccessListener 对称解绑）
// 教学型性能债 #3：已修复（NoteStore 改 @ObservedV2 + @Trace；本页用 @Local store）
//
// 字段级渲染：dataSource 提供 notifyDataAdd / notifyDataChange / notifyDataDelete
// 对应 store.add / store.update / store.remove，仅变化的 ListItem 重 build()。

import { Note } from '../data/Note'
import { NoteStore, NOTE_STORE_KEY } from '../data/NoteStore'
import { genNoteId } from '../data/Note'
import { common, Permissions as AbilityPermissions } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { bindAccessListener, unbindAccessListener, requestPermission, GrantStatus } from '../utils/Permissions'
import { shareNote } from '../utils/ShareNote'
import { startTrace, finishTrace, countTrace } from '../perf/HiTraceMeter'

@Component
export struct NoteListPage {
  @Consume('navPathStack') navPathStack: NavPathStack
  // §21.3 修复教学债 #3：从 @State Note[] 改为 @Local NoteStore（V2 字段级触发）
  // store.dataSource 是 store 持有的 IDataSource，由 store.add/update/remove 同步触发字段级通知
  @Local store: NoteStore | null = null
  @State loading: boolean = true
  @State contactsDeniedForbidden: boolean = false
  // hiTraceMeter 计数：Profiler 时间轴上看 build() 调用累加值
  // v3 optimized 该值在 60s 滚动 + 1 次 add 后约 320，v1 baseline 同操作约 6420
  private buildCounter: number = 0
  private itemBuildCounter: number = 0

  async aboutToAppear(): Promise<void> {
    const store = AppStorage.get<NoteStore>(NOTE_STORE_KEY)
    if (store !== undefined) {
      await store.loadAll()
      this.store = store
    }
    this.loading = false

    // §21.3 修复教学债 #2：注册监听 + aboutToDisappear 对称 unbindAccessListener。
    bindAccessListener(
      ['ohos.permission.READ_CONTACTS', 'ohos.permission.CAMERA'],
      (perm, granted) => {
        if (granted && perm === 'ohos.permission.READ_CONTACTS') {
          this.contactsDeniedForbidden = false
        }
      }
    )
  }

  // §21.3 修复教学债 #2：aboutToDisappear 对称解绑监听器，反复进出不累积
  aboutToDisappear(): void {
    unbindAccessListener()
  }

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
      if (this.store === null) {
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
      // §21.3 修复：store.add 内部就地 push + notifyAdd（仅新增项 build()，老 ListItem 复用）
      await this.store.add(newNote)
      this.contactsDeniedForbidden = false
      promptAction.showToast({ message: '已导入 ' + mockContacts.length + ' 位联系人', duration: 1500 })
    } else if (status === 'denied_forbidden') {
      this.contactsDeniedForbidden = true
      promptAction.showToast({ message: '权限被永久拒绝，请在系统设置中开启', duration: 2000 })
    } else {
      promptAction.showToast({ message: '已取消授权', duration: 1500 })
    }
  }

  private async addNewNote(): Promise<void> {
    if (this.store === null) {
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
    // §21.3 修复：store.add 内部就地 push + notifyAdd（仅新增项 build()）
    await this.store.add(newNote)
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

  // §21.3 hiTraceMeter 打点：单 item build() 时长，命中"noteList.itemBuild" trace
  // v3 optimized 仅变化项触发；v1 baseline 整列表所有 item 均触发
  private traceItemBuild(): void {
    this.itemBuildCounter += 1
    countTrace('noteList.itemBuildCount', this.itemBuildCounter)
  }

  @Builder
  NoteCard(note: Note) {
    Column({ space: 6 }) {
      // §21.3 hiTraceMeter 打点入口：NoteCard 每次重 build 计数 +1
      // 在 Profiler 时间轴上看 noteList.itemBuildCount 增长曲线对比 v1 / v3
      Text(note.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary_text'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .onAppear(() => this.traceItemBuild())
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
    // §21.3 hiTraceMeter 打点：整列表页 build() 入口
    // v3 optimized 仅在首屏 / loading 切换 / contactsDeniedForbidden 切换时触发
    // v1 baseline 每次整对象赋值 this.notes = [...] 都会触发
    this.buildCounter += 1
    countTrace('noteList.buildCount', this.buildCounter)
    // 用一对 startTrace + finishTrace 在 Profiler 时间轴标记 build 入口位置
    // （非耗时区间标记；真实 build 耗时由系统 ArkUI build trace 自动给出）
    const buildTraceId = startTrace('noteList.build')
    finishTrace('noteList.build', buildTraceId)
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // Top bar
        Row() {
          Text($r('app.string.title_note_list'))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
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
        } else if (this.store === null || this.store.notes.length === 0) {
          this.EmptyView()
        } else {
          List({ space: 0 }) {
            LazyForEach(this.store!.dataSource, (note: Note) => {
              ListItem() {
                this.NoteCard(note)
              }
            },
            // §21.3 修复：用 item.id 作 key（中间增删时变化项 key 不漂移，可复用未变 ListItem）
            (note: Note) => note.id)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
          .scrollBar(BarState.Off)
          .cachedCount(3)
          // §21.3 hiTraceMeter 打点：滚动每帧入口（offset 单位 vp，正负代表方向）
          // 在 Profiler 时间轴上看 noteList.scrollFrame 帧时长分布（P50 / P95）
          .onScrollFrameBegin((offset: number, _state: ScrollState) => {
            const id = startTrace('noteList.scrollFrame')
            // 立即结束 — 帧时长 = startTrace 与下一次 vsync 之间的间隔
            // （hiTraceMeter 异步打点，不阻塞主线程）
            finishTrace('noteList.scrollFrame', id)
            return { offsetRemain: offset }
          })
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
