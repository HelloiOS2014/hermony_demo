// ShareNote — 用 shareKit 拉起系统分享 sheet
//
// 鸿蒙的系统分享 = systemShareComponent.shareController + ShareData。
// 笔记导出文本 + tags 拼接，让用户可以分享到 IM / 邮件 / 备忘录等系统级支持的
// 任意应用。

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
