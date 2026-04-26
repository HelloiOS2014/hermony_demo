// UiTestAbility.ets — UI 测试 Ability（用于 hvigorw uitest 时把 testRunner 挂到独立 Ability）
//
// 与 EntryAbility 区别：
//   - EntryAbility：业务 Ability（用户用的）
//   - UiTestAbility：测试制品启动入口，OhosTestRunner.onRun 内 startAbility 被测页面
//
// 实际跑通时：hvigor 会在测试 hap 里把 module.json5 testRunner.srcPath 指向 ohosTest/，
// UiTestAbility 由测试制品自动拉起，再调 startAbility(EntryAbility) 进入被测业务。

import UIAbility from '@ohos.app.ability.UIAbility'
import window from '@ohos.window'
import hilog from '@ohos.hilog'

const TAG = 'UiTestAbility'
const DOMAIN = 0xFF00

export default class UiTestAbility extends UIAbility {
  onCreate(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onCreate')
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onWindowStageCreate')
    // 测试 Ability 不挂业务页面 —— testRunner 走 startAbility(EntryAbility) 来跑被测业务
    // 这里复用业务侧 MainPage 作为占位（避免引入未实现的 testability/pages/Index）；
    // testRunner.onRun 内会走 startAbility(EntryAbility) 切到真业务，windowStage 不会真渲染 MainPage。
    windowStage.loadContent('pages/MainPage', (err) => {
      if (err.code !== 0) {
        hilog.error(DOMAIN, TAG, 'loadContent failed code=%{public}d', err.code)
      }
    })
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onWindowStageDestroy')
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onForeground')
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onBackground')
  }
}
