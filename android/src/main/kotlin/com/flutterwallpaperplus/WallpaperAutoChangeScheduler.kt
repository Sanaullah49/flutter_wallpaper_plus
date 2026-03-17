package com.flutterwallpaperplus

import android.content.Context
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/**
 * Schedules the next Wallpaper Auto Change work item.
 */
internal object WallpaperAutoChangeScheduler {
    private const val AUTO_CHANGE_WORK_NAME = "flutter_wallpaper_plus_auto_change"

    fun schedule(context: Context, intervalMinutes: Int) {
        val request = OneTimeWorkRequestBuilder<WallpaperAutoChangeWorker>()
            .setInitialDelay(intervalMinutes.toLong(), TimeUnit.MINUTES)
            .build()

        WorkManager.getInstance(context).enqueueUniqueWork(
            AUTO_CHANGE_WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            request,
        )
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(AUTO_CHANGE_WORK_NAME)
    }
}
