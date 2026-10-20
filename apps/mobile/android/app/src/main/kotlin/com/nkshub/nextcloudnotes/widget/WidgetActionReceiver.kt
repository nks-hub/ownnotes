package com.nkshub.nextcloudnotes.widget

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetBackgroundWorker
import io.flutter.FlutterInjector

/**
 * A tick tapped in a Checklist widget. The command is queued in the same
 * preferences Dart reads (one counter per instance, written here only), the
 * tick shows at once, and Dart applies it through the draft path the editor
 * saves with. While the app lock is on nothing is queued.
 */
class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != WidgetRenderer.ACTION_TICK) return
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        val label = intent.getStringExtra(WidgetRenderer.EXTRA_LABEL)
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID || label == null) return
        val manager = AppWidgetManager.getInstance(context)
        if (!WidgetStore.locked(context)) {
            val checked = intent.getBooleanExtra(WidgetRenderer.EXTRA_CHECKED, true)
            val occurrence = intent.getIntExtra(WidgetRenderer.EXTRA_OCCURRENCE, 0)
            if (WidgetStore.queueTick(context, id, WidgetTask(label, occurrence, !checked), checked)) {
                runDart(context)
            }
        }
        WidgetRenderer.update(context, manager, id)
    }

    /** Starts the background Dart callback registered by the app (`notes_widget.dart`). */
    private fun runDart(context: Context) {
        val app = context.applicationContext
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(app)
        loader.ensureInitializationComplete(app, null)
        HomeWidgetBackgroundWorker.enqueueWork(app, Intent().setData(Uri.parse("ownnotes://widget/commands")))
    }
}
