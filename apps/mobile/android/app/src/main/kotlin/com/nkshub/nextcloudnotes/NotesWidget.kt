package com.nkshub.nextcloudnotes

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * Home-screen list of the latest notes. The app writes them as JSON
 * (`[{"id": ..., "title": ...}]`) whenever its note list changes; a tap
 * opens the note, "+" starts a new one.
 */
class NotesWidget : HomeWidgetProvider() {
    private val rows = intArrayOf(R.id.note0, R.id.note1, R.id.note2, R.id.note3, R.id.note4)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val notes = try {
            JSONArray(widgetData.getString("notes", "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.notes_widget)
            views.setOnClickPendingIntent(R.id.widget_title, open(context, null))
            views.setOnClickPendingIntent(R.id.widget_new, open(context, "ownnotes://new"))
            rows.forEachIndexed { index, row ->
                if (index < notes.length()) {
                    val note = notes.getJSONObject(index)
                    views.setTextViewText(row, note.optString("title"))
                    views.setViewVisibility(row, View.VISIBLE)
                    views.setOnClickPendingIntent(
                        row,
                        open(context, "ownnotes://note/" + Uri.encode(note.optString("id"))),
                    )
                } else {
                    views.setViewVisibility(row, View.GONE)
                }
            }
            views.setViewVisibility(
                R.id.widget_empty,
                if (notes.length() == 0) View.VISIBLE else View.GONE,
            )
            // The app lock is on: titles stay hidden, the widget says so.
            views.setTextViewText(
                R.id.widget_empty,
                context.getString(
                    if (widgetData.getBoolean("locked", false)) {
                        R.string.widget_locked
                    } else {
                        R.string.widget_empty
                    },
                ),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun open(context: Context, uri: String?) =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            uri?.let(Uri::parse),
        )
}
