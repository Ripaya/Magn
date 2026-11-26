package magn.ion

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Android 14–16 compliant `specialUse` Foreground Service displaying a live
 * chronometer notification with inline Pause/Resume and Skip actions, paired
 * with Doze-safe AlarmManager exact completion alarms.
 */
class FocusTimerService : Service() {

    companion object {
        const val CHANNEL_ID = "magn_active_timer"
        const val NOTIFICATION_ID = 4001
        const val ALARM_REQUEST_CODE = 4002

        const val ACTION_START = "magn.ion.ACTION_START"
        const val ACTION_PAUSE = "magn.ion.ACTION_PAUSE"
        const val ACTION_STOP = "magn.ion.ACTION_STOP"
        const val ACTION_NOTIF_PAUSE = "magn.ion.ACTION_NOTIF_PAUSE"
        const val ACTION_NOTIF_RESUME = "magn.ion.ACTION_NOTIF_RESUME"
        const val ACTION_NOTIF_SKIP = "magn.ion.ACTION_NOTIF_SKIP"

        const val EXTRA_TITLE = "title"
        const val EXTRA_SUBTITLE = "subtitle"
        const val EXTRA_START_UTC_MS = "startUtcMs"
        const val EXTRA_TARGET_END_UTC_MS = "targetEndUtcMs"
        const val EXTRA_IS_COUNT_UP = "isCountUp"
        const val EXTRA_FORMATTED_TIME = "formattedTime"
        const val EXTRA_NOTIFICATION_STYLE = "notificationStyle"
        const val EXTRA_COMPLETION_SOUND = "completionSound"
        const val EXTRA_VIBRATION_PATTERN = "vibrationPattern"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "Magn Focus"
                val subtitle = intent.getStringExtra(EXTRA_SUBTITLE) ?: "Session active"
                val startUtcMs = intent.getLongExtra(EXTRA_START_UTC_MS, System.currentTimeMillis())
                val targetEndUtcMs = intent.getLongExtra(EXTRA_TARGET_END_UTC_MS, -1L)
                val isCountUp = intent.getBooleanExtra(EXTRA_IS_COUNT_UP, false)
                val style = intent.getStringExtra(EXTRA_NOTIFICATION_STYLE) ?: "standard"
                val sound = intent.getStringExtra(EXTRA_COMPLETION_SOUND) ?: "soft_chime"
                val vibration = intent.getStringExtra(EXTRA_VIBRATION_PATTERN) ?: "gentle"

                val notification = buildRunningNotification(
                    title = title,
                    subtitle = subtitle,
                    startUtcMs = startUtcMs,
                    targetEndUtcMs = targetEndUtcMs,
                    isCountUp = isCountUp,
                    style = style
                )

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }

                if (!isCountUp && targetEndUtcMs > System.currentTimeMillis()) {
                    scheduleExactPhaseEndAlarm(targetEndUtcMs, title, sound, vibration)
                } else {
                    cancelPhaseEndAlarm()
                }
            }

            ACTION_PAUSE -> {
                cancelPhaseEndAlarm()
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "Magn (Paused)"
                val formatted = intent.getStringExtra(EXTRA_FORMATTED_TIME) ?: ""
                val notification = buildPausedNotification(title, formatted)
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.notify(NOTIFICATION_ID, notification)
            }

            ACTION_STOP -> {
                cancelPhaseEndAlarm()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }

            ACTION_NOTIF_PAUSE -> MainActivity.dispatchNativeAction("pause")
            ACTION_NOTIF_RESUME -> MainActivity.dispatchNativeAction("resume")
            ACTION_NOTIF_SKIP -> MainActivity.dispatchNativeAction("skip")
        }

        return START_NOT_STICKY
    }

    private fun buildRunningNotification(
        title: String,
        subtitle: String,
        startUtcMs: Long,
        targetEndUtcMs: Long,
        isCountUp: Boolean,
        style: String
    ): Notification {
        val openAppIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setContentIntent(openAppIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        if (style != "compact") {
            builder.setUsesChronometer(true)
            if (!isCountUp && targetEndUtcMs > 0L) {
                builder.setWhen(targetEndUtcMs)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    builder.setChronometerCountDown(true)
                }
            } else {
                builder.setWhen(startUtcMs)
            }
        }

        if (style == "standard") {
            val pausePi = serviceActionPendingIntent(ACTION_NOTIF_PAUSE, 101)
            val skipPi = serviceActionPendingIntent(ACTION_NOTIF_SKIP, 102)
            builder.addAction(android.R.drawable.ic_media_pause, "Pause", pausePi)
            builder.addAction(android.R.drawable.ic_media_next, "Skip", skipPi)
        }

        return builder.build()
    }

    private fun buildPausedNotification(title: String, formattedTime: String): Notification {
        val openAppIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val resumePi = serviceActionPendingIntent(ACTION_NOTIF_RESUME, 103)
        val skipPi = serviceActionPendingIntent(ACTION_NOTIF_SKIP, 104)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_pause)
            .setContentTitle(title)
            .setContentText("Paused at $formattedTime")
            .setContentIntent(openAppIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(android.R.drawable.ic_media_play, "Resume", resumePi)
            .addAction(android.R.drawable.ic_media_next, "End", skipPi)
            .build()
    }

    private fun serviceActionPendingIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, FocusTimerService::class.java).apply {
            this.action = action
        }
        return PendingIntent.getService(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun scheduleExactPhaseEndAlarm(
        triggerAtUtcMs: Long,
        title: String,
        sound: String,
        vibration: String
    ) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, TimerAlarmReceiver::class.java).apply {
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_COMPLETION_SOUND, sound)
            putExtra(EXTRA_VIBRATION_PATTERN, vibration)
        }
        val pi = PendingIntent.getBroadcast(
            this,
            ALARM_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }

        if (canExact) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtUtcMs, pi)
        } else {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtUtcMs, pi)
        }
    }

    private fun cancelPhaseEndAlarm() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, TimerAlarmReceiver::class.java)
        val pi = PendingIntent.getBroadcast(
            this,
            ALARM_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pi)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Active Focus Timer",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Ongoing live chronometer while a Magn focus session is running"
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }
}
