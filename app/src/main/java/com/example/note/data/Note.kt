// data/Note.kt
// 笔记数据模型。
//
// feat-1：纯 data class（内存）
// feat-3：升级为 @Entity，由 Room 持久化到 SQLite

package com.example.note.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "notes")
data class Note(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val title: String,
    val content: String,
    val updatedAt: Long, // epoch millis
)
