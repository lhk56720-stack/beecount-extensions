package dev.beecount.extensions.automation_android

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class BeecountAutomationAndroidPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler {
    private lateinit var applicationContext: Context
    private lateinit var channel: MethodChannel
    private lateinit var preferences: CapturePreferences
    private lateinit var eventQueue: SecureEventQueue
    private lateinit var queueExecutor: ExecutorService
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        preferences = CapturePreferences(applicationContext)
        eventQueue = SecureEventQueue(applicationContext)
        queueExecutor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "beecount-automation-platform").apply {
                isDaemon = true
            }
        }
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> runQueueOperation(result) {
                statusMap(eventQueue.pendingCount(System.currentTimeMillis()))
            }
            "configure" -> configure(call, result)
            "openNotificationAccessSettings" -> result.success(openNotificationSettings())
            "leaseEvents" -> runQueueOperation(result) {
                eventQueue.lease(
                    limit = requireNotNull(call.argument<Int>("limit")),
                    leaseDurationMs = requireNotNull(
                        call.argument<Number>("leaseDurationMs"),
                    ).toLong(),
                    nowMs = System.currentTimeMillis(),
                ).toPlatformMap()
            }
            "renewLease" -> runQueueOperation(result) {
                eventQueue.renew(
                    leaseToken = requireNotNull(call.argument<String>("leaseToken")),
                    requestedExtensionMs = requireNotNull(
                        call.argument<Number>("requestedExtensionMs"),
                    ).toLong(),
                    nowMs = System.currentTimeMillis(),
                ).toPlatformMap()
            }
            "acknowledgeEvent" -> runQueueOperation(result) {
                mutationMap(
                    eventQueue.acknowledge(
                        leaseToken = requireNotNull(call.argument<String>("leaseToken")),
                        captureId = requireNotNull(call.argument<String>("captureId")),
                        nowMs = System.currentTimeMillis(),
                    ),
                )
            }
            "releaseLease" -> runQueueOperation(result) {
                mutationMap(
                    eventQueue.release(
                        leaseToken = requireNotNull(call.argument<String>("leaseToken")),
                        nowMs = System.currentTimeMillis(),
                    ),
                )
            }
            "failEvent" -> runQueueOperation(result) {
                mutationMap(
                    eventQueue.fail(
                        leaseToken = requireNotNull(call.argument<String>("leaseToken")),
                        captureId = requireNotNull(call.argument<String>("captureId")),
                        disposition = requireNotNull(call.argument<String>("disposition")),
                        safeReasonCode = requireNotNull(
                            call.argument<String>("safeReasonCode"),
                        ),
                        retryAfterMs = call.argument<Number>("retryAfterMs")?.toLong(),
                        nowMs = System.currentTimeMillis(),
                    ),
                )
            }
            "purgeExpired" -> runQueueOperation(result) {
                eventQueue.purgeExpired(
                    requireNotNull(call.argument<Number>("nowMs")).toLong(),
                )
            }
            else -> result.notImplemented()
        }
    }

    private fun configure(call: MethodCall, result: MethodChannel.Result) {
        val automationEnabled = call.argument<Boolean>("automationEnabled") ?: false
        val notificationEnabled = call.argument<Boolean>("notificationEnabled") ?: false
        val rawPackages = call.argument<List<String>>("enabledPackageNames") ?: emptyList()
        val enabledPackages = rawPackages.toSet()
        if (!enabledPackages.all(NotificationSourceRegistry::isSupported)) {
            result.error(
                "automation.unsupported_source",
                "A requested package is not in the reviewed source registry.",
                null,
            )
            return
        }
        preferences.update(
            automationEnabled = automationEnabled,
            notificationEnabled = notificationEnabled,
            enabledPackageNames = enabledPackages,
        )
        runQueueOperation(result) {
            if (!automationEnabled || !notificationEnabled) {
                eventQueue.clearUnconsumed()
            } else {
                val enabledSourceIds = enabledPackages.mapNotNullTo(mutableSetOf()) {
                    NotificationSourceRegistry.sourceFor(it)?.id
                }
                eventQueue.removeDisabledSources(enabledSourceIds)
            }
            statusMap(eventQueue.pendingCount(System.currentTimeMillis()))
        }
    }

    private fun statusMap(pendingEventCount: Int): Map<String, Any> = mapOf(
        "platformSupported" to true,
        "accessGranted" to isNotificationAccessGranted(),
        "serviceConnected" to BeeCountNotificationListenerService.serviceConnected,
        "automationEnabled" to preferences.automationEnabled,
        "notificationEnabled" to preferences.notificationEnabled,
        "enabledPackageNames" to preferences.enabledPackageNames.toList(),
        "pendingEventCount" to pendingEventCount,
    )

    private fun isNotificationAccessGranted(): Boolean {
        val component = listenerComponent()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            val manager = applicationContext.getSystemService(NotificationManager::class.java)
            return manager.isNotificationListenerAccessGranted(component)
        }
        val enabled = Settings.Secure.getString(
            applicationContext.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return enabled.split(':').any {
            ComponentName.unflattenFromString(it) == component
        }
    }

    private fun openNotificationSettings(): Boolean {
        val component = listenerComponent()
        val intents = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                add(
                    Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                        .putExtra(
                            Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                            component.flattenToString(),
                        ),
                )
            }
            add(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }
        val intent = intents.firstOrNull {
            it.resolveActivity(applicationContext.packageManager) != null
        } ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        applicationContext.startActivity(intent)
        return true
    }

    private fun listenerComponent(): ComponentName = ComponentName(
        applicationContext,
        BeeCountNotificationListenerService::class.java,
    )

    private fun mutationMap(status: String): Map<String, String> =
        mapOf("status" to status)

    private fun runQueueOperation(
        result: MethodChannel.Result,
        operation: () -> Any?,
    ) {
        queueExecutor.execute {
            try {
                val value = operation()
                mainHandler.post { result.success(value) }
            } catch (_: Exception) {
                mainHandler.post {
                    result.error(
                        "automation.platform_error",
                        "The local automation operation failed.",
                        null,
                    )
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        if (::queueExecutor.isInitialized) queueExecutor.shutdown()
    }

    companion object {
        private const val CHANNEL_NAME =
            "dev.beecount.extensions/notification_automation"
    }
}
