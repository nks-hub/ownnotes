package com.nkshub.nextcloudnotes

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives text shared from other apps (Google Keep, Samsung Notes, ...) and
 * blocks screenshots on request and answers the camera permission of the
 * QR login scanner, which the camera plugin cannot report back to Dart. A FragmentActivity is what the device-unlock
 * prompt of local_auth needs.
 */
class MainActivity : FlutterFragmentActivity() {
    private var shared: Map<String, String>? = null
    private var channel: MethodChannel? = null
    private var pendingCamera: MethodChannel.Result? = null

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
            "com.nkshub.nextcloudnotes/camera_permission",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(cameraStatus())
                "request" -> requestCamera(result)
                "openSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            .setData(Uri.parse("package:$packageName")),
                    )
                    result.success(true)
                }
                else -> result.notImplemented()
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

    private fun cameraStatus(): Map<String, String> {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return mapOf("status" to "granted")
        }
        val asked = getSharedPreferences("permissions", MODE_PRIVATE)
            .getBoolean("camera_asked", false)
        return mapOf("status" to if (asked) "denied" else "notDetermined")
    }

    private fun requestCamera(result: MethodChannel.Result) {
        if (cameraStatus()["status"] == "granted") {
            result.success(cameraStatus())
            return
        }
        if (pendingCamera != null) {
            result.error("in_progress", "A camera request is already active.", null)
            return
        }
        pendingCamera = result
        getSharedPreferences("permissions", MODE_PRIVATE).edit()
            .putBoolean("camera_asked", true).apply()
        ActivityCompat.requestPermissions(
            this, arrayOf(Manifest.permission.CAMERA), CAMERA_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CAMERA_REQUEST) return
        // An interrupted request is not a refusal; allow the prompt again.
        if (grantResults.isEmpty()) {
            getSharedPreferences("permissions", MODE_PRIVATE).edit()
                .putBoolean("camera_asked", false).apply()
        }
        pendingCamera?.success(cameraStatus())
        pendingCamera = null
    }

    override fun onDestroy() {
        pendingCamera?.error("cancelled", "The camera request was cancelled.", null)
        pendingCamera = null
        super.onDestroy()
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

    private companion object {
        const val CAMERA_REQUEST = 4108
    }
}
