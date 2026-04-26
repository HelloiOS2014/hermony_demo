// data/Note.kt
// 笔记数据模型。
// feat-1 阶段是普通 data class（内存列表）；feat-3 RDB 加 @Entity 注解。

package com.example.note.data

data class Note(
    val id: Long,
    val title: String,
    val content: String,
    val updatedAt: Long, // epoch millis
)
