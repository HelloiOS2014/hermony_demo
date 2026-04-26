// Permissions — 通讯录 / 相机权限申请封装（v3-perf-optimized §21.3 修复版）
//
// §21.3 修复教学债 #2：bindAccessListener 持久化句柄（subscriber id），
// 新增对称的 unbindAccessListener 在 aboutToDisappear 调用 am.off。
// 反复进出页面不再累积监听器：
//   - 内存平稳
//   - 同一权限变更回调仅触发 1 次
//
// 生产代码请按 §17.x 规范对称注册 / 解绑。

import { abilityAccessCtrl, common, Permissions as AbilityPermissions } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'Permissions'
const DOMAIN = 0xFF00

export type GrantStatus = 'granted' | 'denied' | 'denied_forbidden'

// 当前已注册的监听器：v3-2 起持久化句柄，便于 unbindAccessListener 对称解绑
let listenerRegistered = false
let lastTokenId: number = 0
// 持久 atManager 引用 + 注册过的权限集合，off 时必须传与 on 完全一致的 permissions 列表
let registeredAm: abilityAccessCtrl.AtManager | null = null
let registeredPermissions: AbilityPermissions[] | null = null

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
 * §21.3 修复教学债 #2：注册监听并持久化 atManager + permissions 句柄，
 * 配套 unbindAccessListener 在 aboutToDisappear 调用，单次进出不累积监听器。
 */
export function bindAccessListener(
  permissions: AbilityPermissions[],
  cb: (perm: AbilityPermissions, granted: boolean) => void
): void {
  // 防御：若上一轮 disappear 漏 off，先解绑旧的，确保单次注册
  if (registeredAm !== null && registeredPermissions !== null) {
    try {
      registeredAm.off('permissionStateChange', [], registeredPermissions)
      hilog.warn(DOMAIN, TAG, 'previous listener auto-unbound before re-bind')
    } catch (_e) {
      // 忽略：上一次未注册成功
    }
  }

  const am = abilityAccessCtrl.createAtManager()
  try {
    am.on('permissionStateChange', [], permissions, (data) => {
      const granted = data.change === abilityAccessCtrl.PermissionStateChangeType.PERMISSION_GRANTED_OPER
      cb(data.permissionName as AbilityPermissions, granted)
    })
    registeredAm = am
    registeredPermissions = permissions
    listenerRegistered = true
    hilog.info(DOMAIN, TAG, 'listener bound (will be symmetrically unbound — perf debt #2 fixed)')
  } catch (err) {
    const e = err as BusinessError
    hilog.error(DOMAIN, TAG, 'bind listener failed code=%{public}d msg=%{public}s', e.code, e.message)
  }
}

/**
 * §21.3 修复教学债 #2：对称解绑 — aboutToDisappear 调用，必须传与 on 一致的 permissions。
 * 解绑后字段级置空，避免悬挂引用。
 */
export function unbindAccessListener(): void {
  if (registeredAm === null || registeredPermissions === null) {
    return
  }
  try {
    registeredAm.off('permissionStateChange', [], registeredPermissions)
    hilog.info(DOMAIN, TAG, 'listener unbound (symmetric off — perf debt #2 fixed)')
  } catch (err) {
    const e = err as BusinessError
    hilog.error(DOMAIN, TAG, 'unbind listener failed code=%{public}d msg=%{public}s', e.code, e.message)
  } finally {
    registeredAm = null
    registeredPermissions = null
    listenerRegistered = false
  }
}

export function isListenerRegistered(): boolean {
  return listenerRegistered
}

export function setLastTokenId(tokenId: number): void {
  lastTokenId = tokenId
}

export function getLastTokenId(): number {
  return lastTokenId
}
