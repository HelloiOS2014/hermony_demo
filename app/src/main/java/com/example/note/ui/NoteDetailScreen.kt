// ui/NoteDetailScreen.kt
// 笔记详情 / 编辑屏。
//
// feat-2 阶段：
//   - 通过 NavHost 路由 detail/{id} 渲染
//   - 加载 ViewModel 中的笔记，显示标题 / 正文输入框
//   - 顶部「保存」回写到 ViewModel
// 后续：
//   - feat-4：在右上角加 CAMERA 权限触发 + 拒绝兜底 UI
//   - feat-6：再加 Share 按钮（Intent.ACTION_SEND）

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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NoteDetailScreen(
    noteId: Long,
    viewModel: NoteListViewModel,
    onBack: () -> Unit,
) {
    val origin = remember(noteId) { viewModel.get(noteId) }

    if (origin == null) {
        // 防御：传入未知 id 时给个友好兜底（不至于 NPE 闪退）
        Scaffold { padding ->
            Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center,
            ) { Text("笔记不存在（id=$noteId）") }
        }
        return
    }

    var title by rememberSaveable(noteId) { mutableStateOf(origin.title) }
    var content by rememberSaveable(noteId) { mutableStateOf(origin.content) }

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
