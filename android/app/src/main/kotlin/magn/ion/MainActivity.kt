package magn.ion

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL = "magn.ion/native_timer"
        private const val EVENT_CHANNEL = "magn.ion/native_events"

        @Volatile
        private var eventSink: EventChannel.EventSink? = null
        private val mainHandler = Handler(Looper.getMainLooper())

        fun dispatchNativeAction(action: String) {
            mainHandler.post {
                eventSink?.success(action)
            }
        }
    }

    private lateinit var dndManager: DndManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        dndManager = DndManager(applicationContext)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForegroundSession" -> {
                        val intent = Intent(this, FocusTimerService::class.java).apply {
                            action = FocusTimerService.ACTION_START
                            putExtra(FocusTimerService.EXTRA_TITLE, call.argument<String>("title"))
                            putExtra(FocusTimerService.EXTRA_SUBTITLE, call.argument<String>("subtitle"))
                            putExtra(
                                FocusTimerService.EXTRA_START_UTC_MS,
                                (call.argument<Number>("startUtcMs")?.toLong() ?: System.currentTimeMillis())
                            )
                            putExtra(
                                FocusTimerService.EXTRA_TARGET_END_UTC_MS,
                                (call.argument<Number>("targetEndUtcMs")?.toLong() ?: -1L)
                            )
                            putExtra(
                                FocusTimerService.EXTRA_IS_COUNT_UP,
                                call.argument<Boolean>("isCountUp") ?: false
                            )
                            putExtra(
                                FocusTimerService.EXTRA_NOTIFICATION_STYLE,
                                call.argument<String>("notificationStyle") ?: "standard"
                            )
                            putExtra(
                                FocusTimerService.EXTRA_COMPLETION_SOUND,
                                call.argument<String>("completionSound") ?: "soft_chime"
                            )
                            putExtra(
                                FocusTimerService.EXTRA_VIBRATION_PATTERN,
                                call.argument<String>("vibrationPattern") ?: "gentle"
                            )
                        }
                        ContextCompat.startForegroundService(this, intent)
                        result.success(null)
                    }

                    "pauseForegroundSession" -> {
                        val intent = Intent(this, FocusTimerService::class.java).apply {
                            action = FocusTimerService.ACTION_PAUSE
                            putExtra(FocusTimerService.EXTRA_TITLE, call.argument<String>("title"))
                            putExtra(
                                FocusTimerService.EXTRA_FORMATTED_TIME,
                                call.argument<String>("formattedTime")
                            )
                        }
                        startService(intent)
                        result.success(null)
                    }

                    "stopForegroundSession" -> {
                        val intent = Intent(this, FocusTimerService::class.java).apply {
                            action = FocusTimerService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(null)
                    }

                    "triggerCompletionAlert" -> {
                        val sound = call.argument<String>("sound") ?: "soft_chime"
                        val vibration = call.argument<String>("vibration") ?: "gentle"
                        TimerAlarmReceiver.playCompletionAlert(applicationContext, sound, vibration)
                        result.success(null)
                    }

                    "setDndActive" -> {
                        val active = call.argument<Boolean>("active") ?: false
                        dndManager.setFocusDndActive(active)
                        result.success(null)
                    }

                    "hasDndPermission" -> {
                        result.success(dndManager.hasDndPermission())
                    }

                    "requestDndPermission" -> {
                        dndManager.requestDndPermission()
                        result.success(null)
                    }

                    "canScheduleExactAlarms" -> {
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            alarmManager.canScheduleExactAlarms()
                        } else {
                            true
                        }
                        result.success(allowed)
                    }

                    "requestExactAlarmPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        }
                        result.success(null)
                    }

                    "setAmbientSound" -> {
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
