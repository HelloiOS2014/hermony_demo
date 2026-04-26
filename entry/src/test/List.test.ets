// List.test.ets — 测试套集中加载入口
// hvigorw test 时由 OhosTestRunner 拉起本文件，testsuite() 把所有 default export 注册到 Hypium

import noteRdbTest from './Note.test'
import userPrefsStoreTest from './UserPrefs.test'
import uiTestList from './UiTestList.test'

export default function testsuite() {
  noteRdbTest()
  userPrefsStoreTest()
  // [v4-2] UI 自动化套（driver.findComponent + click + assertVisible 完整流程）
  uiTestList()
}
