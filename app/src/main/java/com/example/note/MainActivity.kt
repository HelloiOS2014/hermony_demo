// MainActivity.kt
// §21.5 笔记 App 单 Activity 入口。
// feat-1：直接挂 NoteListScreen；feat-2 起替换为 NavHost。

package com.example.note

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.example.note.ui.NoteListScreen
import com.example.note.ui.theme.HermonyNoteTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            HermonyNoteTheme {
                NoteListScreen()
            }
        }
    }
}
