// ui/NoteDetailScreen.kt
// 笔记详情 / 编辑屏。
//
// feat-2：NavHost 路由 + 标题正文输入框 + 保存
// feat-3：通过 suspend get 从 Room 读取，LaunchedEffect 加载

package com.example.note.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.note.data.Note

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NoteDetailScreen(
    noteId: Long,
    viewModel: NoteListViewModel,
    onBack: () -> Unit,
) {
    var origin by remember(noteId) { mutableStateOf<Note?>(null) }
    var loaded by remember(noteId) { mutableStateOf(false) }

    LaunchedEffect(noteId) {
        origin = viewModel.get(noteId)
        loaded = true
    }

    if (!loaded) {
        Scaffold { padding ->
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        }
        return
    }

    val data = origin
    if (data == null) {
        Scaffold { padding ->
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                Text("笔记不存在（id=$noteId）")
            }
        }
        return
    }

    var title by rememberSaveable(noteId) { mutableStateOf(data.title) }
    var content by rememberSaveable(noteId) { mutableStateOf(data.content) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("笔记详情") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
                actions = {
                    IconButton(onClick = {
                        viewModel.update(noteId, title.trim(), content)
                        onBack()
                    }) {
                        Icon(Icons.Filled.Check, contentDescription = "保存")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .verticalScroll(rememberScrollState()),
        ) {
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = { Text("标题") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = content,
                onValueChange = { content = it },
                label = { Text("正文") },
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 240.dp),
            )
        }
    }
}
