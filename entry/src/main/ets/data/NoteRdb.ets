// NoteRdb — relationalStore 封装
// v1 版表结构与 §21.3 / §21.4 / §21.5 全部兼容；v2 起会在 storeConfig 上加 isSearchable 等分布式字段。
//
// schema v1：
//   notes(id TEXT PK, title TEXT, content TEXT, createdAt INT, updatedAt INT, tags TEXT)
// 索引：
//   idx_notes_updatedAt 用于 list 默认按 updatedAt DESC 排序

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
