// OhosTestRunner.ets — Hypium 测试入口（最小三件套之一）
//   1. List.test.ets：集中加载所有 .test.ets
//   2. OhosTestRunner.ets（本文件）：实现 Hypium.hypiumInit + testsuite() + Hypium.hypiumStart
//   3. module.json5：testRunner.name = OhosTestRunner（注：实际使用时 module.json5 引的是
//      UiTestAbility，testRunner 走配置在 module.json5 testRunner 块）
//
// 命令：hvigorw test --mode debug
//   debug 模式必需，release 包关 mock 字节码改写（详见 §16.5 反例）

import AbilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry'
import { Hypium } from '@ohos/hypium'
import { TestRunner } from '@ohos.application.testRunner'
import testsuite from './List.test'

const TAG = 'OhosTestRunner'

export default class OhosTestRunner implements TestRunner {
  onPrepare(): void {
    console.info(TAG + ' onPrepare')
  }

  onRun(): void {
    console.info(TAG + ' onRun start')
    const abilityDelegator = AbilityDelegatorRegistry.getAbilityDelegator()
    const abilityDelegatorArguments = AbilityDelegatorRegistry.getArguments()
    Hypium.hypiumInit(abilityDelegator, abilityDelegatorArguments)
    // testsuite() 把 List.test.ets 里 import 的所有套挂到 Hypium 全局注册表
    testsuite()
    // 启动测试 —— testRunner 拉起所有 describe，按 it 顺序执行
    Hypium.hypiumStart(abilityDelegator, abilityDelegatorArguments)
    console.info(TAG + ' onRun done')
  }
}
