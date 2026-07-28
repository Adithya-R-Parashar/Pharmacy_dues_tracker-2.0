package com.pharmacyduestracker.pharmacy_dues_tracker

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * DEPENDENCY WARNING:
 * This receiver reads the SQLite database `pharmacy_dues_tracker.db` directly.
 * It depends on the following schema structures from database_helper.dart:
 * - Table: `reminders`
 *   - Column: `id` (INTEGER)
 *   - Column: `pharmacy_id` (INTEGER)
 *   - Column: `reminder_type` (TEXT)
 *   - Column: `salesman_name` (TEXT)
 *   - Column: `scheduled_date` (TEXT, format: yyyy-MM-dd)
 *   - Column: `scheduled_time` (TEXT, format: HH:mm)
 *   - Column: `status` (TEXT, e.g. "pending")
 *   - Column: `notification_id` (INTEGER)
 * - Table: `pharmacies`
 *   - Column: `id` (INTEGER)
 *   - Column: `name` (TEXT)
 *   - Column: `salesman` (TEXT)
 * - Table: `invoices`
 *   - Column: `pharmacy_id` (INTEGER)
 *   - Column: `due_amount` (REAL)
 *   - Column: `status` (TEXT, e.g. "open")
 *
 * Any changes to these tables/columns in future schema migrations MUST be kept in sync here.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            Log.d("BootReceiver", "Boot completed. Rescheduling pending reminders...")
            rescheduleReminders(context)
        }
    }

    private fun rescheduleReminders(context: Context) {
        val dbFile = context.getDatabasePath("pharmacy_dues_tracker.db")
        if (!dbFile.exists()) {
            Log.d("BootReceiver", "Database file does not exist. Skipping.")
            return
        }

        var db: SQLiteDatabase? = null
        try {
            db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
            
            val reminderCursor = db.rawQuery(
                "SELECT id, pharmacy_id, reminder_type, salesman_name, scheduled_date, scheduled_time, notification_id FROM reminders WHERE status = 'pending'",
                null
            )

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            while (reminderCursor.moveToNext()) {
                val id = reminderCursor.getInt(0)
                val pharmacyId = if (reminderCursor.isNull(1)) null else reminderCursor.getInt(1)
                val reminderType = reminderCursor.getString(2)
                val salesmanName = reminderCursor.getString(3)
                val scheduledDate = reminderCursor.getString(4)
                val scheduledTime = reminderCursor.getString(5)
                val notificationId = if (reminderCursor.isNull(6)) id else reminderCursor.getInt(6)

                if (scheduledDate.isNullOrEmpty() || scheduledTime.isNullOrEmpty()) continue

                val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US)
                val dateTimeStr = "$scheduledDate $scheduledTime"
                val scheduledDateObj = sdf.parse(dateTimeStr) ?: continue

                if (scheduledDateObj.after(Date())) {
                    var title = ""
                    var body = ""
                    var payload = ""

                    if (reminderType == "pharmacy" && pharmacyId != null) {
                        val pharmacyCursor = db.rawQuery("SELECT name FROM pharmacies WHERE id = ?", arrayOf(pharmacyId.toString()))
                        var pharmacyName = "Pharmacy"
                        if (pharmacyCursor.moveToFirst()) {
                            pharmacyName = pharmacyCursor.getString(0)
                        }
                        pharmacyCursor.close()

                        val invoiceCursor = db.rawQuery("SELECT due_amount FROM invoices WHERE pharmacy_id = ? AND status = 'open'", arrayOf(pharmacyId.toString()))
                        var totalDue = 0.0
                        var openInvoicesCount = 0
                        while (invoiceCursor.moveToNext()) {
                            totalDue += invoiceCursor.getDouble(0)
                            openInvoicesCount++
                        }
                        invoiceCursor.close()

                        title = "Call $pharmacyName"
                        body = "₹${formatCurrency(totalDue)} outstanding — $openInvoicesCount open invoices"
                        payload = "{\"reminder_type\":\"pharmacy\",\"pharmacy_id\":$pharmacyId,\"salesman_name\":null}"
                    } else if (reminderType == "salesman" && !salesmanName.isNullOrEmpty()) {
                        val pharmacyCursor = db.rawQuery("SELECT id FROM pharmacies WHERE salesman = ?", arrayOf(salesmanName))
                        val pIds = mutableListOf<Int>()
                        while (pharmacyCursor.moveToNext()) {
                            pIds.add(pharmacyCursor.getInt(0))
                        }
                        pharmacyCursor.close()

                        var totalDue = 0.0
                        for (pId in pIds) {
                            val invoiceCursor = db.rawQuery("SELECT due_amount FROM invoices WHERE pharmacy_id = ? AND status = 'open'", arrayOf(pId.toString()))
                            while (invoiceCursor.moveToNext()) {
                                totalDue += invoiceCursor.getDouble(0)
                            }
                            invoiceCursor.close()
                        }

                        title = "Call Salesman $salesmanName"
                        body = "${pIds.size} pharmacies — ₹${formatCurrency(totalDue)} total outstanding"
                        payload = "{\"reminder_type\":\"salesman\",\"pharmacy_id\":null,\"salesman_name\":\"$salesmanName\"}"
                    }

                    if (title.isNotEmpty()) {
                        scheduleAlarm(context, alarmManager, notificationId, scheduledDateObj.time, title, body, payload)
                    }
                }
            }
            reminderCursor.close()
        } catch (e: Exception) {
            Log.e("BootReceiver", "Error rescheduling reminders: ${e.message}", e)
        } finally {
            db?.close()
        }
    }

    private fun scheduleAlarm(context: Context, alarmManager: AlarmManager, notificationId: Int, triggerAtMillis: Long, title: String, body: String, payload: String) {
        val intent = Intent(context, NotificationAlarmReceiver::class.java).apply {
            putExtra("notificationId", notificationId)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("payload", payload)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
            Log.d("BootReceiver", "Rescheduled alarm for notification $notificationId at $triggerAtMillis")
        } catch (e: Exception) {
            Log.e("BootReceiver", "Error setting alarm: ${e.message}", e)
        }
    }

    private fun formatCurrency(amount: Double): String {
        return try {
            val format = java.text.NumberFormat.getCurrencyInstance(Locale("en", "IN"))
            var formatted = format.format(amount)
            if (formatted.startsWith("Rs.")) {
                formatted = formatted.substring(3)
            } else if (formatted.startsWith("₹")) {
                formatted = formatted.substring(1)
            }
            formatted.trim()
        } catch (e: Exception) {
            String.format("%.2f", amount)
        }
    }
}
