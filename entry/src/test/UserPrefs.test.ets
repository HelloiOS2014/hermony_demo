// UserPrefs.test.ets — UserPrefsStore 持久化单元测试
//
// 走真 Preferences API（Hypium 测试制品有 context，preferences 可正常 init）
// 异步统一显式 done() + timeout 10s

import {
  describe, beforeAll, beforeEach, afterAll, it, expect
} from '@ohos/hypium'
import { UserPrefsStore } from '../main/ets/data/UserPrefsStore'
import { UserPrefs } from '../main/ets/data/Note'
import abilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

const TEST_TIMEOUT = 10000
const STORE_NAME = 'hermony_note_user_prefs'

export default function userPrefsStoreTest() {
  describe('UserPrefsStore', () => {
    let store: UserPrefsStore
    let ctx: common.UIAbilityContext

    beforeAll(async (done: Function) => {
      try {
        const delegator = abilityDelegatorRegistry.getAbilityDelegator()
        ctx = delegator.getAppContext() as common.UIAbilityContext
        store = new UserPrefsStore()
        await store.init(ctx)
        done()
      } catch (e) {
        done(e as Error)
      }
    }, TEST_TIMEOUT)

    beforeEach(async (done: Function) => {
      // 每个用例前清掉 preferences，避免污染（CI 并发 / 重跑稳定）
      try {
        await preferences.deletePreferences(ctx, STORE_NAME)
        store = new UserPrefsStore()
        await store.init(ctx)
        done()
      } catch (e) {
        done(e as Error)
      }
    }, TEST_TIMEOUT)

    afterAll(async (done: Function) => {
      try {
        await preferences.deletePreferences(ctx, STORE_NAME)
        done()
      } catch (e) {
        done(e as Error)
      }
    }, TEST_TIMEOUT)

    it('load_when_empty_should_return_defaults', 0, async (done: Function) => {
      try {
        const got = await store.load()
        expect(got.themeMode).assertEqual('system')
        expect(got.defaultTags.length).assertEqual(0)
        expect(got.syncEnabled).assertFalse()
        done()
      } catch (e) {
        done(e as Error)
      }
    })

    it('save_then_load_should_roundtrip', 0, async (done: Function) => {
      try {
        const prefs: UserPrefs = {
          themeMode: 'dark',
          defaultTags: ['工作', '会议'],
          syncEnabled: true
        }
        await store.save(prefs)
        const got = await store.load()
        expect(got.themeMode).assertEqual('dark')
        expect(got.defaultTags.length).assertEqual(2)
        expect(got.defaultTags[0]).assertEqual('工作')
        expect(got.syncEnabled).assertTrue()
        done()
      } catch (e) {
        done(e as Error)
      }
    })

    it('save_should_persist_across_reinit', 0, async (done: Function) => {
      try {
        const prefs: UserPrefs = {
          themeMode: 'light',
          defaultTags: ['持久化校验'],
          syncEnabled: false
        }
        await store.save(prefs)
        // 重新 init 模拟应用重启
        const fresh = new UserPrefsStore()
        await fresh.init(ctx)
        const got = await fresh.load()
        expect(got.themeMode).assertEqual('light')
        expect(got.defaultTags[0]).assertEqual('持久化校验')
        done()
      } catch (e) {
        done(e as Error)
      }
    })

    it('load_should_normalize_invalid_themeMode_to_system', 0, async (done: Function) => {
      try {
        // 直接写入非法 themeMode（绕开 save）
        const pref = await preferences.getPreferences(ctx, STORE_NAME)
        await pref.put('themeMode', 'pink')   // 不在 light / dark / system 集
        await pref.flush()
        const got = await store.load()
        expect(got.themeMode).assertEqual('system')   // load() 内 fallback 到 system
        done()
      } catch (e) {
        done(e as Error)
      }
    })

    it('load_should_handle_corrupted_tags_json', 0, async (done: Function) => {
      try {
        const pref = await preferences.getPreferences(ctx, STORE_NAME)
        await pref.put('defaultTags', '{not-valid-json')   // 损坏 JSON
        await pref.flush()
        const got = await store.load()
        // load() 内 try / catch 兜底为空数组（防止解析异常炸进 UI）
        expect(got.defaultTags.length).assertEqual(0)
        done()
      } catch (e) {
        done(e as Error)
      }
    })

    it('require_before_init_should_throw', 0, async (done: Function) => {
      // 未 init 直接 load 应抛错（防御 require() 守卫，无需先调 init）
      const fresh = new UserPrefsStore()
      try {
        await fresh.load()
        // 不应到这里：load() 在未 init 时必须 reject
        done(new Error('expected load() to reject before init, but it resolved') as Error)
      } catch (e) {
        // 期望路径：require 守卫触发 reject
        expect(e !== null && e !== undefined).assertTrue()
        done()
      }
    })
  })
}
