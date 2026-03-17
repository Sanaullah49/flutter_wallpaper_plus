package com.flutterwallpaperplus

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

/**
 * WorkManager entry point for the next Wallpaper Auto Change run.
 */
internal class WallpaperAutoChangeWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val runner = WallpaperAutoChangeRunner(applicationContext)
        val store = WallpaperAutoChangeStore(applicationContext)

        runner.applyNext(goToHome = false)

        if (store.isRunning()) {
            val intervalMinutes = store.getIntervalMinutes()
            if (intervalMinutes > 0) {
                WallpaperAutoChangeScheduler.schedule(
                    applicationContext,
                    intervalMinutes
                )
            }
        }

        return Result.success()
    }
}
