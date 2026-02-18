package com.flutterwallpaperplus

import android.os.Build
import java.util.Locale

/**
 * Centralized OEM policy checks for target reliability.
 *
 * Some OEM ROMs apply additional wallpaper restrictions that make
 * lock-screen targets unreliable for third-party apps.
 */
object OemPolicy {
    private val restrictiveVendors = listOf(
        "xiaomi",
        "redmi",
        "oppo",
        "vivo",
        "realme",
    )

    fun manufacturerRaw(): String = Build.MANUFACTURER.orEmpty()

    fun modelRaw(): String = Build.MODEL.orEmpty()

    fun manufacturerNormalized(): String = manufacturerRaw().lowercase(Locale.US)

    fun isRestrictiveOem(): Boolean {
        val manufacturer = manufacturerNormalized()
        return restrictiveVendors.any { key -> manufacturer.contains(key) }
    }
}
