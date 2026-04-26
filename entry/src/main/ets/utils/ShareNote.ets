// ShareNote — 用 shareKit 拉起系统分享 sheet
//
// 鸿蒙的系统分享 = systemShareComponent.shareController + ShareData。
// 笔记导出文本 + tags 拼接，让用户可以分享到 IM / 邮件 / 备忘录等系统级支持的
// 任意应用。
//
// ╔══════════════════════════════════════════════════════════════════════╗
// ║ §21.5 [feat-6] Android → HarmonyOS NEXT 迁移要点                      ║
// ╠══════════════════════════════════════════════════════════════════════╣
// ║ Android 原工程（v5-android-source 分支 [feat-6]）                     ║
// ║   - util/ShareNote.kt：                                              ║
// ║       Intent(ACTION_SEND).apply {                                     ║
// ║         type = "text/plain"                                           ║
// ║         putExtra(EXTRA_SUBJECT, title)                                ║
// ║         putExtra(EXTRA_TEXT, template)                                ║
// ║       }                                                               ║
// ║   - Intent.createChooser(send, "分享到…")                             ║
// ║   - 长按列表项 / 详情 ShareIcon → 弹分享 chooser                       ║
// ║                                                                      ║
// ║ HarmonyOS 对应实现（本文件）                                          ║
// ║   - systemShare.ShareController({ data: utd.UDC.text, ... })         ║
// ║   - controller.show(context, ShareController.Anchor) 弹原生面板       ║
// ║   - utd.UniformDataType.TEXT 表示纯文本类型                          ║
// ║                                                                      ║
// ║ 关键映射                                                              ║
// ║   Intent.ACTION_SEND text/plain                                       ║
// ║       ↔  systemShare.ShareData({ utd.UniformDataType.TEXT })         ║
// ║   Intent.EXTRA_SUBJECT / EXTRA_TEXT                                   ║
// ║       ↔  ShareData.title / ShareData.content                          ║
// ║   Intent.createChooser(intent, title)                                 ║
// ║       ↔  systemShare.ShareController.show(uiCtx, anchor)             ║
// ║   FLAG_ACTIVITY_NEW_TASK                                              ║
// ║       ↔  无需，鸿蒙必须从 UIContext 启动（不能从 ApplicationContext） ║
// ║   combinedClickable.onLongClick                                       ║
// ║       ↔  .gesture(LongPressGesture().onAction(...))                  ║
// ║                                                                      ║
// ║ 注意点（迁移踩坑）                                                    ║
// ║   1. Android Intent 是松耦合协议，目标 App 用 IntentFilter 自助匹配；  ║
// ║      鸿蒙 ShareKit 通过 utd.UniformDataType 强类型 + 系统调度，         ║
// ║      未声明 utd 类型的 App 不会出现在分享面板                         ║
// ║   2. createChooser 每次都弹；ShareController.show 同样可控显隐，      ║
// ║      但必须从 UIContext 调用（页面销毁后调会抛异常）                  ║
// ║   3. 富文本 / 图片 / 文件需要切换到 utd.UniformDataType.IMAGE 等，    ║
// ║      Android 用 EXTRA_STREAM + Uri；鸿蒙用 ShareData.uri + utd        ║
// ╚══════════════════════════════════════════════════════════════════════╝

import { common } from '@kit.AbilityKit'
import { systemShare } from '@kit.ShareKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Note } from '../data/Note'

const TAG = 'ShareNote'
const DOMAIN = 0xFF00

export async function shareNote(context: common.UIAbilityContext, note: Note): Promise<void> {
  const tagLine = note.tags.length > 0 ? '\n\n标签：' + note.tags.join(' / ') : ''
  const text = '【' + note.title + '】\n\n' + note.content + tagLine
  const shareData: systemShare.SharedData = new systemShare.SharedData({
    utd: utd.UniformDataType.PLAIN_TEXT,
    content: text,
    title: note.title,
    description: note.tags.length > 0 ? note.tags.join(' / ') : '来自 Hermony 笔记'
  })
  const controller: systemShare.ShareController = new systemShare.ShareController(shareData)
  try {
    await controller.show(context, {
      previewMode: systemShare.SharePreviewMode.DETAIL,
      selectionMode: systemShare.SelectionMode.SINGLE
    })
    hilog.info(DOMAIN, TAG, 'share sheet shown for note=%{public}s', note.id)
  } catch (err) {
    const e = err as BusinessError
    hilog.error(DOMAIN, TAG, 'share failed code=%{public}d msg=%{public}s', e.code, e.message)
    throw err as Error
  }
}
