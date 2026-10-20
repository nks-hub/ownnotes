package com.nkshub.nextcloudnotes.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StrikethroughSpan
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.nkshub.nextcloudnotes.R

/** Rows of the Notes list and Checklist widgets, read from the instance's snapshot. */
class WidgetListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        Factory(applicationContext, intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, 0))

    private class Factory(private val appContext: Context, private val id: Int) : RemoteViewsFactory {
        private var context = appContext
        private var config: WidgetConfig? = null
        private var snapshot: WidgetSnapshot? = null
        private var palette: WidgetPalette? = null

        private val checklist get() = config?.type == WidgetConfig.TYPE_CHECKLIST

        override fun onCreate() = Unit

        override fun onDataSetChanged() {
            context = WidgetStore.localized(appContext)
            val c = WidgetStore.config(context, id)
            config = c
            palette = WidgetPalette.of(context, c?.appearance ?: "system")
            // A locked or redacted widget has no rows.
            snapshot = if (WidgetStore.locked(context)) null else WidgetStore.snapshot(context, id)?.takeIf { !it.redacted }
        }

        override fun onDestroy() {
            snapshot = null
        }

        override fun getCount(): Int {
            val s = snapshot ?: return 0
            return if (checklist) s.tasks.size else s.notes.size
        }

        override fun getViewAt(position: Int): RemoteViews? {
            val s = snapshot ?: return null
            val p = palette ?: return null
            val account = config?.accountId ?: return null
            return if (checklist) {
                s.tasks.getOrNull(position)?.let { task(p, it) }
            } else {
                s.notes.getOrNull(position)?.let { note(p, account, it) }
            }
        }

        private fun note(p: WidgetPalette, account: String, n: WidgetNote): RemoteViews {
            val rv = RemoteViews(context.packageName, R.layout.widget_row_note)
            rv.setTextViewText(R.id.row_title, n.title)
            rv.setTextColor(R.id.row_title, p.onSurface)
            rv.setViewVisibility(R.id.row_star, if (n.favorite) View.VISIBLE else View.GONE)
            rv.setInt(R.id.row_star, "setColorFilter", p.accent)
            rv.setOnClickFillInIntent(
                R.id.row,
                Intent().setData(Uri.parse("ownnotes://note/${Uri.encode(account)}/${Uri.encode(n.id)}")),
            )
            return rv
        }

        private fun task(p: WidgetPalette, t: WidgetTask): RemoteViews {
            val rv = RemoteViews(context.packageName, R.layout.widget_row_task)
            rv.setImageViewResource(
                R.id.task_box,
                if (t.checked) R.drawable.widget_check_on else R.drawable.widget_check_off,
            )
            rv.setInt(R.id.task_box, "setColorFilter", if (t.checked) p.accent else p.outline)
            val label = SpannableString(t.label)
            if (t.checked) label.setSpan(StrikethroughSpan(), 0, label.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            rv.setTextViewText(R.id.task_label, label)
            rv.setTextColor(R.id.task_label, if (t.checked) p.secondary else p.onSurface)
            rv.setContentDescription(
                R.id.row,
                context.getString(if (t.checked) R.string.wd_task_done else R.string.wd_task_open, t.label),
            )
            // The requested result, not a toggle: a repeated delivery cannot flip it back.
            rv.setOnClickFillInIntent(
                R.id.row,
                Intent()
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                    .putExtra(WidgetRenderer.EXTRA_LABEL, t.label)
                    .putExtra(WidgetRenderer.EXTRA_OCCURRENCE, t.occurrence)
                    .putExtra(WidgetRenderer.EXTRA_CHECKED, !t.checked),
            )
            return rv
        }

        override fun getLoadingView(): RemoteViews? = null
        override fun getViewTypeCount() = 1
        override fun getItemId(position: Int) = position.toLong()
        override fun hasStableIds() = false
    }
}
