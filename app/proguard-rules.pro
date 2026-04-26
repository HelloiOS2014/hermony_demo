# proguard-rules.pro
# Compose / Kotlin 反射保留，Room 实体类不混淆字段名。

-keep class com.example.note.data.** { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase { *; }
-dontwarn androidx.compose.**
