package com.nkshub.nextcloudnotes

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
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
        // Long press on the launcher icon: "New note", handled like the
        // widget's "+" (home_widget launch intent with ownnotes://new).
        ShortcutManagerCompat.pushDynamicShortcut(
            this,
            ShortcutInfoCompat.Builder(this, "new_note")
                .setShortLabel(getString(R.string.widget_new))
                .setIcon(IconCompat.createWithResource(this, R.mipmap.ic_launcher))
                .setIntent(
                    Intent(this, MainActivity::class.java)
                        .setAction(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION)
                        .setData(Uri.parse("ownnotes://new")),
                )
                .build(),
        )
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
