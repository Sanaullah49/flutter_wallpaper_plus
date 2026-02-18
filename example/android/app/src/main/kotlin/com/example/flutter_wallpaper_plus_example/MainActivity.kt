package com.example.flutter_wallpaper_plus_example

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "ExampleMainActivity"
        private const val ENGINE_ID = "wallpaper_plus_example_engine"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate")
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume")
    }

    override fun onPause() {
        Log.d(TAG, "onPause")
        super.onPause()
    }

    override fun onStop() {
        Log.d(TAG, "onStop")
        super.onStop()
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
        super.onDestroy()
    }

    override fun getRenderMode(): RenderMode {
        // Texture mode is more resilient on some OEM ROMs (e.g., MIUI)
        // when the activity is torn down/recreated after wallpaper changes.
        return RenderMode.texture
    }

    override fun provideFlutterEngine(context: android.content.Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        val cached = cache.get(ENGINE_ID)
        if (cached != null) {
            Log.d(TAG, "provideFlutterEngine: reusing cached engine=${System.identityHashCode(cached)}")
            return cached
        }

        val engine = FlutterEngine(context.applicationContext)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        cache.put(ENGINE_ID, engine)
        Log.d(TAG, "provideFlutterEngine: created cached engine=${System.identityHashCode(engine)}")
        return engine
    }

    override fun shouldDestroyEngineWithHost(): Boolean {
        return false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine: engine=${System.identityHashCode(flutterEngine)}")
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        Log.d(TAG, "cleanUpFlutterEngine: engine=${System.identityHashCode(flutterEngine)}")
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
