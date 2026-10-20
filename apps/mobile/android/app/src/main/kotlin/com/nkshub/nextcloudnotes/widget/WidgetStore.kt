package com.nkshub.nextcloudnotes.widget

import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/** Keys of the home_widget preferences; the same names are used in `widget_storage.dart`. */
object WidgetKeys {
    const val LOCKED = "locked"
    const val UNTITLED = "widget.untitled"
    const val CONFIG_HANDLE = "widget.confighandle"
    const val LEGACY_ACCOUNT = "account"
    const val LEGACY_NOTES = "notes"
    fun config(id: Int) = "widget.config.$id"
    fun snapshot(id: Int) = "widget.snapshot.$id"
    fun cmdSeq(id: Int) = "widget.cmdseq.$id"
    fun cmdDone(id: Int) = "widget.cmddone.$id"
    fun cmd(id: Int, n: Int) = "widget.cmd.$id.$n"
    fun stale(id: Int) = "widget.stale.$id"
}

/** Per-instance configuration written by the configuration screen. */
class WidgetConfig(
    val type: String,
    val accountId: String?,
    val scope: String,
    val category: String,
    val noteId: String?,
    val appearance: String,
) {
    val configured: Boolean
        get() = !accountId.isNullOrEmpty() && when (type) {
            TYPE_NOTE, TYPE_CHECKLIST -> !noteId.isNullOrEmpty()
            else -> true
        }

    companion object {
        const val TYPE_LIST = "notesList"
        const val TYPE_NOTE = "singleNote"
        const val TYPE_CHECKLIST = "checklist"
        const val TYPE_QUICK = "quickNote"

        fun parse(raw: String?): WidgetConfig? = try {
            val json = JSONObject(raw ?: return null)
            val collection = json.optJSONObject("collection")
            WidgetConfig(
                type = json.optString("type", TYPE_LIST),
                accountId = json.optString("accountId").ifEmpty { null },
                scope = collection?.optString("scope", "all") ?: "all",
                category = collection?.optString("category", "") ?: "",
                noteId = json.optString("noteId").ifEmpty { null },
                appearance = json.optString("appearance", "system"),
            )
        } catch (_: Exception) {
            null
        }
    }
}

class WidgetNote(val id: String, val title: String, val favorite: Boolean)

class WidgetTask(val label: String, val occurrence: Int, val checked: Boolean)

/** What a widget draws; a redacted snapshot carries no content at all. */
class WidgetSnapshot(
    val redacted: Boolean,
    val capturedAt: Long,
    val accountId: String?,
    val accountLabel: String?,
    val noteId: String?,
    val revision: Int?,
    val contentHash: String?,
    val title: String?,
    val excerpt: String?,
    val notes: List<WidgetNote>,
    val tasks: List<WidgetTask>,
) {
    val done: Int get() = tasks.count { it.checked }

    companion object {
        fun parse(raw: String?): WidgetSnapshot? = try {
            val json = JSONObject(raw ?: return null)
            if (json.optString("privacy") != "visible") {
                WidgetSnapshot(true, json.optLong("capturedAt"), null, null, null, null, null, null, null, emptyList(), emptyList())
            } else {
                val notes = json.optJSONArray("notes") ?: JSONArray()
                val tasks = json.optJSONArray("tasks") ?: JSONArray()
                WidgetSnapshot(
                    redacted = false,
                    capturedAt = json.optLong("capturedAt"),
                    accountId = json.optString("accountId").ifEmpty { null },
                    accountLabel = json.optString("accountLabel").ifEmpty { null },
                    noteId = json.optString("noteId").ifEmpty { null },
                    revision = if (json.has("revision")) json.optInt("revision") else null,
                    contentHash = json.optString("contentHash").ifEmpty { null },
                    title = json.optString("title").ifEmpty { null },
                    excerpt = json.optString("excerpt").ifEmpty { null },
                    notes = (0 until notes.length()).map {
                        val n = notes.getJSONObject(it)
                        WidgetNote(n.getString("id"), n.optString("title"), n.optBoolean("favorite"))
                    },
                    tasks = (0 until tasks.length()).map {
                        val t = tasks.getJSONObject(it)
                        val key = t.getJSONObject("key")
                        WidgetTask(key.getString("label"), key.optInt("occurrence"), t.optBoolean("checked"))
                    },
                )
            }
        } catch (_: Exception) {
            null
        }
    }
}

object WidgetStore {
    fun prefs(context: Context): SharedPreferences = HomeWidgetPlugin.getData(context)

    fun locked(context: Context) = prefs(context).getBoolean(WidgetKeys.LOCKED, false)
    fun config(context: Context, id: Int) =
        WidgetConfig.parse(prefs(context).getString(WidgetKeys.config(id), null))

    fun snapshot(context: Context, id: Int) =
        WidgetSnapshot.parse(prefs(context).getString(WidgetKeys.snapshot(id), null))

    /** The revision of a checklist note whose last tick could not be applied, if any. */
    fun staleRevision(context: Context, id: Int): String? =
        prefs(context).getString(WidgetKeys.stale(id), null)

    fun forget(context: Context, ids: IntArray) {
        val edit = prefs(context).edit()
        for (id in ids) {
            val seq = prefs(context).getString(WidgetKeys.cmdSeq(id), null)?.toIntOrNull() ?: 0
            for (n in 1..seq) edit.remove(WidgetKeys.cmd(id, n))
            edit.remove(WidgetKeys.config(id)).remove(WidgetKeys.snapshot(id))
                .remove(WidgetKeys.cmdSeq(id)).remove(WidgetKeys.cmdDone(id))
                .remove(WidgetKeys.stale(id))
        }
        edit.apply()
    }

    /**
     * Queues a tick for Dart and shows it at once. The command and its counter
     * are written together; the row stays where it is until the next
     * settled snapshot replaces this one.
     */
    fun queueTick(context: Context, id: Int, task: WidgetTask, checked: Boolean): Boolean {
        val prefs = prefs(context)
        val snapshot = snapshot(context, id) ?: return false
        val noteId = snapshot.noteId ?: return false
        val accountId = snapshot.accountId ?: return false
        val revision = snapshot.revision ?: return false
        val n = (prefs.getString(WidgetKeys.cmdSeq(id), null)?.toIntOrNull() ?: 0) + 1
        val command = JSONObject()
            .put("schema", 1)
            .put("commandId", UUID.randomUUID().toString())
            .put("instanceId", id.toString())
            .put("accountId", accountId)
            .put("noteId", noteId)
            .put("expectedRevision", revision)
            .put("kind", "setTask")
            .put("task", JSONObject().put("label", task.label).put("occurrence", task.occurrence))
            .put("checked", checked)
        snapshot.contentHash?.let { command.put("contentHash", it) }
        val shown = try {
            val json = JSONObject(prefs.getString(WidgetKeys.snapshot(id), "{}")!!)
            val tasks = json.getJSONArray("tasks")
            for (i in 0 until tasks.length()) {
                val t = tasks.getJSONObject(i)
                val key = t.getJSONObject("key")
                if (key.getString("label") == task.label && key.optInt("occurrence") == task.occurrence) {
                    t.put("checked", checked)
                }
            }
            json.toString()
        } catch (_: Exception) {
            null
        }
        return prefs.edit()
            .putString(WidgetKeys.cmd(id, n), command.toString())
            .putString(WidgetKeys.cmdSeq(id), n.toString())
            .apply { if (shown != null) putString(WidgetKeys.snapshot(id), shown) }
            .commit()
    }
}

/**
 * Widgets placed before per-instance configuration showed the notes of the
 * account the app had last published. Those widgets become a Notes list of
 * that account; without a recorded account they ask to be configured.
 */
object WidgetMigration {
    fun run(context: Context, ids: IntArray) {
        val prefs = WidgetStore.prefs(context)
        val account = prefs.getString(WidgetKeys.LEGACY_ACCOUNT, null)
        if (account == null) return
        val notes = try {
            JSONArray(prefs.getString(WidgetKeys.LEGACY_NOTES, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        val locked = WidgetStore.locked(context)
        val edit = prefs.edit()
        if (account.isNotEmpty()) {
            for (id in ids) {
                if (prefs.contains(WidgetKeys.config(id))) continue
                val config = JSONObject()
                    .put("schema", 1)
                    .put("instanceId", id.toString())
                    .put("type", WidgetConfig.TYPE_LIST)
                    .put("accountId", account)
                    .put("collection", JSONObject().put("scope", "all"))
                    .put("appearance", "system")
                val snapshot = JSONObject()
                    .put("schema", 1)
                    .put("instanceId", id.toString())
                    .put("type", WidgetConfig.TYPE_LIST)
                    .put("capturedAt", System.currentTimeMillis())
                    .put("privacy", if (locked) "redacted" else "visible")
                if (!locked) snapshot.put("accountId", account).put("notes", notes)
                edit.putString(WidgetKeys.config(id), config.toString())
                    .putString(WidgetKeys.snapshot(id), snapshot.toString())
            }
        }
        edit.remove(WidgetKeys.LEGACY_ACCOUNT).remove(WidgetKeys.LEGACY_NOTES).commit()
    }
}
