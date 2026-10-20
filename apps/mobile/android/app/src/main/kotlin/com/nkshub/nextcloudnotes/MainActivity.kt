package com.nkshub.nextcloudnotes

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Parcelable
import android.provider.OpenableColumns
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
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

/**
 * Receives text, pictures and files shared from other apps (Google Keep,
 * Samsung Notes, ...) and keeps each share on disk until Flutter has stored
 * it and acknowledges it. Also blocks screenshots on request and answers the
 * camera permission of the QR login scanner, which the camera plugin cannot
 * report back to Dart. A FragmentActivity is what the device-unlock prompt of
 * local_auth needs.
 */
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var pendingCamera: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // A recreated activity still carries the old intent; it was taken already.
        if (savedInstanceState == null) persistShare(intent)
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
                when (call.method) {
                    "listCaptures" -> result.success(listCaptures())
                    "ackCapture" -> {
                        val id = call.arguments as? String
                        if (id != null && SAFE_ID.matches(id)) {
                            File(captureRoot(), id).deleteRecursively()
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
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
        persistShare(intent)
    }

    private fun captureRoot() = File(filesDir, "captures")

    /**
     * Copies a share into `captures/<id>/` (text in capture.json, files in
     * `files/`). The folder is renamed into place last, so a listing sees a
     * share whole or not at all. Runs off the main thread: files can be big.
     * The share stays there until Flutter acknowledges it with `ackCapture`.
     */
    private fun persistShare(intent: Intent?) {
        if (intent == null || intent.getBooleanExtra(HANDLED, false)) return
        val action = intent.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return
        intent.putExtra(HANDLED, true)
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() ?: ""
        val title = intent.getStringExtra(Intent.EXTRA_SUBJECT) ?: ""
        val uris = streamUris(intent)
        val mime = intent.type
        if (text.isEmpty() && uris.isEmpty()) return
        Thread {
            try {
                val id = UUID.randomUUID().toString()
                val work = File(captureRoot(), "$id.tmp")
                File(work, "files").mkdirs()
                val kept = ArrayList<Triple<String, String, String>>()
                uris.forEachIndexed { i, uri ->
                    val type = contentResolver.getType(uri) ?: mime ?: "application/octet-stream"
                    val name = displayName(uri) ?: "file-$i"
                    val target = File(work, "files/$i")
                    val copied = try {
                        contentResolver.openInputStream(uri)?.use { input ->
                            target.outputStream().use { out -> input.copyTo(out) }
                        } != null
                    } catch (e: Exception) {
                        false
                    }
                    if (copied && target.length() <= MAX_FILE) {
                        kept.add(Triple(name, type, "files/$i"))
                    } else {
                        target.delete()
                    }
                }
                if (text.isEmpty() && kept.isEmpty()) {
                    work.deleteRecursively()
                    return@Thread
                }
                val dest = File(captureRoot(), id)
                val files = JSONArray()
                for ((name, type, relative) in kept) {
                    files.put(
                        JSONObject().put("name", name).put("mime", type)
                            .put("path", File(dest, relative).absolutePath),
                    )
                }
                File(work, "capture.json").writeText(
                    JSONObject().put("id", id).put("title", title).put("text", text)
                        .put("createdAt", System.currentTimeMillis())
                        .put("files", files).toString(),
                )
                if (work.renameTo(dest)) {
                    runOnUiThread { channel?.invokeMethod("shared", null) }
                } else {
                    work.deleteRecursively()
                }
            } catch (e: Exception) {
                // The share sheet of the sender is already closed; a half
                // copy is worse than none, and the .tmp folder is ignored.
            }
        }.start()
    }

    @Suppress("DEPRECATION")
    private fun streamUris(intent: Intent): List<Uri> {
        val out = ArrayList<Uri>()
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)?.let { out.add(it) }
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                ?.let { out.addAll(it) }
        } else {
            val single = intent.getParcelableExtra<Parcelable>(Intent.EXTRA_STREAM)
            if (single is Uri) out.add(single)
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let { out.addAll(it) }
        }
        return out.distinct()
    }

    private fun displayName(uri: Uri): String? = try {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
    } catch (e: Exception) {
        null
    } ?: uri.lastPathSegment

    private fun listCaptures(): List<Map<String, Any>> {
        val dirs = captureRoot().listFiles { f -> f.isDirectory && SAFE_ID.matches(f.name) }
            ?: return emptyList()
        return dirs.mapNotNull { dir ->
            try {
                val json = JSONObject(File(dir, "capture.json").readText())
                val files = json.getJSONArray("files")
                mapOf<String, Any>(
                    "id" to json.getString("id"),
                    "title" to json.getString("title"),
                    "text" to json.getString("text"),
                    "createdAt" to json.getLong("createdAt"),
                    "files" to (0 until files.length()).map {
                        val f = files.getJSONObject(it)
                        mapOf(
                            "name" to f.getString("name"),
                            "mime" to f.getString("mime"),
                            "path" to f.getString("path"),
                        )
                    },
                )
            } catch (e: Exception) {
                null
            }
        }.sortedBy { it["createdAt"] as Long }
    }

    private companion object {
        const val CAMERA_REQUEST = 4108
        const val HANDLED = "com.nkshub.nextcloudnotes.HANDLED"
        const val MAX_FILE = 64L * 1024 * 1024
        val SAFE_ID = Regex("[A-Za-z0-9_-]{1,80}")
    }
}
