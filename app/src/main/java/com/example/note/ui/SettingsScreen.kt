// ui/SettingsScreen.kt
// 设置页（feat-7）。
//
// 三组偏好：
//   1. 深色模式（与 feat-5 共用 UserPrefsRepo.darkMode；这里只读 + Switch）
//   2. 字号缩放（fontScale 0.85 ~ 1.30，Slider）
//   3. 列表排序（sortDesc，Switch；ViewModel 已订阅 → 切换立即生效）
//   + 关于条目
//
// 全部走 DataStore Preferences，重启 App 仍保留。

package com.example.note.ui

import android.app.Application
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.note.R
import com.example.note.data.UserPrefsRepo
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class SettingsViewModel(app: Application) : AndroidViewModel(app) {
    private val repo = UserPrefsRepo(app)

    val darkMode: StateFlow<Boolean?> = repo.darkMode
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)
    val fontScale: StateFlow<Float> = repo.fontScale
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), 1.0f)
    val sortDesc: StateFlow<Boolean> = repo.sortDesc
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), true)

    fun setDark(value: Boolean) = viewModelScope.launch { repo.setDarkMode(value) }
    fun setFontScale(value: Float) = viewModelScope.launch { repo.setFontScale(value) }
    fun setSortDesc(value: Boolean) = viewModelScope.launch { repo.setSortDesc(value) }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onBack: () -> Unit,
    viewModel: SettingsViewModel = viewModel(),
) {
    val dark by viewModel.darkMode.collectAsState()
    val fs by viewModel.fontScale.collectAsState()
    val desc by viewModel.sortDesc.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.settings_title)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState()),
        ) {
            SwitchRow(
                title = stringResource(R.string.settings_dark_mode),
                summary = stringResource(R.string.settings_dark_mode_summary),
                checked = dark == true,
                onChange = viewModel::setDark,
            )
            HorizontalDivider()

            SliderRow(
                title = stringResource(R.string.settings_font_scale),
                summary = stringResource(R.string.settings_font_scale_summary),
                value = fs,
                valueRange = 0.85f..1.30f,
                steps = 8, // 0.05 步进
                display = { String.format("%.2fx", it) },
                onChange = viewModel::setFontScale,
            )
            HorizontalDivider()

            SwitchRow(
                title = stringResource(R.string.settings_sort_desc),
                summary = stringResource(R.string.settings_sort_desc_summary),
                checked = desc,
                onChange = viewModel::setSortDesc,
            )
            HorizontalDivider()

            AboutRow(
                title = stringResource(R.string.settings_about),
                summary = stringResource(R.string.settings_about_summary),
            )
        }
    }
}

@Composable
private fun SwitchRow(
    title: String,
    summary: String,
    checked: Boolean,
    onChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(2.dp))
            Text(
                summary,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
        }
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

@Composable
private fun SliderRow(
    title: String,
    summary: String,
    value: Float,
    valueRange: ClosedFloatingPointRange<Float>,
    steps: Int,
    display: (Float) -> String,
    onChange: (Float) -> Unit,
) {
    Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(title, modifier = Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
            Text(display(value), style = MaterialTheme.typography.titleMedium)
        }
        Text(
            summary,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
        Slider(
            value = value,
            onValueChange = onChange,
            valueRange = valueRange,
            steps = steps,
        )
    }
}

@Composable
private fun AboutRow(title: String, summary: String) {
    Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
        Text(title, style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(2.dp))
        Text(
            summary,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
    }
}
