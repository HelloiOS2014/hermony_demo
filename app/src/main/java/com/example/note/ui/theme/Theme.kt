// ui/theme/Theme.kt
// Material3 主题包装：feat-1 只支持浅色主题，feat-5 起接入 darkTheme 参数。

package com.example.note.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = Brand40,
    onPrimary = Color(0xFFFFFFFF),
    surface = Surface,
    onSurface = OnSurface,
)

private val DarkColors = darkColorScheme(
    primary = Brand80,
    onPrimary = Color(0xFF002F65),
    surface = SurfaceDark,
    onSurface = OnSurfaceDark,
)

@Composable
fun HermonyNoteTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colors = if (darkTheme) DarkColors else LightColors
    MaterialTheme(colorScheme = colors, content = content)
}
