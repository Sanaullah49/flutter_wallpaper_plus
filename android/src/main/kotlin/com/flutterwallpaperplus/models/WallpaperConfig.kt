package com.flutterwallpaperplus.models

/**
 * Internal configuration parsed from Dart method call arguments.
 *
 * This is a pure data class with no Android framework dependencies,
 * making it easy to test and pass between components.
 *
 * All fields have sensible defaults so partial argument maps
 * from Dart don't cause crashes.
 */
data class WallpaperConfig(
    /** Source type: "asset", "file", or "url" */
    val sourceType: String,
    /** Source path, file path, or URL */
    val sourcePath: String,
    /** Target screen: "home", "lock", or "both" */
    val target: String,
    /** Whether to play audio in video wallpapers */
    val enableAudio: Boolean = false,
    /** Whether to loop video wallpapers */
    val loop: Boolean = true,
    /** Toast message to display on success */
    val successMessage: String = "Wallpaper set successfully",
    /** Toast message to display on error (fallback) */
    val errorMessage: String = "Failed to set wallpaper",
    /** Whether to show Android Toast notifications */
    val showToast: Boolean = true,
    /** Whether to send user to home screen as best-effort after launch/apply */
    val goToHome: Boolean = false,
) {
    companion object {
        /**
         * Parses a [WallpaperConfig] from a method call arguments map.
         *
         * @param map The arguments map from Flutter's MethodCall.
         * @return A fully populated [WallpaperConfig].
         * @throws IllegalArgumentException if the "source" key is missing
         *   or not a Map.
         */
        @Suppress("UNCHECKED_CAST")
        fun fromMap(map: Map<String, Any?>): WallpaperConfig {
            val source = map["source"] as? Map<String, Any?>
                ?: throw IllegalArgumentException(
                    "Missing or invalid 'source' argument. " +
                            "Expected Map with 'type' and 'path' keys."
                )

            val sourceType = source["type"] as? String
                ?: throw IllegalArgumentException(
                    "Missing 'type' in source argument"
                )

            val sourcePath = source["path"] as? String
                ?: throw IllegalArgumentException(
                    "Missing 'path' in source argument"
                )

            return WallpaperConfig(
                sourceType = sourceType,
                sourcePath = sourcePath,
                target = map["target"] as? String ?: "both",
                enableAudio = map["enableAudio"] as? Boolean ?: false,
                loop = map["loop"] as? Boolean ?: true,
                successMessage = map["successMessage"] as? String
                    ?: "Wallpaper set successfully",
                errorMessage = map["errorMessage"] as? String
                    ?: "Failed to set wallpaper",
                showToast = map["showToast"] as? Boolean ?: true,
                goToHome = map["goToHome"] as? Boolean ?: false,
            )
        }
    }

    /**
     * Validates that the source path is non-empty.
     *
     * @return true if the configuration appears valid.
     */
    fun isValid(): Boolean {
        return sourcePath.isNotBlank() &&
                sourceType in listOf("asset", "file", "url") &&
                target in listOf("home", "lock", "both")
    }
}
