// ui/NoteListScreen.kt
// 笔记列表屏。
//
// feat-1 阶段：
//   - 使用 ViewModel 维护内存中的 List<Note>
//   - LazyColumn 渲染 + 5 条预置笔记 + 空态
// 后续：
//   - feat-2 增加点击跳转详情
//   - feat-3 把 ViewModel 数据源换成 Room Flow

package com.example.note.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.note.R
import com.example.note.data.Note
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** feat-1：内存版 ViewModel。feat-3 会被替换为依赖 NoteDao 的版本。 */
class NoteListViewModel : ViewModel() {

    private val _notes = MutableStateFlow(seedNotes())
    val notes: StateFlow<List<Note>> = _notes.asStateFlow()

    fun addBlank() {
        val now = System.currentTimeMillis()
        val next = (_notes.value.maxOfOrNull { it.id } ?: 0L) + 1
        _notes.value = listOf(
            Note(
                id = next,
                title = "新笔记 #$next",
                content = "",
                updatedAt = now,
            )
        ) + _notes.value
    }

    private fun seedNotes(): List<Note> {
        val base = System.currentTimeMillis()
        return listOf(
            Note(1, "和音笔记 · 欢迎",      "这是 §21.5 教学项目首屏第 1 条预置笔记。", base - 60_000),
            Note(2, "Compose 列表渲染要点", "LazyColumn + items(key = ) 比 Column 滚动性能更好。", base - 120_000),
            Note(3, "Room 数据流",          "DAO 返回 Flow<List<Entity>>，UI 用 collectAsState。", base - 180_000),
            Note(4, "运行时权限",           "API 23+ 需要在使用前 requestPermissions。", base - 240_000),
            Note(5, "深色主题",             "values-night/ 限定符 + setDefaultNightMode。", base - 300_000),
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NoteListScreen(
    viewModel: NoteListViewModel = viewModel(),
) {
    val notes by viewModel.notes.collectAsState()

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(stringResource(R.string.list_title)) },
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = { viewModel.addBlank() }) {
                Icon(Icons.Filled.Add, contentDescription = stringResource(R.string.action_new))
            }
        },
    ) { padding ->
        if (notes.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    stringResource(R.string.list_empty),
                    style = MaterialTheme.typography.bodyLarge,
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(vertical = 8.dp),
            ) {
                items(items = notes, key = { it.id }) { note ->
                    NoteRow(note)
                    HorizontalDivider()
                }
            }
        }
    }
}

@Composable
private fun NoteRow(note: Note) {
    val fmt = remember { SimpleDateFormat("MM-dd HH:mm", Locale.getDefault()) }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Text(
            text = note.title,
            style = MaterialTheme.typography.titleMedium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = fmt.format(Date(note.updatedAt)),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
    }
}
