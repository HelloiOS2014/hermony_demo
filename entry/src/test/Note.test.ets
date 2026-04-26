// Note.test.ets — NoteRdb / NoteStore 单元测试（Hypium + MockKit）
//
// 设计思路（对照 hermony §16.5）：
//   1. NoteRdb 走真 RDB（hvigorw test --mode debug 起 testRunner，会拿到测试用 context）
//   2. NoteStore 走 MockKit ordinary mock —— rdb 是 NoteStore 的依赖，单测里替换为 fake
//      避免每个 NoteStore 用例都要建表 / 清表
//   3. 异步用例统一显式 done()，timeout = 10000（默认 5s 在 CI 下不够，详见 §16.5 反例 1）
//   4. 用 try / catch + done(error) 保证异常路径也调 done（防"timeout 看不到根因"）
//
// 运行：hvigorw test --mode debug
// 覆盖率：jacoco-report.html（详见 build-profile.json5 testCompileMode = mixed）

import {
  describe, beforeAll, beforeEach, afterEach, afterAll, it, expect
} from '@ohos/hypium'
import { MockKit, when } from '@ohos/hypium'
import { NoteRdb } from '../main/ets/data/NoteRdb'
import { NoteStore } from '../main/ets/data/NoteStore'
import { Note, genNoteId } from '../main/ets/data/Note'
import abilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry'
import { common } from '@kit.AbilityKit'

const TEST_TIMEOUT = 10000

function makeNote(overrides?: Partial<Note>): Note {
  const now = Date.now()
  const base: Note = {
    id: genNoteId(),
    title: 'unit-test-title',
    content: 'unit-test-content',
    createdAt: now,
    updatedAt: now,
    tags: ['unit', 'test']
  }
  return Object.assign(base, overrides ?? {}) as Note
}

export default function noteRdbTest() {

  // ── NoteRdb：真 RDB 链路（init / insert / query / update / delete）──
  describe('NoteRdb', () => {
    let rdb: NoteRdb
    let ctx: common.UIAbilityContext

    beforeAll(async (done: Function) => {
      try {
        const delegator = abilityDelegatorRegistry.getAbilityDelegator()
        ctx = delegator.getAppContext() as common.UIAbilityContext
        rdb = new NoteRdb()
        await rdb.init(ctx)
        done()
      } catch (e) {
        done(e as Error)
      }
    }, TEST_TIMEOUT)

    afterAll(async (done: Function) => {
      try {
        // 清表（防止跑 UI 测试时残留干扰）
        const all = await rdb.queryAll()
        for (const n of all) {
          await rdb.deleteById(n.id)
        }
        done()
      } catch (e) {
        done(e as Error)
      }
    }, TEST_TIMEOUT)

    beforeEach(async (done: Function) => {
      // 每个用例前清空表，避免用例间互相污染（CI 并发安全）
      try {
        const all = await rdb.queryAll()
        for (const n of all) {
          await rdb.deleteById(n.id)
        }
        done()
      } catch (e) {
        done(e as Error)
      }
    }, TEST_TIMEOUT)

    afterEach(() => {
      // 占位（rdb 是套内单例，无需 per-case 销毁）
    })

    it('insert_query_should_roundtrip', 0, async (done: Function) => {
      try {
        const n = makeNote({ title: 'roundtrip', content: 'hello' })
        await rdb.insert(n)
        const got = await rdb.getById(n.id)
        expect(got !== null).assertTrue()
        expect(got!.id).assertEqual(n.id)
        expect(got!.title).assertEqual('roundtrip')
        expect(got!.content).assertEqual('hello')
        expect(got!.tags.length).assertEqual(2)
        done()
      } catch (e) {
        done(e as Error)
      }
    })

    it('queryAll_should_order_by_updatedAt_desc', 0, async (done: Function) => {
      try {
        const t = Date.now()
        const a = makeNote({ title: 'A', updatedAt: t - 3000 })
        const b = makeNote({ title: 'B', updatedAt: t - 1000 })
        const c = makeNote({ title: 'C', updatedAt: t - 2000 })
        await rdb.insert(a)
        await rdb.insert(b)
        await rdb.insert(c)
        const list = await rdb.queryAll()
        expect(list.length).assertEqual(3)
        expect(list[0].title).assertEqual('B')   // 最新
        expect(list[1].title).assertEqual('C')
        expect(list[2].title).assertEqual('A')   // 最旧
        done()
      } catch (e) {
        done(e as Error)
      }
    })

    it('update_should_replace_fields', 0, async (done: Function) => {
      try {
        const n = makeNote({ title: 'before', content: 'old' })
        await rdb.insert(n)
        const updated: Note = {
          id: n.id,
          title: 'after',
          content: 'new',
          createdAt: n.createdAt,
          updatedAt: n.updatedAt + 1000,
          tags: ['updated']
        }
        await rdb.update(updated)
        const got = await rdb.getById(n.id)
        expect(got!.title).assertEqual('after')
        expect(got!.content).assertEqual('new')
        expect(got!.tags[0]).assertEqual('updated')
        done()
      } catch (e) {
        done(e as Error)
      }
    })

    it('deleteById_should_remove_row', 0, async (done: Function) => {
      try {
        const n = makeNote()
        await rdb.insert(n)
        await rdb.deleteById(n.id)
        const got = await rdb.getById(n.id)
        expect(got).assertNull()
        const cnt = await rdb.count()
        expect(cnt).assertEqual(0)
        done()
      } catch (e) {
        done(e as Error)
      }
    })

    it('count_should_match_inserted_rows', 0, async (done: Function) => {
      try {
        for (let i = 0; i < 5; i++) {
          await rdb.insert(makeNote({ title: 'row-' + i }))
        }
        const c = await rdb.count()
        expect(c).assertEqual(5)
        done()
      } catch (e) {
        done(e as Error)
      }
    })

    it('getById_missing_should_return_null', 0, async (done: Function) => {
      try {
        const got = await rdb.getById('not-exist-id')
        expect(got).assertNull()
        done()
      } catch (e) {
        done(e as Error)
      }
    })
  })


  // ── NoteStore：用 MockKit ordinary mock 替换 NoteRdb 依赖 ──
  // 业务核心覆盖率目标 ≥ 80% —— 此套覆盖 NoteStore 的 add / update / remove / loadAll / getById / snapshot
  describe('NoteStore (with MockKit ordinary mock)', () => {

    it('loadAll_should_cache_and_return_rdb_data', 0, async (done: Function) => {
      try {
        const mocker = new MockKit()
        const fakeRdb = new NoteRdb()
        const seed: Note[] = [makeNote({ title: 'seed-1' }), makeNote({ title: 'seed-2' })]
        // ordinary mock：替换 queryAll 返回桩数据，无需起真 RDB
        const queryAllMock = mocker.mockFunc(fakeRdb, fakeRdb.queryAll)
        when(queryAllMock).afterReturn(() => Promise.resolve(seed))

        const store = new NoteStore(fakeRdb)
        const got = await store.loadAll()
        expect(got.length).assertEqual(2)
        expect(got[0].title).assertEqual('seed-1')
        // snapshot 应返回与 cached 等价拷贝
        const snap = store.snapshot()
        expect(snap.length).assertEqual(2)
        done()
      } catch (e) {
        done(e as Error)
      }
    })

    it('add_should_append_and_return_new_array', 0, async (done: Function) => {
      try {
        const mocker = new MockKit()
        const fakeRdb = new NoteRdb()
        const queryAllMock = mocker.mockFunc(fakeRdb, fakeRdb.queryAll)
        when(queryAllMock).afterReturn(() => Promise.resolve([] as Note[]))
        const insertMock = mocker.mockFunc(fakeRdb, fakeRdb.insert)
        when(insertMock).afterReturn(() => Promise.resolve())

        const store = new NoteStore(fakeRdb)
        await store.loadAll()
        const newNote = makeNote({ title: 'added' })
        const arr = await store.add(newNote)
        expect(arr.length).assertEqual(1)
        expect(arr[0].title).assertEqual('added')
        // 教学债 #3 验证：返回新数组（非 mutation）
        expect(arr === store.snapshot()).assertFalse()
        done()
      } catch (e) {
        done(e as Error)
      }
    })

    it('update_should_replace_by_id', 0, async (done: Function) => {
      try {
        const mocker = new MockKit()
        const fakeRdb = new NoteRdb()
        const seed: Note[] = [makeNote({ title: 'before' })]
        const queryAllMock = mocker.mockFunc(fakeRdb, fakeRdb.queryAll)
        when(queryAllMock).afterReturn(() => Promise.resolve(seed))
        const updateMock = mocker.mockFunc(fakeRdb, fakeRdb.update)
        when(updateMock).afterReturn(() => Promise.resolve())

        const store = new NoteStore(fakeRdb)
        await store.loadAll()
        const updated: Note = Object.assign({}, seed[0], { title: 'after' }) as Note
        const arr = await store.update(updated)
        expect(arr.length).assertEqual(1)
        expect(arr[0].title).assertEqual('after')
        done()
      } catch (e) {
        done(e as Error)
      }
    })

    it('remove_should_filter_by_id', 0, async (done: Function) => {
      try {
        const mocker = new MockKit()
        const fakeRdb = new NoteRdb()
        const a = makeNote({ title: 'a' })
        const b = makeNote({ title: 'b' })
        const queryAllMock = mocker.mockFunc(fakeRdb, fakeRdb.queryAll)
        when(queryAllMock).afterReturn(() => Promise.resolve([a, b]))
        const delMock = mocker.mockFunc(fakeRdb, fakeRdb.deleteById)
        when(delMock).afterReturn(() => Promise.resolve())

        const store = new NoteStore(fakeRdb)
        await store.loadAll()
        const arr = await store.remove(a.id)
        expect(arr.length).assertEqual(1)
        expect(arr[0].title).assertEqual('b')
        done()
      } catch (e) {
        done(e as Error)
      }
    })

    it('getById_should_lookup_cached', 0, async (done: Function) => {
      try {
        const mocker = new MockKit()
        const fakeRdb = new NoteRdb()
        const target = makeNote({ title: 'target' })
        const queryAllMock = mocker.mockFunc(fakeRdb, fakeRdb.queryAll)
        when(queryAllMock).afterReturn(() => Promise.resolve([target]))

        const store = new NoteStore(fakeRdb)
        await store.loadAll()
        const got = store.getById(target.id)
        expect(got !== undefined).assertTrue()
        expect(got!.title).assertEqual('target')
        const miss = store.getById('not-exist')
        expect(miss === undefined).assertTrue()
        done()
      } catch (e) {
        done(e as Error)
      }
    })
  })


  // ── genNoteId 工具函数（覆盖率门槛 ≥ 50%）──
  describe('genNoteId', () => {
    it('should_match_uuid_v4_pattern', 0, () => {
      const id = genNoteId()
      // UUID v4 形如 xxxxxxxx-xxxx-4xxx-xxxx-xxxxxxxxxxxx（hex）
      const re = new RegExp('^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}$')
      expect(re.test(id)).assertTrue()
    })

    it('should_be_unique_across_calls', 0, () => {
      const ids = new Set<string>()
      for (let i = 0; i < 100; i++) {
        ids.add(genNoteId())
      }
      // 100 次随机生成无碰撞（v4 碰撞概率约 2^-122）
      expect(ids.size).assertEqual(100)
    })
  })
}
