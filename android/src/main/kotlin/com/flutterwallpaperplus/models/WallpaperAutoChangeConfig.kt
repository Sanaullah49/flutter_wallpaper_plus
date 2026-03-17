package com.flutterwallpaperplus.models

/**
 * Source entry for Wallpaper Auto Change.
 */
data class WallpaperAutoChangeSource(
    val sourceType: String,
    val sourcePath: String,
)

/**
 * Parsed configuration for Wallpaper Auto Change V1.
 *
 * V1 intentionally stays simple:
 * - image sources only
 * - one interval for the whole playlist
 * - one target for the whole playlist
 */
data class WallpaperAutoChangeConfig(
    val sources: List<WallpaperAutoChangeSource>,
    val target: String,
    val intervalMinutes: Int,
    val successMessage: String = "Wallpaper Auto Change started",
    val errorMessage: String = "Failed to start Wallpaper Auto Change",
    val showToast: Boolean = true,
    val goToHome: Boolean = false,
) {
    companion object {
        @Suppress("UNCHECKED_CAST")
        fun fromMap(map: Map<String, Any?>): WallpaperAutoChangeConfig {
            val rawSources = map["sources"] as? List<*>
                ?: throw IllegalArgumentException(
                    "Missing or invalid 'sources'. Expected a List of source maps."
                )

            val sources = rawSources.mapIndexed { index, raw ->
                val source = raw as? Map<String, Any?>
                    ?: throw IllegalArgumentException(
                        "Invalid source at index $index. Expected Map with 'type' and 'path'."
                    )
                WallpaperAutoChangeSource(
                    sourceType = source["type"] as? String
                        ?: throw IllegalArgumentException(
                            "Missing 'type' in source at index $index."
                        ),
                    sourcePath = source["path"] as? String
                        ?: throw IllegalArgumentException(
                            "Missing 'path' in source at index $index."
                        ),
                )
            }

            val intervalMinutes = when (val raw = map["intervalMinutes"]) {
                is Int -> raw
                is Long -> raw.toInt()
                is Double -> raw.toInt()
                else -> throw IllegalArgumentException(
                    "Missing or invalid 'intervalMinutes'. Expected integer minutes."
                )
            }

            return WallpaperAutoChangeConfig(
                sources = sources,
                target = map["target"] as? String ?: "home",
                intervalMinutes = intervalMinutes,
                successMessage = map["successMessage"] as? String
                    ?: "Wallpaper Auto Change started",
                errorMessage = map["errorMessage"] as? String
                    ?: "Failed to start Wallpaper Auto Change",
                showToast = map["showToast"] as? Boolean ?: true,
                goToHome = map["goToHome"] as? Boolean ?: false,
            )
        }
    }

    fun isValid(): Boolean {
        if (intervalMinutes < 1) return false
        if (sources.isEmpty()) return false
        if (target !in listOf("home", "lock", "both")) return false
        return sources.all { source ->
            source.sourceType in listOf("asset", "file", "url") &&
                    source.sourcePath.isNotBlank()
        }
    }
}
