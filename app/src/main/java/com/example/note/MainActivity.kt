// MainActivity.kt
// §21.5 笔记 App 单 Activity 入口。
//
// feat-1：直接挂 NoteListScreen
// feat-2：替换为 NavHost，路由表 list / detail/{id}

package com.example.note

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.example.note.ui.NoteDetailScreen
import com.example.note.ui.NoteListScreen
import com.example.note.ui.NoteListViewModel
import com.example.note.ui.theme.HermonyNoteTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            HermonyNoteTheme {
                val nav = rememberNavController()
                // ViewModel 提到 Activity 作用域：列表 / 详情共享同一份数据
                val vm: NoteListViewModel = viewModel()

                NavHost(navController = nav, startDestination = "list") {
                    composable("list") {
                        NoteListScreen(
                            viewModel = vm,
                            onOpenDetail = { id -> nav.navigate("detail/$id") },
                        )
                    }
                    composable(
                        route = "detail/{id}",
                        arguments = listOf(navArgument("id") { type = NavType.LongType }),
                    ) { backStack ->
                        val id = backStack.arguments?.getLong("id") ?: -1L
                        NoteDetailScreen(
                            noteId = id,
                            viewModel = vm,
                            onBack = { nav.popBackStack() },
                        )
                    }
                }
            }
        }
    }
}
