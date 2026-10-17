package com.na7la.iot

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class Na7laWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val totalWatts = widgetData.getString("total_watts", "0 W") ?: "0 W"
            val stripStatus = widgetData.getString("strip_status", "متصل") ?: "متصل"

            val views = RemoteViews(context.packageName, R.layout.widget_hive).apply {
                setTextViewText(R.id.widget_total_watts, totalWatts)
                setTextViewText(R.id.widget_status, stripStatus)

                // Open App on widget click
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    Intent(context, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
