// MainActivity.kt
// §21.5 笔记 App 单 Activity 入口。
//
// feat-1：直接挂 NoteListScreen
// feat-2：替换为 NavHost，路由表 list / detail/{id}
// feat-5：监听 UserPrefsRepo.darkMode → 决定 HermonyNoteTheme(darkTheme)
//        + AppCompatDelegate.setDefaultNightMode 同步系统级配色
//        + DataStore 持久化，重启保留

package com.example.note

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.appcompat.app.AppCompatDelegate
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.example.note.data.UserPrefsRepo
import com.example.note.ui.NoteDetailScreen
import com.example.note.ui.NoteListScreen
import com.example.note.ui.NoteListViewModel
import com.example.note.ui.SettingsScreen
import com.example.note.ui.theme.HermonyNoteTheme
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val prefs = UserPrefsRepo(applicationContext)

        setContent {
            val darkOverride by prefs.darkMode.collectAsState(initial = null)
            val systemDark = isSystemInDarkTheme()
            val effectiveDark = darkOverride ?: systemDark

            // 同步 AppCompat NightMode（影响 status bar / Activity 重建窗口配色）
            LaunchedSyncNightMode(darkOverride)

            HermonyNoteTheme(darkTheme = effectiveDark) {
                val nav = rememberNavController()
                val vm: NoteListViewModel = viewModel()

                NavHost(navController = nav, startDestination = "list") {
                    composable("list") {
                        NoteListScreen(
                            viewModel = vm,
                            darkOverride = darkOverride,
                            onToggleDark = {
                                CoroutineScope(Dispatchers.IO).launch {
                                    val next = when (darkOverride) {
                                        null -> !systemDark    // 第一次按：与当前实际相反
                                        true -> false
                                        false -> true
                                    }
                                    prefs.setDarkMode(next)
                                }
                            },
                            onOpenDetail = { id -> nav.navigate("detail/$id") },
                            onOpenSettings = { nav.navigate("settings") },
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
                    composable("settings") {
                        SettingsScreen(onBack = { nav.popBackStack() })
                    }
                }
            }
        }
    }
}

/**
 * 把 DataStore 中的 darkOverride 同步到 AppCompatDelegate.NightMode，
 * 让窗口装饰（状态栏 / 导航栏）跟着切换。
 */
@androidx.compose.runtime.Composable
private fun LaunchedSyncNightMode(darkOverride: Boolean?) {
    androidx.compose.runtime.LaunchedEffect(darkOverride) {
        AppCompatDelegate.setDefaultNightMode(
            when (darkOverride) {
                null -> AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM
                true -> AppCompatDelegate.MODE_NIGHT_YES
                false -> AppCompatDelegate.MODE_NIGHT_NO
            }
        )
    }
}
