// data/UserPrefsRepo.kt
// 用户偏好（DataStore Preferences）。
//
// feat-5：darkMode 持久化（true/false/null=跟随系统）
// feat-7：fontScale / sortDesc 等设置项

package com.example.note.data

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/** Application 作用域 DataStore 实例（property delegate）。 */
private val Context.userPrefsDataStore by preferencesDataStore(name = "user_prefs")

class UserPrefsRepo(private val ctx: Context) {

    private val store get() = ctx.applicationContext.userPrefsDataStore

    /** null = 跟随系统；true = 强制深色；false = 强制浅色。 */
    val darkMode: Flow<Boolean?> = store.data.map { it[KEY_DARK_MODE] }

    suspend fun setDarkMode(enabled: Boolean?) {
        store.edit { prefs ->
            if (enabled == null) prefs.remove(KEY_DARK_MODE)
            else prefs[KEY_DARK_MODE] = enabled
        }
    }

    /** feat-7：字号缩放（1.0 = 默认，0.85~1.30）。 */
    val fontScale: Flow<Float> = store.data.map { it[KEY_FONT_SCALE] ?: 1.0f }

    suspend fun setFontScale(value: Float) {
        store.edit { it[KEY_FONT_SCALE] = value.coerceIn(0.85f, 1.30f) }
    }

    /** feat-7：列表是否按更新时间倒序（默认 true）。 */
    val sortDesc: Flow<Boolean> = store.data.map { it[KEY_SORT_DESC] ?: true }

    suspend fun setSortDesc(desc: Boolean) {
        store.edit { it[KEY_SORT_DESC] = desc }
    }

    private companion object {
        val KEY_DARK_MODE: Preferences.Key<Boolean> = booleanPreferencesKey("dark_mode")
        val KEY_FONT_SCALE: Preferences.Key<Float> = floatPreferencesKey("font_scale")
        val KEY_SORT_DESC: Preferences.Key<Boolean> = booleanPreferencesKey("sort_desc")
    }
}
