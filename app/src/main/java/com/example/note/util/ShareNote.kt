// util/ShareNote.kt
// 系统分享：把笔记标题 + 正文打包成 ACTION_SEND，弹分享 chooser。
// chooser 强制每次都弹（教学项目），生产代码可改用一次性默认 app 选择。

package com.example.note.util

import android.content.Context
import android.content.Intent
import com.example.note.R

object ShareNote {

    fun share(ctx: Context, title: String, content: String) {
        val template = ctx.getString(R.string.share_template, title, content)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_SUBJECT, title)
            putExtra(Intent.EXTRA_TEXT, template)
        }
        val chooser = Intent.createChooser(send, ctx.getString(R.string.share_chooser_title))
        // 从非 Activity Context 启动时必须加 NEW_TASK
        if (ctx !is android.app.Activity) chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ctx.startActivity(chooser)
    }
}
