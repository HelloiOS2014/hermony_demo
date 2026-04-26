// List.test.ets — 测试套集中加载入口
// hvigorw test 时由 OhosTestRunner 拉起本文件，testsuite() 把所有 default export 注册到 Hypium

import noteRdbTest from './Note.test'
import userPrefsStoreTest from './UserPrefs.test'

// [v4-2] 在 commit 时再追加 UiTestList 注册
// import uiTestList from './UiTestList.test'

export default function testsuite() {
  noteRdbTest()
  userPrefsStoreTest()
}
