package com.nkshub.nextcloudnotes.widget

import android.content.Context
import android.content.res.Configuration
import com.nkshub.nextcloudnotes.R

/**
 * Colour roles of a widget, always read as complete pairs (surface with its
 * text, accent with its on-accent, container with its on-container). Android 12+
 * takes them from the wallpaper palette (`values-v31`), older versions from the
 * OwnNotes palette (`values`). The widget's own light/dark choice overrides the
 * system setting by resolving the resources under a forced night mode.
 */
class WidgetPalette(
    val surface: Int,
    val raised: Int,
    val onSurface: Int,
    val secondary: Int,
    val accent: Int,
    val onAccent: Int,
    val container: Int,
    val onContainer: Int,
    val outline: Int,
) {
    companion object {
        fun of(context: Context, appearance: String): WidgetPalette {
            val system = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
            val night = when (appearance) {
                "light" -> false
                "dark" -> true
                else -> system == Configuration.UI_MODE_NIGHT_YES
            }
            val forced = Configuration(context.resources.configuration)
            forced.uiMode = (forced.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                if (night) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
            val c = context.createConfigurationContext(forced)
            return WidgetPalette(
                surface = c.getColor(R.color.widget_surface),
                raised = c.getColor(R.color.widget_raised),
                onSurface = c.getColor(R.color.widget_on_surface),
                secondary = c.getColor(R.color.widget_secondary),
                accent = c.getColor(R.color.widget_accent),
                onAccent = c.getColor(R.color.widget_on_accent),
                container = c.getColor(R.color.widget_container),
                onContainer = c.getColor(R.color.widget_on_container),
                outline = c.getColor(R.color.widget_outline),
            )
        }
    }
}
