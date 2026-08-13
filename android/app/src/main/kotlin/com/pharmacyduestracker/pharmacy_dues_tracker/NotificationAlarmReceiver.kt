package com.pharmacyduestracker.pharmacy_dues_tracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

class NotificationAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getIntExtra("notificationId", 0)
        val title = intent.getStringExtra("title") ?: "Call Reminder"
        val body = intent.getStringExtra("body") ?: "Time to make the scheduled call"
        val payload = intent.getStringExtra("payload")

        Log.d("NotificationAlarmReceiver", "Received alarm. Displaying notification $notificationId: $title - $body")

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "call_reminders",
                "Call Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for call reminders"
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = "SELECT_NOTIFICATION"
            putExtra("SELECT_NOTIFICATION_PAYLOAD", payload)
            putExtra("payload", payload)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val smallIconId = context.resources.getIdentifier("ic_launcher", "mipmap", context.packageName)
        val notificationBuilder = NotificationCompat.Builder(context, "call_reminders")
            .setSmallIcon(if (smallIconId != 0) smallIconId else android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true)
            .setAutoCancel(true)

        notificationManager.notify(notificationId, notificationBuilder.build())
    }
}
