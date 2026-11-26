package magn.ion

import android.app.AutomaticZenRule
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.service.notification.Condition

/**
 * Android 15 (API 35)+ compliant Do Not Disturb manager.
 *
 * On Android 15+, apps can no longer directly toggle global DND via
 * NotificationManager.setInterruptionFilter(). Instead, Magn registers and
 * toggles an app-owned AutomaticZenRule ("Magn Focus").
 * On API 24–34, falls back gracefully to standard NotificationPolicy access.
 */
class DndManager(private val context: Context) {

    private val notificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private val prefs =
        context.getSharedPreferences("magn_dnd_prefs", Context.MODE_PRIVATE)

    companion object {
        private const val KEY_ZEN_RULE_ID = "automatic_zen_rule_id"
        private val CONDITION_URI: Uri = Uri.parse("condition://magn.ion/focus_active")
    }

    fun hasDndPermission(): Boolean {
        return notificationManager.isNotificationPolicyAccessGranted
    }

    fun requestDndPermission() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    fun setFocusDndActive(active: Boolean) {
        if (!hasDndPermission()) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            toggleAutomaticZenRule(active)
        } else {
            @Suppress("DEPRECATION")
            val filter = if (active) {
                NotificationManager.INTERRUPTION_FILTER_PRIORITY
            } else {
                NotificationManager.INTERRUPTION_FILTER_ALL
            }
            try {
                notificationManager.setInterruptionFilter(filter)
            } catch (_: SecurityException) {
            }
        }
    }

    private fun toggleAutomaticZenRule(active: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return

        val ruleId = ensureZenRuleId() ?: return
        val conditionState = if (active) Condition.STATE_TRUE else Condition.STATE_FALSE
        val summary = if (active) "Magn focus session in progress" else "Idle"

        try {
            val condition = Condition(CONDITION_URI, summary, conditionState)
            notificationManager.setAutomaticZenRuleState(ruleId, condition)
        } catch (_: Exception) {
            prefs.edit().remove(KEY_ZEN_RULE_ID).apply()
            val freshId = ensureZenRuleId() ?: return
            try {
                val condition = Condition(CONDITION_URI, summary, conditionState)
                notificationManager.setAutomaticZenRuleState(freshId, condition)
            } catch (_: Exception) {
            }
        }
    }

    private fun ensureZenRuleId(): String? {
        val existingId = prefs.getString(KEY_ZEN_RULE_ID, null)
        if (existingId != null && notificationManager.getAutomaticZenRule(existingId) != null) {
            return existingId
        }

        val rule = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            AutomaticZenRule.Builder("Magn Focus", CONDITION_URI)
                .setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                .setEnabled(true)
                .setManualInvocationAllowed(true)
                .setTriggerDescription("Active during Magn focus blocks")
                .build()
        } else {
            @Suppress("DEPRECATION")
            AutomaticZenRule(
                "Magn Focus",
                null as ComponentName?,
                ComponentName(context, MainActivity::class.java),
                CONDITION_URI,
                null,
                NotificationManager.INTERRUPTION_FILTER_PRIORITY,
                true
            )
        }

        return try {
            val newId = notificationManager.addAutomaticZenRule(rule)
            if (newId != null) {
                prefs.edit().putString(KEY_ZEN_RULE_ID, newId).apply()
            }
            newId
        } catch (_: Exception) {
            null
        }
    }
}
