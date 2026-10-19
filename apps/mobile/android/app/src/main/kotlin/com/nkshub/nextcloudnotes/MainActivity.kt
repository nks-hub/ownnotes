package com.nkshub.nextcloudnotes

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives text shared from other apps (Google Keep, Samsung Notes, ...) and
 * blocks screenshots on request. A FragmentActivity is what the device-unlock
 * prompt of local_auth needs.
 */
class MainActivity : FlutterFragmentActivity() {
    private var shared: Map<String, String>? = null
    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // A recreated activity still carries the old intent; it was taken already.
        if (savedInstanceState == null) shared = sharedText(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.nkshub.nextcloudnotes/share",
        ).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "takeShared") {
                    result.success(shared)
                    shared = null
                } else {
                    result.notImplemented()
                }
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.nkshub.nextcloudnotes/window",
        ).setMethodCallHandler { call, result ->
            if (call.method == "setSecure") {
                if (call.arguments == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        shared = sharedText(intent) ?: return
        channel?.invokeMethod("shared", null)
    }

    private fun sharedText(intent: Intent?): Map<String, String>? {
        if (intent?.action != Intent.ACTION_SEND) return null
        if (intent.type?.startsWith("text/") != true) return null
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
        return mapOf(
            "title" to (intent.getStringExtra(Intent.EXTRA_SUBJECT) ?: ""),
            "text" to text,
        )
    }
}
