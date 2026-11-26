package magn.ion

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * BroadcastReceiver triggered by AlarmManager.setExactAndAllowWhileIdle()
 * to fire reliable completion chimes/vibration even when the device is in Doze mode.
 */
class TimerAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val sound = intent.getStringExtra(FocusTimerService.EXTRA_COMPLETION_SOUND) ?: "soft_chime"
        val vibration = intent.getStringExtra(FocusTimerService.EXTRA_VIBRATION_PATTERN) ?: "gentle"

        playCompletionAlert(context, sound, vibration)
        MainActivity.dispatchNativeAction("alarm_fired")
    }

    companion object {
        fun playCompletionAlert(context: Context, sound: String, vibration: String) {
            if (sound != "silent") {
                try {
                    val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    val ringtone = RingtoneManager.getRingtone(context, uri)
                    ringtone?.play()
                } catch (_: Exception) {
                }
            }

            if (vibration != "off") {
                val pattern = when (vibration) {
                    "crisp" -> longArrayOf(0, 90, 90, 90)
                    "long_pulse" -> longArrayOf(0, 450, 150, 450)
                    else -> longArrayOf(0, 180, 120, 140)
                }

                try {
                    val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val vm = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                        vm.defaultVibrator
                    } else {
                        @Suppress("DEPRECATION")
                        context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(pattern, -1)
                    }
                } catch (_: Exception) {
                }
            }
        }
    }
}
