// NoteRdb — relationalStore 封装
// v1 版表结构与 §21.3 / §21.4 / §21.5 全部兼容；v2 起会在 storeConfig 上加 isSearchable 等分布式字段。
//
// schema v1：
//   notes(id TEXT PK, title TEXT, content TEXT, createdAt INT, updatedAt INT, tags TEXT)
// 索引：
//   idx_notes_updatedAt 用于 list 默认按 updatedAt DESC 排序
//
// ╔══════════════════════════════════════════════════════════════════════╗
// ║ §21.5 [feat-3] Android → HarmonyOS NEXT 迁移要点                      ║
// ╠══════════════════════════════════════════════════════════════════════╣
// ║ Android 原工程（v5-android-source 分支 [feat-3]）                     ║
// ║   - data/Note.kt：@Entity(tableName="notes") + @PrimaryKey            ║
// ║   - data/NoteDao.kt：@Dao + Flow<List<Note>>（Room 自动通知）          ║
// ║   - data/NoteDatabase.kt：@Database(version=1, entities=[Note])      ║
// ║   - Room.databaseBuilder + addCallback(onCreate) → 5 条 seed         ║
// ║   - ViewModel 通过 dao.observeAll().stateIn(...) 派生 StateFlow      ║
// ║                                                                      ║
// ║ HarmonyOS 对应实现（本文件）                                          ║
// ║   - relationalStore.getRdbStore(ctx, STORE_CONFIG) 拿 store           ║
// ║   - 手写 SQL CREATE TABLE / CREATE INDEX                             ║
// ║   - rdbStore.executeSql / insert / update / delete / query           ║
// ║   - 没有 Flow 等价物：UI 通过 NoteStore（@Observed）做内存镜像       ║
// ║     增删改时手动 push 更新；预置 5 条由 NoteStore.bootstrap 写入       ║
// ║                                                                      ║
// ║ 关键映射                                                              ║
// ║   @Entity + @PrimaryKey                                               ║
// ║       ↔  手写 CREATE TABLE + 主键约束                                 ║
// ║   @Dao + suspend fun + Flow<List<T>>                                  ║
// ║       ↔  RdbStore.query → ResultSet → 循环 mapToObject               ║
// ║   Room.databaseBuilder + addCallback                                  ║
// ║       ↔  relationalStore.getRdbStore + 首启 if-not-exists 建表        ║
// ║   @Insert(onConflict=REPLACE)                                         ║
// ║       ↔  RdbStore.insert(table, row, ConflictResolution.ON_CONFLICT_REPLACE) ║
// ║   Room Migration                                                      ║
// ║       ↔  RdbStore.executeSql ALTER TABLE + version 字段自维护         ║
// ║                                                                      ║
// ║ 注意点（迁移踩坑）                                                    ║
// ║   1. Android KSP 自动生成 DAO 实现；ArkTS 手写映射会更长，            ║
// ║      建议封装一个 mapResultSet(rs)→Note 私有方法（本文件已实现）       ║
// ║   2. RdbStore.query 返回 Promise（不像 Room 的 suspend），           ║
// ║      ArkTS 调用方必须用 await/then；UI 层不能假设同步返回             ║
// ║   3. SecurityLevel：Android 默认 sandbox；鸿蒙必须显式声明            ║
// ║      relationalStore.SecurityLevel.S1（普通业务数据）                ║
// ╚══════════════════════════════════════════════════════════════════════╝

import { relationalStore } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Note } from './Note'

const TAG = 'NoteRdb'
const DOMAIN = 0xFF00

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'hermony_note_v1.db',
  securityLevel: relationalStore.SecurityLevel.S1
}

const TABLE = 'notes'
const SCHEMA_VERSION = 1   // v2 起会自增；migrate() 按版本走分支

const SQL_CREATE = `CREATE TABLE IF NOT EXISTS ${TABLE} (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  tags TEXT NOT NULL
)`

const SQL_INDEX_UPDATED = `CREATE INDEX IF NOT EXISTS idx_notes_updatedAt ON ${TABLE}(updatedAt DESC)`

export class NoteRdb {
  private store: relationalStore.RdbStore | null = null

  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.store = await relationalStore.getRdbStore(context, STORE_CONFIG)
      await this.store.executeSql(SQL_CREATE)
      await this.store.executeSql(SQL_INDEX_UPDATED)
      await this.migrate()
      hilog.info(DOMAIN, TAG, 'init done schema=v%{public}d', SCHEMA_VERSION)
    } catch (err) {
      const e = err as BusinessError
      hilog.error(DOMAIN, TAG, 'init failed code=%{public}d msg=%{public}s', e.code, e.message)
      throw err as Error
    }
  }

  /**
   * Migration 占位：v1 不需要迁移；v2+ 会在这里加分支。
   * 用 PRAGMA user_version 持久化 schema 版本。
   */
  private async migrate(): Promise<void> {
    if (this.store === null) {
      return
    }
    // 当前 v1 没有迁移分支；保留接口给 v2-multidevice 升级用
    await this.store.executeSql('PRAGMA user_version = ' + SCHEMA_VERSION)
  }

  async getById(id: string): Promise<Note | null> {
    const store = this.require()
    const predicates = new relationalStore.RdbPredicates(TABLE)
    predicates.equalTo('id', id)
    const rs = await store.query(predicates,
      ['id', 'title', 'content', 'createdAt', 'updatedAt', 'tags'])
    if (!rs.goToFirstRow()) {
      rs.close()
      return null
    }
    const note: Note = {
      id: rs.getString(rs.getColumnIndex('id')),
      title: rs.getString(rs.getColumnIndex('title')),
      content: rs.getString(rs.getColumnIndex('content')),
      createdAt: rs.getLong(rs.getColumnIndex('createdAt')),
      updatedAt: rs.getLong(rs.getColumnIndex('updatedAt')),
      tags: JSON.parse(rs.getString(rs.getColumnIndex('tags'))) as string[]
    }
    rs.close()
    return note
  }

  private require(): relationalStore.RdbStore {
    if (this.store === null) {
      throw new Error('NoteRdb not init')
    }
    return this.store
  }

  async insert(note: Note): Promise<void> {
    const store = this.require()
    const bucket: relationalStore.ValuesBucket = {
      id: note.id,
      title: note.title,
      content: note.content,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      tags: JSON.stringify(note.tags)
    }
    await store.insert(TABLE, bucket)
  }

  async update(note: Note): Promise<void> {
    const store = this.require()
    const bucket: relationalStore.ValuesBucket = {
      title: note.title,
      content: note.content,
      updatedAt: note.updatedAt,
      tags: JSON.stringify(note.tags)
    }
    const predicates = new relationalStore.RdbPredicates(TABLE)
    predicates.equalTo('id', note.id)
    await store.update(bucket, predicates)
  }

  async deleteById(id: string): Promise<void> {
    const store = this.require()
    const predicates = new relationalStore.RdbPredicates(TABLE)
    predicates.equalTo('id', id)
    await store.delete(predicates)
  }

  async queryAll(): Promise<Note[]> {
    const store = this.require()
    const predicates = new relationalStore.RdbPredicates(TABLE)
    predicates.orderByDesc('updatedAt')
    const rs = await store.query(predicates,
      ['id', 'title', 'content', 'createdAt', 'updatedAt', 'tags'])
    const list: Note[] = []
    while (rs.goToNextRow()) {
      list.push({
        id: rs.getString(rs.getColumnIndex('id')),
        title: rs.getString(rs.getColumnIndex('title')),
        content: rs.getString(rs.getColumnIndex('content')),
        createdAt: rs.getLong(rs.getColumnIndex('createdAt')),
        updatedAt: rs.getLong(rs.getColumnIndex('updatedAt')),
        tags: JSON.parse(rs.getString(rs.getColumnIndex('tags'))) as string[]
      })
    }
    rs.close()
    return list
  }

  async count(): Promise<number> {
    const store = this.require()
    const predicates = new relationalStore.RdbPredicates(TABLE)
    const rs = await store.query(predicates, ['id'])
    const c = rs.rowCount
    rs.close()
    return c
  }
}
