package com.nkshub.nextcloudnotes

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import com.nkshub.nextcloudnotes.widget.WidgetMigration
import com.nkshub.nextcloudnotes.widget.WidgetRenderer
import com.nkshub.nextcloudnotes.widget.WidgetStore
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Provider of all four widget types (Notes list, Single note, Checklist, Quick
 * note). The type, account and collection or note belong to each instance and
 * are written by its configuration screen; the app and the background worker
 * write the snapshot each instance shows. The component keeps the name of the
 * single-list widget it replaces, so widgets already on the home screen stay.
 */
class NotesWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        WidgetMigration.run(
            context,
            appWidgetManager.getAppWidgetIds(ComponentName(context, NotesWidget::class.java)),
        )
        for (id in appWidgetIds) WidgetRenderer.update(context, appWidgetManager, id)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        WidgetRenderer.update(context, appWidgetManager, appWidgetId)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        WidgetStore.forget(context, appWidgetIds)
    }
}
