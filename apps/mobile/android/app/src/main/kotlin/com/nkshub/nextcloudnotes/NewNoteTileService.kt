package com.nkshub.nextcloudnotes

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Quick settings tile "New note": opens the app on a new note with the same
 * `ownnotes://new` link the widget's "+" uses.
 */
@RequiresApi(Build.VERSION_CODES.N)
class NewNoteTileService : TileService() {
    override fun onStartListening() {
        qsTile?.apply {
            state = Tile.STATE_INACTIVE
            updateTile()
        }
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    @Suppress("DEPRECATION")
    override fun onClick() {
        val intent = Intent(this, MainActivity::class.java)
            .setAction(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION)
            .setData(Uri.parse("ownnotes://new"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        unlockAndRun {
            if (Build.VERSION.SDK_INT >= 34) {
                startActivityAndCollapse(
                    PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE),
                )
            } else {
                startActivityAndCollapse(intent)
            }
        }
    }
}
