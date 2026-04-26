// data/NoteDatabase.kt
// Room Database 单例 + 首次启动 5 条预置笔记 seed。

package com.example.note.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

@Database(entities = [Note::class], version = 1, exportSchema = false)
abstract class NoteDatabase : RoomDatabase() {

    abstract fun noteDao(): NoteDao

    companion object {
        @Volatile private var instance: NoteDatabase? = null

        fun get(context: Context): NoteDatabase = instance ?: synchronized(this) {
            instance ?: build(context.applicationContext).also { instance = it }
        }

        private fun build(ctx: Context): NoteDatabase {
            val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
            return Room.databaseBuilder(ctx, NoteDatabase::class.java, "hermony-note.db")
                .addCallback(object : Callback() {
                    override fun onCreate(db: SupportSQLiteDatabase) {
                        // 数据库首次创建时插入预置数据，重启 App 不会重复 seed
                        scope.launch {
                            instance?.noteDao()?.insertAll(seed())
                        }
                    }
                })
                .build()
        }

        private fun seed(): List<Note> {
            val base = System.currentTimeMillis()
            return listOf(
                Note(0, "和音笔记 · 欢迎",      "这是 §21.5 教学项目首屏第 1 条预置笔记。", base - 60_000),
                Note(0, "Compose 列表渲染要点", "LazyColumn + items(key = ) 比 Column 滚动性能更好。", base - 120_000),
                Note(0, "Room 数据流",          "DAO 返回 Flow<List<Entity>>，UI 用 collectAsState。", base - 180_000),
                Note(0, "运行时权限",           "API 23+ 需要在使用前 requestPermissions。", base - 240_000),
                Note(0, "深色主题",             "values-night/ 限定符 + setDefaultNightMode。", base - 300_000),
            )
        }
    }
}
