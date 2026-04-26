// util/CameraPermission.kt
// 相机运行时权限工具：rememberCameraPermissionState 返回当前授权状态 + 触发请求的回调。
// 状态分三档：Idle（未请求） / Granted / Denied，UI 据此切到主流程或兜底卡片。

package com.example.note.util

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat

enum class CameraPermissionStatus { Idle, Granted, Denied }

class CameraPermissionState internal constructor(
    private val current: () -> CameraPermissionStatus,
    private val request: () -> Unit,
    private val setStatus: (CameraPermissionStatus) -> Unit,
) {
    val status: CameraPermissionStatus get() = current()
    fun requestIfNeeded() {
        if (status == CameraPermissionStatus.Granted) return
        request()
    }
    /** 教学用：方便单元 / 预览测试直接置态。 */
    internal fun setForPreview(s: CameraPermissionStatus) = setStatus(s)
}

private fun Context.cameraGrantedNow(): Boolean =
    ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
        PackageManager.PERMISSION_GRANTED

@Composable
fun rememberCameraPermissionState(): CameraPermissionState {
    val ctx = LocalContext.current
    var status by remember {
        mutableStateOf(
            if (ctx.cameraGrantedNow()) CameraPermissionStatus.Granted
            else CameraPermissionStatus.Idle
        )
    }
    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { granted ->
        status = if (granted) CameraPermissionStatus.Granted else CameraPermissionStatus.Denied
    }
    return remember {
        CameraPermissionState(
            current = { status },
            request = { launcher.launch(Manifest.permission.CAMERA) },
            setStatus = { status = it },
        )
    }
}
