// ui/NoteDetailScreen.kt
// 笔记详情 / 编辑屏。
//
// feat-2：NavHost 路由 + 标题正文输入框 + 保存
// feat-3：通过 suspend get 从 Room 读取，LaunchedEffect 加载
// feat-4：右上角"拍照插入"按钮 + runtime CAMERA 权限 + 拒绝兜底卡片

package com.example.note.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.example.note.R
import com.example.note.data.Note
import com.example.note.util.CameraPermissionStatus
import com.example.note.util.rememberCameraPermissionState

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

    // feat-4：相机权限状态
    val camera = rememberCameraPermissionState()

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
                    IconButton(onClick = { camera.requestIfNeeded() }) {
                        Icon(
                            Icons.Filled.PhotoCamera,
                            contentDescription = stringResource(R.string.action_camera),
                        )
                    }
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
            // feat-4：权限态分支 UI
            when (camera.status) {
                CameraPermissionStatus.Idle -> {
                    AssistRationaleCard(
                        text = stringResource(R.string.perm_camera_rationale),
                        actionText = stringResource(R.string.action_camera),
                        onAction = { camera.requestIfNeeded() },
                    )
                    Spacer(Modifier.height(12.dp))
                }
                CameraPermissionStatus.Denied -> {
                    AssistDeniedCard(text = stringResource(R.string.perm_camera_denied))
                    Spacer(Modifier.height(12.dp))
                }
                CameraPermissionStatus.Granted -> {
                    AssistGrantedCard(text = stringResource(R.string.perm_camera_granted))
                    Spacer(Modifier.height(12.dp))
                }
            }

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

@Composable
private fun AssistRationaleCard(text: String, actionText: String, onAction: () -> Unit) {
    ElevatedCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
            Spacer(Modifier.width(8.dp))
            TextButton(onClick = onAction) { Text(actionText) }
        }
    }
}

@Composable
private fun AssistDeniedCard(text: String) {
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.elevatedCardColors(
            containerColor = MaterialTheme.colorScheme.errorContainer,
            contentColor = MaterialTheme.colorScheme.onErrorContainer,
        ),
    ) {
        Text(text, modifier = Modifier.padding(12.dp), style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun AssistGrantedCard(text: String) {
    ElevatedCard(modifier = Modifier.fillMaxWidth()) {
        Text(text, modifier = Modifier.padding(12.dp), style = MaterialTheme.typography.bodyMedium)
    }
}
