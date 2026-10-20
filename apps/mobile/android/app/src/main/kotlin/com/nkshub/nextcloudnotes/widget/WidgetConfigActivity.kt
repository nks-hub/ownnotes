package com.nkshub.nextcloudnotes.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.view.FlutterCallbackInformation

/**
 * Configuration screen of a widget instance, shown when the widget is placed
 * and from "reconfigure" on Android 12+. It is the Flutter screen
 * `features/widgets/widget_config_main.dart` in its own engine and task, so it
 * neither needs the app's UI to be running nor returns its result into
 * [com.nkshub.nextcloudnotes.MainActivity]. A FragmentActivity is what the
 * device-unlock prompt needs when the app lock is on.
 *
 * The engine starts the Dart function the app registered under
 * [WidgetKeys.CONFIG_HANDLE] (a callback handle, which the VM resolves for any
 * function; looking a function up by name and library only finds `main`).
 * Until the app has run once after an update there is no handle and the
 * activity shows the app itself.
 */
class WidgetConfigActivity : FlutterFragmentActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        val handle = WidgetStore.prefs(context).getString(WidgetKeys.CONFIG_HANDLE, null)?.toLongOrNull()
            ?: return null
        val callback = FlutterCallbackInformation.lookupCallbackInformation(handle) ?: return null
        val loader = FlutterInjector.instance().flutterLoader()
        val engine = FlutterEngine(context)
        engine.dartExecutor.executeDartCallback(
            DartExecutor.DartCallback(context.assets, loader.findAppBundlePath(), callback),
        )
        return engine
    }

    /** The launcher sends no first update to a widget with a configuration screen. */
    override fun finish() {
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (id != AppWidgetManager.INVALID_APPWIDGET_ID) {
            WidgetRenderer.update(this, AppWidgetManager.getInstance(this), id)
        }
        super.finish()
    }
}
