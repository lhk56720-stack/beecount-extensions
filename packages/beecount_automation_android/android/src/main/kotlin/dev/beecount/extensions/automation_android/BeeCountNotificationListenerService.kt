package dev.beecount.extensions.automation_android

import android.app.Notification
import android.content.ComponentName
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class BeeCountNotificationListenerService : NotificationListenerService() {
    private lateinit var capturePreferences: CapturePreferences
    private lateinit var eventQueue: SecureEventQueue
    private lateinit var queueExecutor: ExecutorService

    override fun onCreate() {
        super.onCreate()
        capturePreferences = CapturePreferences(applicationContext)
        eventQueue = SecureEventQueue(applicationContext)
        queueExecutor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "beecount-notification-queue").apply {
                isDaemon = true
            }
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        serviceConnected = true
    }

    override fun onListenerDisconnected() {
        serviceConnected = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            requestRebind(ComponentName(this, javaClass))
        }
        super.onListenerDisconnected()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val source = NotificationSourceRegistry.sourceFor(sbn.packageName) ?: return
        if (!capturePreferences.canCapture(source.packageName)) return

        val fragments = extractFragments(sbn.notification)
        if (fragments.isEmpty()) return

        val capturedAtMs = System.currentTimeMillis()
        val notificationKey = sbn.key
        val postTime = sbn.postTime
        queueExecutor.execute {
            val eventIdHash = eventQueue.hmacToken("event:$notificationKey")
            val lifecycle = if (eventQueue.hasSeenSource(eventIdHash, capturedAtMs)) {
                "updated"
            } else {
                "posted"
            }
            val captureMaterial = buildString {
                append("capture|")
                append(notificationKey)
                append('|')
                append(postTime)
                append('|')
                append(lifecycle)
                fragments.forEach {
                    append('|')
                    append(it.role)
                    append(':')
                    append(it.value)
                }
            }
            eventQueue.enqueue(
                CapturedNotificationPayload(
                    captureId = eventQueue.hmacToken(captureMaterial),
                    sourceAppId = source.id,
                    packageName = source.packageName,
                    rawEventId = notificationKey,
                    eventIdHash = eventIdHash,
                    lifecycle = lifecycle,
                    observedAtMs = postTime,
                    capturedAtMs = capturedAtMs,
                    textFragments = fragments,
                ),
            )
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        captureRemoval(sbn)
    }

    override fun onNotificationRemoved(
        sbn: StatusBarNotification,
        rankingMap: RankingMap,
        reason: Int,
    ) {
        captureRemoval(sbn)
    }

    private fun captureRemoval(sbn: StatusBarNotification) {
        val source = NotificationSourceRegistry.sourceFor(sbn.packageName) ?: return
        if (!capturePreferences.canCapture(source.packageName)) return
        val capturedAtMs = System.currentTimeMillis()
        val notificationKey = sbn.key
        val postTime = sbn.postTime
        queueExecutor.execute {
            val eventIdHash = eventQueue.hmacToken("event:$notificationKey")
            if (!eventQueue.hasSeenSource(eventIdHash, capturedAtMs)) return@execute
            eventQueue.enqueue(
                CapturedNotificationPayload(
                    captureId = eventQueue.hmacToken(
                        "capture|$notificationKey|$postTime|removed",
                    ),
                    sourceAppId = source.id,
                    packageName = source.packageName,
                    rawEventId = notificationKey,
                    eventIdHash = eventIdHash,
                    lifecycle = "removed",
                    observedAtMs = capturedAtMs,
                    capturedAtMs = capturedAtMs,
                    textFragments = emptyList(),
                ),
            )
        }
    }

    private fun extractFragments(notification: Notification): List<NativeTextFragment> {
        val extras = notification.extras ?: return emptyList()
        val fragments = mutableListOf<NativeTextFragment>()
        val seenValues = mutableSetOf<String>()
        var remainingCharacters = MAX_TOTAL_CHARACTERS

        fun add(role: String, rawValue: CharSequence?) {
            if (fragments.size >= MAX_FRAGMENTS || remainingCharacters <= 0) return
            val normalized = rawValue?.toString()?.trim().orEmpty()
            if (normalized.isEmpty() || !seenValues.add(normalized)) return
            val bounded = normalized.take(minOf(MAX_FRAGMENT_CHARACTERS, remainingCharacters))
            if (bounded.isEmpty()) return
            fragments += NativeTextFragment(role, bounded)
            remainingCharacters -= bounded.length
        }

        add("title", extras.getCharSequence(Notification.EXTRA_TITLE))
        add("body", extras.getCharSequence(Notification.EXTRA_TEXT))
        add("body", extras.getCharSequence(Notification.EXTRA_BIG_TEXT))
        add("body", extras.getCharSequence(Notification.EXTRA_SUB_TEXT))
        extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)?.forEach {
            add("body", it)
        }
        return fragments
    }

    override fun onDestroy() {
        serviceConnected = false
        if (::queueExecutor.isInitialized) queueExecutor.shutdown()
        super.onDestroy()
    }

    companion object {
        @Volatile
        internal var serviceConnected: Boolean = false
            private set

        private const val MAX_FRAGMENTS = 8
        private const val MAX_FRAGMENT_CHARACTERS = 256
        private const val MAX_TOTAL_CHARACTERS = 1024
    }
}
