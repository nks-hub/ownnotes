package com.nkshub.nextcloudnotes.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.text.format.DateUtils
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import com.nkshub.nextcloudnotes.MainActivity
import com.nkshub.nextcloudnotes.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Builds the RemoteViews of every widget type (redesign spec 9.3). One layout
 * per type; the size class only decides which parts show. Android 12+ gets one
 * RemoteViews per size the launcher reports, older versions pick the class from
 * the widget options. Rendering reads local preferences only.
 */
object WidgetRenderer {
    enum class Size { SMALL, MEDIUM, LARGE }

    const val EXTRA_LABEL = "label"
    const val EXTRA_OCCURRENCE = "occurrence"
    const val EXTRA_CHECKED = "checked"
    const val ACTION_TICK = "com.nkshub.nextcloudnotes.widget.TICK"

    private class State(
        val context: Context,
        val id: Int,
        val config: WidgetConfig?,
        val snapshot: WidgetSnapshot?,
        val locked: Boolean,
        val palette: WidgetPalette,
    )

    /** From this font scale on the headers wrap and the small layouts drop their detail line. */
    private fun State.largeText() = context.resources.configuration.fontScale >= 1.3f

    fun update(context: Context, manager: AppWidgetManager, id: Int) {
        manager.updateAppWidget(id, build(context, manager, id))
        manager.notifyAppWidgetViewDataChanged(id, R.id.list)
    }

    fun sizeClass(widthDp: Float, heightDp: Float) = when {
        widthDp >= 220 && heightDp >= 220 -> Size.LARGE
        widthDp >= 220 || heightDp >= 220 -> Size.MEDIUM
        else -> Size.SMALL
    }

    @Suppress("DEPRECATION")
    private fun build(context: Context, manager: AppWidgetManager, id: Int): RemoteViews {
        val config = WidgetStore.config(context, id)
        val state = State(
            context, id, config,
            WidgetStore.snapshot(context, id),
            WidgetStore.locked(context),
            WidgetPalette.of(context, config?.appearance ?: "system"),
        )
        val options = manager.getAppWidgetOptions(id)
        if (Build.VERSION.SDK_INT >= 31) {
            val sizes = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            if (!sizes.isNullOrEmpty()) {
                val byClass = HashMap<Size, RemoteViews>()
                val map = HashMap<SizeF, RemoteViews>()
                for (size in sizes) {
                    val cls = sizeClass(size.width, size.height)
                    map[size] = byClass.getOrPut(cls) { views(state, cls) }
                }
                return RemoteViews(map)
            }
        }
        val portrait = context.resources.configuration.orientation != Configuration.ORIENTATION_LANDSCAPE
        val width = options.getInt(
            if (portrait) AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH else AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH,
        )
        val height = options.getInt(
            if (portrait) AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT else AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT,
        )
        return views(state, sizeClass(width.toFloat(), height.toFloat()))
    }

    private fun views(s: State, size: Size): RemoteViews {
        val config = s.config
        val snapshot = s.snapshot
        return when {
            s.locked -> message(s, R.string.wd_hidden, R.string.wd_unlock, open(s.context, "ownnotes://open"))
            config == null || !config.configured -> message(
                s, R.string.wd_configure_hint, R.string.wd_configure, configure(s.context, s.id),
            )
            snapshot == null || snapshot.redacted -> message(s, R.string.wd_updating, null, open(s.context, "ownnotes://open"))
            else -> when (config.type) {
                WidgetConfig.TYPE_NOTE -> note(s, config, snapshot, size)
                WidgetConfig.TYPE_CHECKLIST -> collection(s, config, snapshot, size, true)
                WidgetConfig.TYPE_QUICK -> quick(s, config, snapshot, size)
                else -> collection(s, config, snapshot, size, false)
            }
        }
    }

    // ---- shared pieces ----

    private fun RemoteViews.tint(id: Int, color: Int) = setInt(id, "setColorFilter", color)

    private fun RemoteViews.ink(id: Int, text: CharSequence?, color: Int) {
        if (text == null) {
            setViewVisibility(id, View.GONE)
        } else {
            setViewVisibility(id, View.VISIBLE)
            setTextViewText(id, text)
            setTextColor(id, color)
        }
    }

    private fun base(s: State, layout: Int): RemoteViews {
        val rv = RemoteViews(s.context.packageName, layout)
        rv.tint(R.id.bg, s.palette.surface)
        return rv
    }

    private fun open(context: Context, uri: String): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))

    private fun enc(value: String) = Uri.encode(value)

    private fun noteUri(account: String, note: String) = "ownnotes://note/${enc(account)}/${enc(note)}"

    private fun newUri(account: String, kind: String) = "ownnotes://new/${enc(account)}?kind=$kind"

    /** Opens the configuration screen of this instance; unique per instance. */
    private fun configure(context: Context, id: Int): PendingIntent = PendingIntent.getActivity(
        context,
        id,
        Intent(context, WidgetConfigActivity::class.java)
            .setAction(AppWidgetManager.ACTION_APPWIDGET_CONFIGURE)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun mutableFlag() = if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0

    private fun snapshotTime(context: Context, millis: Long): String {
        val today = DateUtils.isToday(millis)
        val flags = DateUtils.FORMAT_SHOW_TIME or
            if (today) 0 else DateUtils.FORMAT_SHOW_DATE or DateUtils.FORMAT_ABBREV_MONTH
        return context.getString(R.string.wd_updated, DateUtils.formatDateTime(context, millis, flags))
    }

    private fun message(s: State, text: Int, action: Int?, click: PendingIntent): RemoteViews {
        val rv = base(s, R.layout.widget_message)
        val p = s.palette
        rv.setTextColor(R.id.title, p.onSurface)
        rv.ink(R.id.message, s.context.getString(text), p.secondary)
        if (action == null) {
            rv.setViewVisibility(R.id.action, View.GONE)
        } else {
            rv.setViewVisibility(R.id.action, View.VISIBLE)
            rv.tint(R.id.action_bg, p.container)
            rv.ink(R.id.action_label, s.context.getString(action), p.onContainer)
        }
        rv.setOnClickPendingIntent(R.id.root, click)
        return rv
    }

    private fun header(
        rv: RemoteViews,
        s: State,
        title: CharSequence,
        subtitle: CharSequence?,
        subtitleColor: Int,
        headerClick: PendingIntent,
        addClick: PendingIntent?,
    ) {
        val p = s.palette
        rv.ink(R.id.title, title, p.onSurface)
        rv.setInt(R.id.title, "setMaxLines", if (s.largeText()) 2 else 1)
        rv.ink(R.id.subtitle, subtitle, subtitleColor)
        rv.setOnClickPendingIntent(R.id.header_text, headerClick)
        if (addClick == null) {
            rv.setViewVisibility(R.id.add, View.GONE)
        } else {
            rv.setViewVisibility(R.id.add, View.VISIBLE)
            rv.tint(R.id.add_bg, p.container)
            rv.tint(R.id.add_icon, p.onContainer)
            rv.setOnClickPendingIntent(R.id.add, addClick)
        }
    }

    private fun collectionTitle(context: Context, config: WidgetConfig) = when (config.scope) {
        "favorites" -> context.getString(R.string.wd_favorites)
        "uncategorised" -> context.getString(R.string.wd_uncategorised)
        "category" -> config.category.ifEmpty { context.getString(R.string.wd_all_notes) }
        else -> context.getString(R.string.wd_all_notes)
    }

    // ---- types ----

    private fun collection(
        s: State,
        config: WidgetConfig,
        snapshot: WidgetSnapshot,
        size: Size,
        checklist: Boolean,
    ): RemoteViews {
        val account = config.accountId!!
        if (checklist && snapshot.noteId == null) {
            return message(s, R.string.wd_note_missing, R.string.wd_configure, configure(s.context, s.id))
        }
        val rv = base(s, R.layout.widget_list)
        val p = s.palette
        val context = s.context
        val stale = checklist && WidgetStore.staleRevision(context, s.id) == snapshot.revision.toString()
        val title = if (checklist) snapshot.title ?: "" else collectionTitle(context, config)
        val subtitle: CharSequence?
        val subtitleColor: Int
        if (size == Size.SMALL && s.largeText()) {
            subtitle = null
            subtitleColor = p.secondary
        } else if (stale) {
            subtitle = context.getString(R.string.wd_stale)
            subtitleColor = p.accent
        } else if (checklist) {
            subtitle = context.getString(R.string.wd_progress, snapshot.done, snapshot.tasks.size)
            subtitleColor = p.secondary
        } else {
            subtitle = if (size == Size.SMALL) null else snapshot.accountLabel
            subtitleColor = p.secondary
        }
        header(
            rv, s, title, subtitle, subtitleColor,
            headerClick = open(
                context,
                if (checklist) noteUri(account, snapshot.noteId!!) else "ownnotes://open",
            ),
            addClick = open(context, newUri(account, if (checklist) "checklist" else "note")),
        )
        rv.setRemoteAdapter(
            R.id.list,
            Intent(context, WidgetListService::class.java)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, s.id)
                .also { it.data = Uri.parse(it.toUri(Intent.URI_INTENT_SCHEME)) },
        )
        rv.setEmptyView(R.id.list, R.id.empty)
        // The list shows this view itself, and only while it has no rows.
        rv.setTextViewText(
            R.id.empty,
            context.getString(if (checklist) R.string.wd_empty_tasks else R.string.wd_empty_notes),
        )
        rv.setTextColor(R.id.empty, p.secondary)
        rv.setPendingIntentTemplate(
            R.id.list,
            if (checklist) {
                PendingIntent.getBroadcast(
                    context,
                    s.id * 10 + 2,
                    Intent(context, WidgetActionReceiver::class.java).setAction(ACTION_TICK),
                    PendingIntent.FLAG_UPDATE_CURRENT or mutableFlag(),
                )
            } else {
                PendingIntent.getActivity(
                    context,
                    s.id * 10 + 1,
                    Intent(context, MainActivity::class.java)
                        .setAction(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION),
                    PendingIntent.FLAG_UPDATE_CURRENT or mutableFlag(),
                )
            },
        )
        rv.ink(
            R.id.footer,
            if (size == Size.SMALL) null else snapshotTime(context, snapshot.capturedAt),
            p.secondary,
        )
        return rv
    }

    private fun note(s: State, config: WidgetConfig, snapshot: WidgetSnapshot, size: Size): RemoteViews {
        val account = config.accountId!!
        val noteId = snapshot.noteId
            ?: return message(s, R.string.wd_note_missing, R.string.wd_configure, configure(s.context, s.id))
        val rv = base(s, R.layout.widget_note)
        val p = s.palette
        val context = s.context
        val click = open(context, noteUri(account, noteId))
        header(
            rv, s, snapshot.title ?: "",
            if (size == Size.SMALL || s.largeText()) null else snapshot.accountLabel, p.secondary,
            headerClick = click, addClick = null,
        )
        rv.ink(R.id.excerpt, snapshot.excerpt ?: context.getString(R.string.wd_no_excerpt), p.onSurface)
        rv.setInt(R.id.excerpt, "setMaxLines", when (size) {
            Size.SMALL -> 2
            Size.MEDIUM -> 4
            Size.LARGE -> 14
        })
        rv.ink(R.id.footer, if (size == Size.SMALL) null else snapshotTime(context, snapshot.capturedAt), p.secondary)
        rv.setOnClickPendingIntent(R.id.root, click)
        return rv
    }

    private fun quick(s: State, config: WidgetConfig, snapshot: WidgetSnapshot, size: Size): RemoteViews {
        val account = config.accountId!!
        val rv = base(s, R.layout.widget_quick)
        val p = s.palette
        val context = s.context
        rv.ink(
            R.id.title,
            if (size == Size.LARGE) snapshot.accountLabel ?: context.getString(R.string.widget_title) else null,
            p.onSurface,
        )
        fun button(id: Int, label: Int, kind: String, primary: Boolean, visible: Boolean) {
            val root = id
            rv.setViewVisibility(root, if (visible) View.VISIBLE else View.GONE)
            if (!visible) return
            val bg = when (id) {
                R.id.btn_new -> R.id.btn_new_bg
                R.id.btn_checklist -> R.id.btn_checklist_bg
                R.id.btn_daily -> R.id.btn_daily_bg
                else -> R.id.btn_template_bg
            }
            val text = when (id) {
                R.id.btn_new -> R.id.btn_new_label
                R.id.btn_checklist -> R.id.btn_checklist_label
                R.id.btn_daily -> R.id.btn_daily_label
                else -> R.id.btn_template_label
            }
            rv.tint(bg, if (primary) p.container else p.raised)
            rv.ink(text, context.getString(label), if (primary) p.onContainer else p.onSurface)
            rv.setOnClickPendingIntent(root, open(context, newUri(account, kind)))
        }
        button(R.id.btn_new, R.string.wd_new_note, "note", true, true)
        button(R.id.btn_checklist, R.string.wd_new_checklist, "checklist", false, size != Size.SMALL)
        button(R.id.btn_daily, R.string.wd_daily, "daily", false, size == Size.LARGE)
        button(R.id.btn_template, R.string.wd_template, "template", false, size == Size.LARGE)
        return rv
    }
}
