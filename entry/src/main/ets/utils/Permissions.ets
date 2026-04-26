// Permissions — 通讯录 / 相机权限申请封装
//
// ╔══════════════════════════════════════════════════════════════════════╗
// ║ §21.5 [feat-4] Android → HarmonyOS NEXT 迁移要点                      ║
// ╠══════════════════════════════════════════════════════════════════════╣
// ║ Android 原工程（v5-android-source 分支 [feat-4]）                     ║
// ║   - AndroidManifest.xml: <uses-permission android:name=".CAMERA" />  ║
// ║   - util/CameraPermission.kt:                                         ║
// ║       rememberCameraPermissionState() 基于                            ║
// ║       ActivityResultContracts.RequestPermission                       ║
// ║   - 三态：Idle / Granted / Denied，UI 据此切分支卡片                  ║
// ║   - 启动时 ContextCompat.checkSelfPermission 同步当前授权             ║
// ║                                                                      ║
// ║ HarmonyOS 对应实现（本文件）                                          ║
// ║   - module.json5 requestPermissions:                                  ║
// ║       ohos.permission.READ_CONTACTS / CAMERA                         ║
// ║   - abilityAccessCtrl.createAtManager().requestPermissionsFromUser    ║
// ║   - on('selfPermissionStateChange') 监听权限态变化                    ║
// ║   - GrantStatus.PERMISSION_GRANTED / PERMISSION_DENIED               ║
// ║                                                                      ║
// ║ 关键映射                                                              ║
// ║   Manifest <uses-permission>                                          ║
// ║       ↔  module.json5 requestPermissions[]                            ║
// ║   ActivityResultContracts.RequestPermission                           ║
// ║       ↔  atManager.requestPermissionsFromUser(ctx, [perm])           ║
// ║   ContextCompat.checkSelfPermission                                   ║
// ║       ↔  atManager.checkAccessTokenSync(tokenId, perm)               ║
// ║   PackageManager.PERMISSION_GRANTED                                   ║
// ║       ↔  GrantStatus.PERMISSION_GRANTED                               ║
// ║   onRequestPermissionsResult (legacy)                                 ║
// ║       ↔  on('selfPermissionStateChange', cb)                         ║
// ║   "前往设置 - 应用 - 权限"引导                                        ║
// ║       ↔  ACL（Access Control List）+ Settings.openSettings           ║
// ║                                                                      ║
// ║ 注意点（迁移踩坑）                                                    ║
// ║   1. 鸿蒙 system_grant 权限（如 INTERNET）不需要弹窗，                  ║
// ║      只 user_grant 才走 requestPermissionsFromUser；                   ║
// ║      Android 只看 protectionLevel 判定，习惯上比鸿蒙宽松               ║
// ║   2. on('selfPermissionStateChange') 必须对称 off！                  ║
// ║      否则反复进出页面会累积监听器（见下面教学债 #2）                   ║
// ║   3. Activity Result API 自动管理生命周期；ArkTS 必须手写             ║
// ║      aboutToAppear/aboutToDisappear 配对                              ║
// ╚══════════════════════════════════════════════════════════════════════╝
//
// ⚠️ 教学型性能债 #2（§21.3 演示修复用）：
//   下面的 abilityAccessCtrl 监听器在 aboutToAppear 时注册，但页面在 aboutToDisappear
//   阶段**没有**对称解绑（off）。
//   单次进出页面看不出问题，但反复进出该页面会累积监听器引用，导致：
//     - 内存占用持续上涨
//     - 同一权限变更回调被触发 N 次（N = 进出次数）
//   v3-perf-optimized 会在调用方页面的 aboutToDisappear 加 unbindAccessListener。
//
// 生产代码请按 §17.x 规范对称注册 / 解绑。

import { abilityAccessCtrl, common, Permissions as AbilityPermissions } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'Permissions'
const DOMAIN = 0xFF00

export type GrantStatus = 'granted' | 'denied' | 'denied_forbidden'

// 当前已注册的监听器；故意做成模块级单例，便于 demo "反复进出 → 累积"现象
let listenerRegistered = false
let lastTokenId: number = 0

/**
 * 同步接口：申请权限并返回结果。被拒绝时返回 denied / denied_forbidden（一次拒永久拒）。
 */
export async function requestPermission(
  context: common.UIAbilityContext,
  permission: AbilityPermissions
): Promise<GrantStatus> {
  const am = abilityAccessCtrl.createAtManager()
  try {
    const result = await am.requestPermissionsFromUser(context, [permission])
    const code = result.authResults[0]
    if (code === 0) {
      return 'granted'
    }
    // 鸿蒙：-1 = 拒绝；2 = 用户勾选"不再询问"
    return code === 2 ? 'denied_forbidden' : 'denied'
  } catch (err) {
    const e = err as BusinessError
    hilog.error(DOMAIN, TAG, 'requestPermission failed code=%{public}d msg=%{public}s', e.code, e.message)
    return 'denied'
  }
}

/**
 * 教学债 #2：注册监听 — 仅 add，**不**提供对称的 off 调用点。
 * 调用方在 aboutToAppear 调，aboutToDisappear 漏调 off → 监听器堆积。
 */
export function bindAccessListener(
  permissions: AbilityPermissions[],
  cb: (perm: AbilityPermissions, granted: boolean) => void
): void {
  const am = abilityAccessCtrl.createAtManager()
  try {
    am.on('permissionStateChange', [], permissions, (data) => {
      const granted = data.change === abilityAccessCtrl.PermissionStateChangeType.PERMISSION_GRANTED_OPER
      cb(data.permissionName as AbilityPermissions, granted)
    })
    listenerRegistered = true
    hilog.info(DOMAIN, TAG, 'listener bound (NOT symmetrically unbound — perf debt #2)')
  } catch (err) {
    const e = err as BusinessError
    hilog.error(DOMAIN, TAG, 'bind listener failed code=%{public}d msg=%{public}s', e.code, e.message)
  }
}

// v3-perf-optimized 会启用此函数，在 aboutToDisappear 调用，与 bindAccessListener 对称：
// export function unbindAccessListener(...) { am.off('permissionStateChange', ...) }

export function isListenerRegistered(): boolean {
  return listenerRegistered
}

export function setLastTokenId(tokenId: number): void {
  lastTokenId = tokenId
}

export function getLastTokenId(): number {
  return lastTokenId
}
