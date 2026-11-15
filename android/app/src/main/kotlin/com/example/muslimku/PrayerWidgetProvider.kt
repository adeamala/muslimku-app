package com.example.muslimku

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * "Jadwal sholat" home-screen widget. Reads what Dart wrote through the
 * `publishWidget` method channel call (widget_city, widget_days: up to seven
 * days of times), picks today's row and the next prayer by the phone clock,
 * and asks for a redraw at the next prayer time (and at midnight) with an
 * inexact alarm, so the highlight moves without the app running.
 */
class PrayerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val widgetData = prefs(context)
        val now = Calendar.getInstance()
        val city = widgetData.getString(CITY_KEY, null)
        val today = todayRow(widgetData.getString(DAYS_KEY, null), now)
        val nextAt = nextPrayerMillis(today, now)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, build(context, city, today, now))
        }
        scheduleRefresh(context, nextAt ?: nextMidnight(now))
    }

    private fun build(
        context: Context,
        city: String?,
        today: Map<String, String>?,
        now: Calendar,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_prayer)
        val launch = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_root, launch)
        views.setTextViewText(R.id.widget_city, city ?: "Muslimku")
        if (today == null) {
            views.setViewVisibility(R.id.widget_times, View.GONE)
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            views.setTextViewText(R.id.widget_date, "Jadwal sholat")
            return views
        }
        views.setViewVisibility(R.id.widget_times, View.VISIBLE)
        views.setViewVisibility(R.id.widget_empty, View.GONE)
        val dateLabel = SimpleDateFormat("EEE, d MMM", Locale("id", "ID")).format(now.time)
        val next = nextPrayerIndex(today, now)
        val nextLabel = if (next == null) "Subuh besok" else "${LABELS[next]} ${today[KEYS[next]]}"
        views.setTextViewText(R.id.widget_date, "$dateLabel · $nextLabel")
        for (i in KEYS.indices) {
            val isNext = next == i
            views.setTextViewText(LABEL_IDS[i], LABELS[i])
            views.setTextViewText(TIME_IDS[i], today[KEYS[i]] ?: "--:--")
            views.setTextColor(LABEL_IDS[i], if (isNext) ACCENT else INK_MUTED)
            views.setTextColor(TIME_IDS[i], if (isNext) ACCENT else INK)
            views.setInt(CELL_IDS[i], "setBackgroundResource", if (isNext) R.drawable.widget_cell_next else 0)
        }
        return views
    }

    private fun scheduleRefresh(context: Context, at: Long) {
        val intent = Intent(context, PrayerWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(
                AppWidgetManager.EXTRA_APPWIDGET_IDS,
                AppWidgetManager.getInstance(context)
                    .getAppWidgetIds(ComponentName(context, PrayerWidgetProvider::class.java)),
            )
        }
        val pending = PendingIntent.getBroadcast(
            context,
            REFRESH_REQUEST,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // Inexact on purpose: no exact-alarm permission needed for a widget.
        alarms.set(AlarmManager.RTC, at + 30_000L, pending)
    }

    companion object {
        const val CITY_KEY = "widget_city"
        const val DAYS_KEY = "widget_days"
        private const val PREFS = "muslimku_widget"
        private const val REFRESH_REQUEST = 7201

        fun prefs(context: Context): SharedPreferences =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        /** Stores [data] and redraws every placed widget. */
        fun publish(context: Context, data: Map<String, String>) {
            val editor = prefs(context).edit()
            for ((k, v) in data) editor.putString(k, v)
            editor.apply()
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, PrayerWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val intent = Intent(context, PrayerWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }

        private val KEYS = listOf("subuh", "dzuhur", "ashar", "maghrib", "isya")
        private val LABELS = listOf("Subuh", "Dzuhur", "Ashar", "Maghrib", "Isya")
        private val LABEL_IDS = listOf(
            R.id.widget_label_0, R.id.widget_label_1, R.id.widget_label_2, R.id.widget_label_3, R.id.widget_label_4,
        )
        private val TIME_IDS = listOf(
            R.id.widget_time_0, R.id.widget_time_1, R.id.widget_time_2, R.id.widget_time_3, R.id.widget_time_4,
        )
        private val CELL_IDS = listOf(
            R.id.widget_cell_0, R.id.widget_cell_1, R.id.widget_cell_2, R.id.widget_cell_3, R.id.widget_cell_4,
        )
        private val INK = Color.parseColor("#16123A")
        private val INK_MUTED = Color.parseColor("#5E5980")
        private val ACCENT = Color.parseColor("#5A45FE")

        /** The row whose `date` is today's yyyy-MM-dd, or null. */
        fun todayRow(json: String?, now: Calendar): Map<String, String>? {
            if (json.isNullOrEmpty()) return null
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now.time)
            return try {
                val days = JSONArray(json)
                (0 until days.length())
                    .map { days.getJSONObject(it) }
                    .firstOrNull { it.optString("date") == today }
                    ?.let { row -> row.keys().asSequence().associateWith { row.optString(it) } }
            } catch (_: Exception) {
                null
            }
        }

        /** Index into KEYS of the first prayer still ahead today, or null after Isya. */
        fun nextPrayerIndex(today: Map<String, String>, now: Calendar): Int? {
            val minutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
            for ((i, key) in KEYS.withIndex()) {
                val t = parseMinutes(today[key]) ?: continue
                if (t > minutes) return i
            }
            return null
        }

        private fun nextPrayerMillis(today: Map<String, String>?, now: Calendar): Long? {
            if (today == null) return null
            val i = nextPrayerIndex(today, now) ?: return null
            val t = parseMinutes(today[KEYS[i]]) ?: return null
            val at = now.clone() as Calendar
            at.set(Calendar.HOUR_OF_DAY, t / 60)
            at.set(Calendar.MINUTE, t % 60)
            at.set(Calendar.SECOND, 0)
            return at.timeInMillis
        }

        private fun nextMidnight(now: Calendar): Long {
            val at = now.clone() as Calendar
            at.add(Calendar.DAY_OF_MONTH, 1)
            at.set(Calendar.HOUR_OF_DAY, 0)
            at.set(Calendar.MINUTE, 0)
            at.set(Calendar.SECOND, 0)
            return at.timeInMillis
        }

        private fun parseMinutes(hhmm: String?): Int? {
            val parts = hhmm?.split(":") ?: return null
            if (parts.size != 2) return null
            val h = parts[0].toIntOrNull() ?: return null
            val m = parts[1].toIntOrNull() ?: return null
            return h * 60 + m
        }
    }
}
