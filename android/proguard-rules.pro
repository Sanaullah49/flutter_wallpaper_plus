# ============================================================
# Flutter Wallpaper Plus — ProGuard / R8 Rules
# ============================================================

# Keep the plugin class (loaded via reflection by Flutter)
-keep class com.flutterwallpaperplus.FlutterWallpaperPlusPlugin { *; }

# Keep the wallpaper service (declared in AndroidManifest)
-keep public class com.flutterwallpaperplus.VideoWallpaperService { *; }

# Keep all model classes (serialized via maps)
-keep class com.flutterwallpaperplus.models.** { *; }

# ExoPlayer / Media3
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep interface androidx.media3.** { *; }

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Kotlin coroutines
-keepclassmembers class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Keep wallpaper service inner engine class
-keep class com.flutterwallpaperplus.VideoWallpaperService$* { *; }

# General Android rules
-keep public class * extends android.service.wallpaper.WallpaperService
-keepclassmembers class * extends android.service.wallpaper.WallpaperService {
    public <methods>;
}