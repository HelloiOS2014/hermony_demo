// DistributedNoteStore — v2-multidevice 跨设备笔记同步
//
// 与 §9.5 教程"分布式数据对象"小节对应：
//   distributedDataObject 是一个三层结构：
//     1. 本地缓存（同步写，立刻返回）
//     2. 同步队列（后台 fan-out 到对端）
//     3. 软总线广播（鸿蒙设备间直连优先，弱网降级到 IM 消息通道）
//
// 工作模型：
//   - 业务侧通过 setSessionId(<userId>_<bizId>) 加入同会话
//   - 所有同 sessionId 的设备共享一份对象（DistributedNoteListState）
//   - 任意端 set obj.notes = [...] → 对端 onChange 回调被触发，参数是变更字段名数组
//   - 写完不阻塞业务线程；断网时本地写仍生效，恢复后同步队列追发
//
// 与 NoteStore（v1）的关系：
//   - NoteStore 仍是 RDB 持久化的真源，DistributedNoteStore 不替换它
//   - 同步上：本地 NoteStore 变更 → 镜像到 distributedDataObject → 对端 onChange
//   - 同步下：对端 onChange → 把对象当前值写回本地 NoteStore（含 RDB）
//
// 教学债保留：DistributedNoteStore 是 v2 新增模块，**不**沿用 NoteStore 的整对象写
// 教学债 #3，因为 distributedDataObject 的同步层本身就要求 set 整字段（push 在部分
// 系统版本下不一定触发 fan-out）。教学债 #3 仅在 v1 NoteStore 内保留，§21.3 修复时
// 再演示 V2 @ObservedV2/@Trace 改造。

import distributedObject from '@ohos.data.distributedDataObject'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Note } from './Note'
import { NoteStore } from './NoteStore'

const TAG = 'DistributedNoteStore'
const DOMAIN = 0xFF00

// distributedDataObject 字段限制：number / string / boolean / 数组 / plain object
// 不能放 Date / Map / 自定义类实例（序列化边界）。Note 接口本身已是 plain shape，
// 整 notes 数组放进去即可。
interface DistributedNoteListState {
  notes: Note[]
  totalCount: number
  lastModifiedAtIso: string
}

export const DISTRIBUTED_STORE_KEY = 'distributedNoteStore'

// onChange 回调里要避免触发"对端再次 onChange"形成回调风暴（§9.5 反例 2）：
// 在 onChange 内只读 obj.notes，**不**再回写 obj 字段。
//
// status 事件携带 status: string（'online' | 'offline'）—— 用于 UI 提示对端断连。
export interface DistributedSyncListener {
  onChange: (notes: Note[], fields: string[]) => void
  onStatus: (networkId: string, status: 'online' | 'offline') => void
}

export class DistributedNoteStore {
  private obj: distributedObject.DataObject | null = null
  private currentSessionId: string = ''
  private listener: DistributedSyncListener | null = null
  private noteStore: NoteStore
  // 防回调风暴：对端 onChange → 写回本地 RDB → 再 mirror 到 obj 时跳过
  private suppressMirror: boolean = false

  constructor(noteStore: NoteStore) {
    this.noteStore = noteStore
  }

  // 必须在 EntryAbility.onCreate 里调（拿得到 UIAbilityContext）
  init(context: common.UIAbilityContext): void {
    const initial: DistributedNoteListState = {
      notes: [],
      totalCount: 0,
      lastModifiedAtIso: new Date().toISOString()
    }
    this.obj = distributedObject.create(context, initial)
    hilog.info(DOMAIN, TAG, 'init done')
  }

  // sessionId 设计：建议 <userId>_<bizId>，例如 'user123_notes'
  // 多端用相同 sessionId → 同步会话；切账号时调 leaveSession() 退出旧会话
  joinSession(sessionId: string, listener: DistributedSyncListener): void {
    if (this.obj === null) {
      hilog.warn(DOMAIN, TAG, 'joinSession skipped: not init')
      return
    }
    if (sessionId === '') {
      hilog.warn(DOMAIN, TAG, 'joinSession skipped: empty sessionId')
      return
    }
    if (this.currentSessionId === sessionId) {
      // 已加入同会话 —— 仅替换 listener
      this.listener = listener
      return
    }
    // 切会话前先解绑旧 listener
    this.detachListeners()

    this.currentSessionId = sessionId
    this.listener = listener
    this.obj.setSessionId(sessionId)
    hilog.info(DOMAIN, TAG, 'joinSession sessionId=%{public}s', sessionId)

    // change 事件：对端任何字段变更都会触发，参数是变更字段名列表
    this.obj.on('change', (sessionId: string, fields: string[]) => {
      hilog.info(DOMAIN, TAG, 'onChange sessionId=%{public}s fields=%{public}s',
        sessionId, fields.join(','))
      const remoteNotes = this.obj?.notes as Note[] | undefined
      if (remoteNotes !== undefined) {
        // 把对端值写回本地 NoteStore（异步），并通知 UI
        this.applyRemoteToLocal(remoteNotes)
        if (this.listener !== null) {
          this.listener.onChange(remoteNotes, fields)
        }
      }
    })

    // status 事件：对端设备上线 / 下线
    this.obj.on('status', (sessionId: string, networkId: string, status: string) => {
      hilog.info(DOMAIN, TAG, 'onStatus sessionId=%{public}s networkId=%{public}s status=%{public}s',
        sessionId, networkId, status)
      if (this.listener !== null && (status === 'online' || status === 'offline')) {
        this.listener.onStatus(networkId, status as 'online' | 'offline')
      }
    })
  }

  // 退出会话：close 后本地缓存保留，但不再 fan-out
  // 必须在用户关闭同步开关 / 切账号 / Ability onDestroy 时调
  leaveSession(): void {
    if (this.obj === null) {
      return
    }
    this.detachListeners()
    if (this.currentSessionId !== '') {
      this.obj.setSessionId('')
      hilog.info(DOMAIN, TAG, 'leaveSession sessionId=%{public}s', this.currentSessionId)
    }
    this.currentSessionId = ''
    this.listener = null
  }

  // 业务侧：本地 NoteStore 变更后调，把整 notes 数组镜像到分布式对象
  // 注意：替换整个数组而不是 push（§9.5 反例 1）
  mirrorLocalToRemote(): void {
    if (this.obj === null || this.currentSessionId === '' || this.suppressMirror) {
      return
    }
    const local = this.noteStore.snapshot()
    this.obj.notes = local
    this.obj.totalCount = local.length
    this.obj.lastModifiedAtIso = new Date().toISOString()
  }

  // 对端 onChange → 写回本地 RDB
  // 简化策略：以远端 notes 为准做 diff（add 新增 / update 已变 / remove 已无）
  // 生产场景需要 LWW（按 updatedAt 取胜者）+ 删除墓碑表，此处只做最简同步演示
  private async applyRemoteToLocal(remoteNotes: Note[]): Promise<void> {
    this.suppressMirror = true
    try {
      const localById = new Map<string, Note>()
      for (const n of this.noteStore.snapshot()) {
        localById.set(n.id, n)
      }
      const remoteIds = new Set<string>()
      for (const r of remoteNotes) {
        remoteIds.add(r.id)
        const local = localById.get(r.id)
        if (local === undefined) {
          await this.noteStore.add(r)
        } else if (local.updatedAt < r.updatedAt) {
          // last-write-wins：远端 updatedAt 更新 → 本地覆盖
          await this.noteStore.update(r)
        }
      }
      // 远端没有的笔记：本仓未做删除墓碑，故不主动删除（避免离线端启动时把对端清空）
      // 真实业务请用 distributedKVStore 单独存 tombstone，本 demo 仅同步 add/update
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'applyRemoteToLocal error %{public}s', JSON.stringify(e))
    } finally {
      this.suppressMirror = false
    }
  }

  private detachListeners(): void {
    if (this.obj === null) {
      return
    }
    try {
      this.obj.off('change')
      this.obj.off('status')
    } catch (_e) {
      // 重复 off 在部分版本会抛 —— 安全忽略
    }
  }

  // 测试 / 调试用
  isJoined(): boolean {
    return this.currentSessionId !== ''
  }

  getSessionId(): string {
    return this.currentSessionId
  }
}
