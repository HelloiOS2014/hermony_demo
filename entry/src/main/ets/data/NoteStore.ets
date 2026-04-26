// NoteStore — v1 业务状态层
//
// ⚠️ 教学型性能债 #3（§21.3 演示修复用）：
//   v1 在这里用 V1 装饰器 + 整对象写，每次 add/update/delete 都会触发整个
//   LazyForEach 重 build()。
//   v3-perf-optimized 会改为：
//     @ObservedV2 class NoteStore { @Trace notes: Note[] = [] }
//   再配合 LazyForEach 的 IDataSource 触发字段级渲染。
//
// 生产代码请按 §17.1 渲染性能规范，勿照抄此实现。

import { Note } from './Note'
import { NoteRdb } from './NoteRdb'

// 单例 key：在 EntryAbility 启动后塞进 AppStorage，页面用 LocalStorageProp 取
export const NOTE_STORE_KEY = 'noteStore'

// V1 装饰器在 struct 里使用，这里用普通类持引用 + 通过 AppStorage / LocalStorage 暴露
// 真正在页面里：@State notes: Note[] = AppStorage.get<Note[]>('notes') ?? []
//             this.notes = [...this.notes, newNote]   // 整对象写，触发整列表 build()
export class NoteStore {
  private rdb: NoteRdb
  private cached: Note[] = []

  constructor(rdb: NoteRdb) {
    this.rdb = rdb
  }

  async loadAll(): Promise<Note[]> {
    this.cached = await this.rdb.queryAll()
    return this.cached
  }

  // 教学债 #3：返回新数组而不是 mutation，调用方只能整对象赋值
  async add(note: Note): Promise<Note[]> {
    await this.rdb.insert(note)
    this.cached = [...this.cached, note]   // ← 整对象写
    return this.cached
  }

  async update(note: Note): Promise<Note[]> {
    await this.rdb.update(note)
    this.cached = this.cached.map((n) => n.id === note.id ? note : n)  // ← 整对象写
    return this.cached
  }

  async remove(id: string): Promise<Note[]> {
    await this.rdb.deleteById(id)
    this.cached = this.cached.filter((n) => n.id !== id)  // ← 整对象写
    return this.cached
  }

  getById(id: string): Note | undefined {
    return this.cached.find((n) => n.id === id)
  }

  snapshot(): Note[] {
    return this.cached.slice()
  }
}
