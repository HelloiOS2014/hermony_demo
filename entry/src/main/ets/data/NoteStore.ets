// NoteStore — 业务状态层（v3-perf-optimized §21.3 修复版）
//
// §21.3 修复教学债 #3：从 V1 整对象写改为 V2 字段级 @Trace 触发：
//   @ObservedV2 class NoteStore { @Trace notes: Note[] = [] }
//   add/update/remove **就地** mutate（push / 字段赋值 / splice），
//   @Trace 装饰的字段写入会自动触发依赖该字段的组件做字段级 build()。
//
// 业务侧组件用 @Local store: NoteStore（V2 装饰器，从 AppStorage 取实例后接管）。
// store.dataSource 暴露 LazyForEach 数据源；store 在每次 mutation 后**同步**调
// notifyDataAdd / notifyDataChange / notifyDataDelete，仅变化的 ListItem 重 build()。
// 整列表 build() 调用 ↓ 95%（与 v1 baseline 比；详见 docs/perf-summary.md）。
//
// 生产代码请按 §17.1 渲染性能规范，本文件即为达标实现样本。

import { Note } from './Note'
import { NoteRdb } from './NoteRdb'

// 单例 key：在 EntryAbility 启动后塞进 AppStorage，页面 AppStorage.get 取
export const NOTE_STORE_KEY = 'noteStore'

// LazyForEach 字段级数据源：与 store.notes 共享同一引用，提供 notifyXxx 通知 API
export class NoteListSource implements IDataSource {
  private listeners: DataChangeListener[] = []
  private items: Note[]

  constructor(items: Note[]) {
    this.items = items
  }

  reload(): void {
    this.listeners.forEach((l) => l.onDataReloaded())
  }

  notifyAdd(index: number): void {
    this.listeners.forEach((l) => l.onDataAdd(index))
  }

  notifyChange(index: number): void {
    this.listeners.forEach((l) => l.onDataChange(index))
  }

  notifyDelete(index: number): void {
    this.listeners.forEach((l) => l.onDataDelete(index))
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

@ObservedV2
export class NoteStore {
  private rdb: NoteRdb
  // §21.3 修复：@Trace 字段级触发；写入此字段时仅依赖该字段的组件重 build()
  @Trace notes: Note[] = []
  // LazyForEach 数据源：与 notes 共享同一引用，store mutation 后同步通知字段级渲染
  readonly dataSource: NoteListSource

  constructor(rdb: NoteRdb) {
    this.rdb = rdb
    this.dataSource = new NoteListSource(this.notes)
  }

  async loadAll(): Promise<Note[]> {
    const all = await this.rdb.queryAll()
    // 就地清空 + push，避免整对象赋值（@Trace 数组被替换会触发整列表通知）
    this.notes.splice(0, this.notes.length, ...all)
    this.dataSource.reload()
    return this.notes
  }

  // §21.3 修复：就地 push + notifyAdd，仅新增项 build()
  async add(note: Note): Promise<number> {
    await this.rdb.insert(note)
    this.notes.push(note)
    const idx = this.notes.length - 1
    this.dataSource.notifyAdd(idx)
    return idx
  }

  // §21.3 修复：找到下标后**就地**字段级写 + notifyChange，仅该 ListItem 重 build()
  async update(note: Note): Promise<number> {
    await this.rdb.update(note)
    const idx = this.notes.findIndex((n) => n.id === note.id)
    if (idx >= 0) {
      this.notes[idx] = note
      this.dataSource.notifyChange(idx)
    }
    return idx
  }

  // §21.3 修复：splice 就地删除 + notifyDelete，仅触发该索引位置的删除通知
  async remove(id: string): Promise<number> {
    await this.rdb.deleteById(id)
    const idx = this.notes.findIndex((n) => n.id === id)
    if (idx >= 0) {
      this.notes.splice(idx, 1)
      this.dataSource.notifyDelete(idx)
    }
    return idx
  }

  getById(id: string): Note | undefined {
    return this.notes.find((n) => n.id === id)
  }

  snapshot(): Note[] {
    return this.notes.slice()
  }
}
