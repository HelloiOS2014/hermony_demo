// ui/NoteListScreen.kt
// 笔记列表屏。
//
// feat-1：内存列表 + LazyColumn + 5 条预置
// feat-2：点击 Row 跳详情，FAB 新建后跳详情
// feat-3：ViewModel 数据源换成 Room Flow，重启保留数据

package com.example.note.ui

import android.app.Application
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.note.R
import com.example.note.data.Note
import com.example.note.data.NoteDao
import com.example.note.data.NoteDatabase
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * feat-3：Room 版 ViewModel。
 * - notes 来自 NoteDao.observeAll()，UI 用 collectAsState 订阅
 * - addBlank / update 都是 suspend，写库后 Flow 会自动推新值
 */
class NoteListViewModel(app: Application) : AndroidViewModel(app) {

    private val dao: NoteDao = NoteDatabase.get(app).noteDao()

    val notes: StateFlow<List<Note>> = dao.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    /** 创建一条空白笔记并将新生成的 rowId 通过回调返回（用于跳转详情）。 */
    fun addBlank(onCreated: (Long) -> Unit) {
        viewModelScope.launch {
            val now = System.currentTimeMillis()
            val nextSerial = (dao.count() + 1)
            val id = dao.insert(
                Note(id = 0, title = "新笔记 #$nextSerial", content = "", updatedAt = now)
            )
            onCreated(id)
        }
    }

    suspend fun get(id: Long): Note? = dao.findById(id)

    fun update(id: Long, title: String, content: String) {
        viewModelScope.launch {
            val cur = dao.findById(id) ?: return@launch
            dao.update(cur.copy(title = title, content = content, updatedAt = System.currentTimeMillis()))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NoteListScreen(
    viewModel: NoteListViewModel = viewModel(),
    darkOverride: Boolean? = null,
    onToggleDark: () -> Unit = {},
    onOpenDetail: (Long) -> Unit = {},
) {
    val notes by viewModel.notes.collectAsState()

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(stringResource(R.string.list_title)) },
                actions = {
                    IconButton(onClick = onToggleDark) {
                        // feat-5：当前深色态显示太阳图标（按下切回浅色），反之亦然
                        val isDarkActive = darkOverride == true
                        Icon(
                            imageVector = if (isDarkActive) Icons.Filled.LightMode else Icons.Filled.DarkMode,
                            contentDescription = stringResource(R.string.action_toggle_dark),
                        )
                    }
                },
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = {
                viewModel.addBlank { id -> onOpenDetail(id) }
            }) {
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
                    NoteRow(note, onClick = { onOpenDetail(note.id) })
                    HorizontalDivider()
                }
            }
        }
    }
}

@Composable
private fun NoteRow(note: Note, onClick: () -> Unit) {
    val fmt = remember { SimpleDateFormat("MM-dd HH:mm", Locale.getDefault()) }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
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
