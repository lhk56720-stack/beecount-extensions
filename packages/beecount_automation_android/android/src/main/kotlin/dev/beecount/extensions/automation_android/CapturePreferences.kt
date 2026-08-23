package dev.beecount.extensions.automation_android

import android.content.Context

internal class CapturePreferences(context: Context) {
    private val preferences = context.getSharedPreferences(
        FILE_NAME,
        Context.MODE_PRIVATE,
    )

    val automationEnabled: Boolean
        get() = preferences.getBoolean(KEY_AUTOMATION_ENABLED, false)

    val notificationEnabled: Boolean
        get() = preferences.getBoolean(KEY_NOTIFICATION_ENABLED, false)

    val enabledPackageNames: Set<String>
        get() = preferences.getStringSet(KEY_ENABLED_PACKAGES, emptySet())
            ?.filterTo(mutableSetOf()) { NotificationSourceRegistry.isSupported(it) }
            ?: emptySet()

    fun canCapture(packageName: String): Boolean =
        automationEnabled &&
            notificationEnabled &&
            packageName in enabledPackageNames &&
            NotificationSourceRegistry.isSupported(packageName)

    fun update(
        automationEnabled: Boolean,
        notificationEnabled: Boolean,
        enabledPackageNames: Set<String>,
    ) {
        require(enabledPackageNames.all(NotificationSourceRegistry::isSupported)) {
            "enabled packages must come from the reviewed source registry"
        }
        preferences.edit()
            .putBoolean(KEY_AUTOMATION_ENABLED, automationEnabled)
            .putBoolean(KEY_NOTIFICATION_ENABLED, notificationEnabled)
            .putStringSet(KEY_ENABLED_PACKAGES, enabledPackageNames)
            .apply()
    }

    companion object {
        private const val FILE_NAME = "beecount_automation_capture"
        private const val KEY_AUTOMATION_ENABLED = "automation_enabled"
        private const val KEY_NOTIFICATION_ENABLED = "notification_enabled"
        private const val KEY_ENABLED_PACKAGES = "enabled_packages"
    }
}
