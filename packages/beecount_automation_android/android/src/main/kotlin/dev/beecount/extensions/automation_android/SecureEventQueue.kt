package dev.beecount.extensions.automation_android

import android.content.Context
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID
import kotlin.math.min

internal data class NativeTextFragment(
    val role: String,
    val value: String,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("role", role)
        .put("value", value)

    fun toPlatformMap(): Map<String, Any> = mapOf(
        "role" to role,
        "value" to value,
    )

    companion object {
        fun fromJson(json: JSONObject): NativeTextFragment = NativeTextFragment(
            role = json.getString("role"),
            value = json.getString("value"),
        )
    }
}

internal data class CapturedNotificationPayload(
    val captureId: String,
    val sourceAppId: String,
    val packageName: String,
    val rawEventId: String,
    val eventIdHash: String,
    val lifecycle: String,
    val observedAtMs: Long,
    val capturedAtMs: Long,
    val textFragments: List<NativeTextFragment>,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("payloadSchemaVersion", 1)
        .put("captureId", captureId)
        .put("sourceAppId", sourceAppId)
        .put("packageName", packageName)
        .put("rawEventId", rawEventId)
        .put("eventIdHash", eventIdHash)
        .put("lifecycle", lifecycle)
        .put("observedAtMs", observedAtMs)
        .put("capturedAtMs", capturedAtMs)
        .put(
            "textFragments",
            JSONArray().apply { textFragments.forEach { put(it.toJson()) } },
        )

    fun toPlatformMap(): Map<String, Any> = mapOf(
        "id" to captureId,
        "source" to mapOf(
            "sourceAppId" to sourceAppId,
            "packageName" to packageName,
            "eventId" to rawEventId,
            "eventIdHash" to eventIdHash,
            "observedAtMs" to observedAtMs,
        ),
        "lifecycle" to lifecycle,
        "capturedAtMs" to capturedAtMs,
        "textFragments" to textFragments.map(NativeTextFragment::toPlatformMap),
    )

    companion object {
        fun fromJson(json: JSONObject): CapturedNotificationPayload {
            require(json.getInt("payloadSchemaVersion") == 1) {
                "unsupported payload schema"
            }
            val fragmentsJson = json.getJSONArray("textFragments")
            val fragments = buildList {
                for (index in 0 until fragmentsJson.length()) {
                    add(NativeTextFragment.fromJson(fragmentsJson.getJSONObject(index)))
                }
            }
            return CapturedNotificationPayload(
                captureId = json.getString("captureId"),
                sourceAppId = json.getString("sourceAppId"),
                packageName = json.getString("packageName"),
                rawEventId = json.getString("rawEventId"),
                eventIdHash = json.getString("eventIdHash"),
                lifecycle = json.getString("lifecycle"),
                observedAtMs = json.getLong("observedAtMs"),
                capturedAtMs = json.getLong("capturedAtMs"),
                textFragments = fragments,
            )
        }
    }
}

internal data class NativeLeasedEvent(
    val payload: CapturedNotificationPayload,
    val firstEnqueuedAtMs: Long,
    val rawExpiresAtMs: Long,
    val attemptCount: Int,
) {
    fun toPlatformMap(): Map<String, Any> = mapOf(
        "event" to payload.toPlatformMap(),
        "firstEnqueuedAtMs" to firstEnqueuedAtMs,
        "rawExpiresAtMs" to rawExpiresAtMs,
        "attemptCount" to attemptCount,
    )
}

internal data class NativeLease(
    val token: String,
    val expiresAtMs: Long,
    val events: List<NativeLeasedEvent>,
) {
    fun toPlatformMap(): Map<String, Any> = mapOf(
        "token" to token,
        "expiresAtMs" to expiresAtMs,
        "events" to events.map(NativeLeasedEvent::toPlatformMap),
    )
}

internal data class NativeRenewalResult(
    val status: String,
    val lease: NativeLease?,
) {
    fun toPlatformMap(): Map<String, Any?> = mapOf(
        "status" to status,
        "lease" to lease?.toPlatformMap(),
    )
}

private data class QueueRecord(
    val captureId: String,
    val sourceAppId: String,
    val sourceIdentityHash: String,
    val firstEnqueuedAtMs: Long,
    val rawExpiresAtMs: Long,
    var availableAtMs: Long,
    var state: String,
    var attemptCount: Int,
    var leaseTokenHash: String?,
    var leaseExpiresAtMs: Long?,
    var lastSafeErrorCode: String?,
    var encryptedPayload: EncryptedPayload?,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("captureId", captureId)
        .put("sourceAppId", sourceAppId)
        .put("sourceIdentityHash", sourceIdentityHash)
        .put("firstEnqueuedAtMs", firstEnqueuedAtMs)
        .put("rawExpiresAtMs", rawExpiresAtMs)
        .put("availableAtMs", availableAtMs)
        .put("state", state)
        .put("attemptCount", attemptCount)
        .put("leaseTokenHash", leaseTokenHash ?: JSONObject.NULL)
        .put("leaseExpiresAtMs", leaseExpiresAtMs ?: JSONObject.NULL)
        .put("lastSafeErrorCode", lastSafeErrorCode ?: JSONObject.NULL)
        .put(
            "cipher",
            encryptedPayload?.let {
                JSONObject()
                    .put("algorithm", "AES-256-GCM")
                    .put("iv", it.iv)
                    .put("ciphertext", it.ciphertext)
            } ?: JSONObject.NULL,
        )

    companion object {
        fun fromJson(json: JSONObject): QueueRecord {
            val cipher = json.optJSONObject("cipher")?.let {
                EncryptedPayload(
                    iv = it.getString("iv"),
                    ciphertext = it.getString("ciphertext"),
                )
            }
            return QueueRecord(
                captureId = json.getString("captureId"),
                sourceAppId = json.getString("sourceAppId"),
                sourceIdentityHash = json.getString("sourceIdentityHash"),
                firstEnqueuedAtMs = json.getLong("firstEnqueuedAtMs"),
                rawExpiresAtMs = json.getLong("rawExpiresAtMs"),
                availableAtMs = json.getLong("availableAtMs"),
                state = json.getString("state"),
                attemptCount = json.getInt("attemptCount"),
                leaseTokenHash = json.optNullableString("leaseTokenHash"),
                leaseExpiresAtMs = json.optNullableLong("leaseExpiresAtMs"),
                lastSafeErrorCode = json.optNullableString("lastSafeErrorCode"),
                encryptedPayload = cipher,
            )
        }
    }
}

private data class AckTombstone(
    val captureId: String,
    val leaseTokenHash: String,
    val expiresAtMs: Long,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("captureId", captureId)
        .put("leaseTokenHash", leaseTokenHash)
        .put("expiresAtMs", expiresAtMs)

    companion object {
        fun fromJson(json: JSONObject): AckTombstone = AckTombstone(
            captureId = json.getString("captureId"),
            leaseTokenHash = json.getString("leaseTokenHash"),
            expiresAtMs = json.getLong("expiresAtMs"),
        )
    }
}

private data class SeenSource(
    val sourceAppId: String,
    val sourceIdentityHash: String,
    val expiresAtMs: Long,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("sourceAppId", sourceAppId)
        .put("sourceIdentityHash", sourceIdentityHash)
        .put("expiresAtMs", expiresAtMs)

    companion object {
        fun fromJson(json: JSONObject): SeenSource = SeenSource(
            sourceAppId = json.getString("sourceAppId"),
            sourceIdentityHash = json.getString("sourceIdentityHash"),
            expiresAtMs = json.getLong("expiresAtMs"),
        )
    }
}

private data class QueueSnapshot(
    val records: MutableList<QueueRecord> = mutableListOf(),
    val acknowledgements: MutableList<AckTombstone> = mutableListOf(),
    val seenSources: MutableList<SeenSource> = mutableListOf(),
)

internal class SecureEventQueue(context: Context) {
    private val crypto = QueueCrypto()
    private val lock = Any()
    private val queueDirectory = File(context.noBackupFilesDir, DIRECTORY_NAME).apply {
        mkdirs()
    }
    private val atomicFile = AtomicFile(File(queueDirectory, FILE_NAME))

    fun hmacToken(value: String): String = crypto.hmacToken(value)

    fun hasSeenSource(sourceIdentityHash: String, nowMs: Long): Boolean = synchronized(lock) {
        val snapshot = readSnapshot()
        val removed = purgeSnapshot(snapshot, nowMs)
        if (removed > 0) writeSnapshot(snapshot)
        snapshot.seenSources.any { it.sourceIdentityHash == sourceIdentityHash }
    }

    fun enqueue(payload: CapturedNotificationPayload) = synchronized(lock) {
        val snapshot = readSnapshot()
        purgeSnapshot(snapshot, payload.capturedAtMs)
        if (snapshot.records.any { it.captureId == payload.captureId }) return@synchronized
        if (snapshot.records.size >= MAX_QUEUE_RECORDS) {
            val oldestUnleased = snapshot.records
                .filter { it.state != STATE_LEASED }
                .minByOrNull { it.firstEnqueuedAtMs }
                ?: return@synchronized
            snapshot.records.remove(oldestUnleased)
        }

        val rawExpiresAtMs = payload.capturedAtMs + RAW_TTL_MS
        snapshot.records += QueueRecord(
            captureId = payload.captureId,
            sourceAppId = payload.sourceAppId,
            sourceIdentityHash = payload.eventIdHash,
            firstEnqueuedAtMs = payload.capturedAtMs,
            rawExpiresAtMs = rawExpiresAtMs,
            availableAtMs = payload.capturedAtMs,
            state = STATE_AVAILABLE,
            attemptCount = 0,
            leaseTokenHash = null,
            leaseExpiresAtMs = null,
            lastSafeErrorCode = null,
            encryptedPayload = crypto.encrypt(payload.toJson().toString()),
        )
        snapshot.seenSources.removeAll {
            it.sourceIdentityHash == payload.eventIdHash
        }
        snapshot.seenSources += SeenSource(
            payload.sourceAppId,
            payload.eventIdHash,
            rawExpiresAtMs,
        )
        trimMetadata(snapshot)
        writeSnapshot(snapshot)
    }

    fun lease(limit: Int, leaseDurationMs: Long, nowMs: Long): NativeLease = synchronized(lock) {
        require(limit in 1..100) { "limit must be between 1 and 100" }
        require(leaseDurationMs > 0) { "lease duration must be positive" }
        val snapshot = readSnapshot()
        releaseExpiredLeases(snapshot, nowMs)
        purgeSnapshot(snapshot, nowMs)

        val selected = snapshot.records
            .asSequence()
            .filter {
                (it.state == STATE_AVAILABLE || it.state == STATE_RETRY_WAITING) &&
                    it.availableAtMs <= nowMs &&
                    it.encryptedPayload != null
            }
            .sortedBy { it.firstEnqueuedAtMs }
            .take(limit)
            .toList()

        val token = UUID.randomUUID().toString()
        if (selected.isEmpty()) {
            writeSnapshot(snapshot)
            return@synchronized NativeLease(token, nowMs + leaseDurationMs, emptyList())
        }

        val tokenHash = crypto.hmacToken("lease:$token")
        val expiresAtMs = min(
            nowMs + leaseDurationMs,
            selected.minOf { it.rawExpiresAtMs },
        )
        val events = mutableListOf<NativeLeasedEvent>()
        selected.forEach { record ->
            record.attemptCount += 1
            val payload = try {
                CapturedNotificationPayload.fromJson(
                    JSONObject(crypto.decrypt(requireNotNull(record.encryptedPayload))),
                )
            } catch (_: Exception) {
                record.state = STATE_DEAD_LETTER
                record.encryptedPayload = null
                record.leaseTokenHash = null
                record.leaseExpiresAtMs = null
                record.lastSafeErrorCode = "queue.decrypt_failed"
                return@forEach
            }
            record.state = STATE_LEASED
            record.leaseTokenHash = tokenHash
            record.leaseExpiresAtMs = expiresAtMs
            record.lastSafeErrorCode = null
            events += NativeLeasedEvent(
                payload = payload,
                firstEnqueuedAtMs = record.firstEnqueuedAtMs,
                rawExpiresAtMs = record.rawExpiresAtMs,
                attemptCount = record.attemptCount,
            )
        }
        writeSnapshot(snapshot)
        NativeLease(token, expiresAtMs, events)
    }

    fun renew(
        leaseToken: String,
        requestedExtensionMs: Long,
        nowMs: Long,
    ): NativeRenewalResult = synchronized(lock) {
        require(requestedExtensionMs > 0) { "requested extension must be positive" }
        val snapshot = readSnapshot()
        releaseExpiredLeases(snapshot, nowMs)
        purgeSnapshot(snapshot, nowMs)
        val tokenHash = crypto.hmacToken("lease:$leaseToken")
        val records = snapshot.records.filter {
            it.state == STATE_LEASED && it.leaseTokenHash == tokenHash
        }
        if (records.isEmpty()) {
            writeSnapshot(snapshot)
            return@synchronized NativeRenewalResult(STATUS_LEASE_NOT_FOUND, null)
        }
        val currentExpiry = records.minOf { requireNotNull(it.leaseExpiresAtMs) }
        if (currentExpiry <= nowMs) {
            releaseExpiredLeases(snapshot, nowMs)
            writeSnapshot(snapshot)
            return@synchronized NativeRenewalResult(STATUS_LEASE_EXPIRED, null)
        }
        val newExpiry = min(
            currentExpiry + requestedExtensionMs,
            records.minOf { it.rawExpiresAtMs },
        )
        records.forEach { it.leaseExpiresAtMs = newExpiry }
        val events = records.mapNotNull { record ->
            val encrypted = record.encryptedPayload ?: return@mapNotNull null
            val payload = try {
                CapturedNotificationPayload.fromJson(JSONObject(crypto.decrypt(encrypted)))
            } catch (_: Exception) {
                record.state = STATE_DEAD_LETTER
                record.encryptedPayload = null
                record.leaseTokenHash = null
                record.leaseExpiresAtMs = null
                record.lastSafeErrorCode = "queue.decrypt_failed"
                return@mapNotNull null
            }
            NativeLeasedEvent(
                payload,
                record.firstEnqueuedAtMs,
                record.rawExpiresAtMs,
                record.attemptCount,
            )
        }
        writeSnapshot(snapshot)
        NativeRenewalResult(
            STATUS_APPLIED,
            NativeLease(leaseToken, newExpiry, events),
        )
    }

    fun acknowledge(leaseToken: String, captureId: String, nowMs: Long): String =
        synchronized(lock) {
            val snapshot = readSnapshot()
            releaseExpiredLeases(snapshot, nowMs)
            purgeSnapshot(snapshot, nowMs)
            val tokenHash = crypto.hmacToken("lease:$leaseToken")
            if (snapshot.acknowledgements.any {
                    it.captureId == captureId && it.leaseTokenHash == tokenHash
                }
            ) {
                writeSnapshot(snapshot)
                return@synchronized STATUS_ALREADY_APPLIED
            }
            val record = snapshot.records.firstOrNull { it.captureId == captureId }
                ?: return@synchronized STATUS_EVENT_NOT_IN_LEASE
            val leaseStatus = validateLease(record, tokenHash, nowMs)
            if (leaseStatus != STATUS_APPLIED) {
                writeSnapshot(snapshot)
                return@synchronized leaseStatus
            }
            snapshot.records.remove(record)
            snapshot.acknowledgements += AckTombstone(
                captureId = captureId,
                leaseTokenHash = tokenHash,
                expiresAtMs = record.rawExpiresAtMs,
            )
            trimMetadata(snapshot)
            writeSnapshot(snapshot)
            STATUS_APPLIED
        }

    fun release(leaseToken: String, nowMs: Long): String = synchronized(lock) {
        val snapshot = readSnapshot()
        releaseExpiredLeases(snapshot, nowMs)
        purgeSnapshot(snapshot, nowMs)
        val tokenHash = crypto.hmacToken("lease:$leaseToken")
        val records = snapshot.records.filter {
            it.state == STATE_LEASED && it.leaseTokenHash == tokenHash
        }
        if (records.isEmpty()) {
            writeSnapshot(snapshot)
            return@synchronized STATUS_LEASE_NOT_FOUND
        }
        records.forEach {
            it.state = STATE_AVAILABLE
            it.availableAtMs = nowMs
            it.leaseTokenHash = null
            it.leaseExpiresAtMs = null
        }
        writeSnapshot(snapshot)
        STATUS_APPLIED
    }

    fun fail(
        leaseToken: String,
        captureId: String,
        disposition: String,
        safeReasonCode: String,
        retryAfterMs: Long?,
        nowMs: Long,
    ): String = synchronized(lock) {
        require(SAFE_CODE.matches(safeReasonCode)) { "invalid safe reason code" }
        require(
            (disposition == "retryable" && retryAfterMs != null) ||
                (disposition == "permanent" && retryAfterMs == null),
        ) { "failure disposition and retryAfter do not match" }
        val snapshot = readSnapshot()
        releaseExpiredLeases(snapshot, nowMs)
        purgeSnapshot(snapshot, nowMs)
        val tokenHash = crypto.hmacToken("lease:$leaseToken")
        val record = snapshot.records.firstOrNull { it.captureId == captureId }
            ?: return@synchronized STATUS_EVENT_NOT_IN_LEASE
        val leaseStatus = validateLease(record, tokenHash, nowMs)
        if (leaseStatus != STATUS_APPLIED) {
            writeSnapshot(snapshot)
            return@synchronized leaseStatus
        }
        record.leaseTokenHash = null
        record.leaseExpiresAtMs = null
        record.lastSafeErrorCode = safeReasonCode
        if (disposition == "permanent") {
            record.state = STATE_DEAD_LETTER
            record.encryptedPayload = null
        } else {
            record.state = STATE_RETRY_WAITING
            record.availableAtMs = min(requireNotNull(retryAfterMs), record.rawExpiresAtMs)
        }
        writeSnapshot(snapshot)
        STATUS_APPLIED
    }

    fun pendingCount(nowMs: Long): Int = synchronized(lock) {
        val snapshot = readSnapshot()
        releaseExpiredLeases(snapshot, nowMs)
        purgeSnapshot(snapshot, nowMs)
        writeSnapshot(snapshot)
        snapshot.records.count { it.state != STATE_DEAD_LETTER }
    }

    fun purgeExpired(nowMs: Long): Int = synchronized(lock) {
        val snapshot = readSnapshot()
        releaseExpiredLeases(snapshot, nowMs)
        val removed = purgeSnapshot(snapshot, nowMs)
        writeSnapshot(snapshot)
        removed
    }

    fun clearUnconsumed() = synchronized(lock) {
        val snapshot = readSnapshot()
        snapshot.records.clear()
        snapshot.acknowledgements.clear()
        snapshot.seenSources.clear()
        writeSnapshot(snapshot)
    }

    fun removeDisabledSources(enabledSourceIds: Set<String>) = synchronized(lock) {
        val snapshot = readSnapshot()
        snapshot.records.removeAll { it.sourceAppId !in enabledSourceIds }
        snapshot.seenSources.removeAll { it.sourceAppId !in enabledSourceIds }
        writeSnapshot(snapshot)
    }

    private fun trimMetadata(snapshot: QueueSnapshot) {
        while (snapshot.acknowledgements.size > MAX_METADATA_RECORDS) {
            snapshot.acknowledgements.removeAt(0)
        }
        while (snapshot.seenSources.size > MAX_METADATA_RECORDS) {
            snapshot.seenSources.removeAt(0)
        }
    }

    private fun validateLease(record: QueueRecord, tokenHash: String, nowMs: Long): String {
        if (record.state != STATE_LEASED || record.leaseTokenHash != tokenHash) {
            return STATUS_EVENT_NOT_IN_LEASE
        }
        if ((record.leaseExpiresAtMs ?: 0) <= nowMs) return STATUS_LEASE_EXPIRED
        return STATUS_APPLIED
    }

    private fun releaseExpiredLeases(snapshot: QueueSnapshot, nowMs: Long) {
        snapshot.records.forEach { record ->
            if (record.state == STATE_LEASED && (record.leaseExpiresAtMs ?: 0) <= nowMs) {
                record.state = STATE_AVAILABLE
                record.availableAtMs = nowMs
                record.leaseTokenHash = null
                record.leaseExpiresAtMs = null
            }
        }
    }

    private fun purgeSnapshot(snapshot: QueueSnapshot, nowMs: Long): Int {
        val before = snapshot.records.size
        snapshot.records.removeAll { it.rawExpiresAtMs <= nowMs }
        snapshot.acknowledgements.removeAll { it.expiresAtMs <= nowMs }
        snapshot.seenSources.removeAll { it.expiresAtMs <= nowMs }
        return before - snapshot.records.size
    }

    private fun readSnapshot(): QueueSnapshot {
        if (!atomicFile.baseFile.exists()) return QueueSnapshot()
        return try {
            atomicFile.openRead().bufferedReader().use { reader ->
                val root = JSONObject(reader.readText())
                require(root.getInt("schemaVersion") == STORAGE_SCHEMA_VERSION)
                QueueSnapshot(
                    records = root.getJSONArray("records").toMutableList(QueueRecord::fromJson),
                    acknowledgements = root.getJSONArray("acknowledgements")
                        .toMutableList(AckTombstone::fromJson),
                    seenSources = root.getJSONArray("seenSources")
                        .toMutableList(SeenSource::fromJson),
                )
            }
        } catch (_: Exception) {
            atomicFile.delete()
            QueueSnapshot()
        }
    }

    private fun writeSnapshot(snapshot: QueueSnapshot) {
        val root = JSONObject()
            .put("schemaVersion", STORAGE_SCHEMA_VERSION)
            .put("records", snapshot.records.toJsonArray(QueueRecord::toJson))
            .put(
                "acknowledgements",
                snapshot.acknowledgements.toJsonArray(AckTombstone::toJson),
            )
            .put("seenSources", snapshot.seenSources.toJsonArray(SeenSource::toJson))
        val output = atomicFile.startWrite()
        try {
            output.write(root.toString().toByteArray(Charsets.UTF_8))
            atomicFile.finishWrite(output)
        } catch (error: Exception) {
            atomicFile.failWrite(output)
            throw error
        }
    }

    companion object {
        private const val STORAGE_SCHEMA_VERSION = 1
        private const val RAW_TTL_MS = 24L * 60L * 60L * 1000L
        private const val MAX_QUEUE_RECORDS = 500
        private const val MAX_METADATA_RECORDS = 1000
        private const val DIRECTORY_NAME = "beecount_automation_queue"
        private const val FILE_NAME = "events.json"

        private const val STATE_AVAILABLE = "available"
        private const val STATE_LEASED = "leased"
        private const val STATE_RETRY_WAITING = "retryWaiting"
        private const val STATE_DEAD_LETTER = "deadLetter"

        const val STATUS_APPLIED = "applied"
        const val STATUS_ALREADY_APPLIED = "alreadyApplied"
        const val STATUS_LEASE_EXPIRED = "leaseExpired"
        const val STATUS_LEASE_NOT_FOUND = "leaseNotFound"
        const val STATUS_EVENT_NOT_IN_LEASE = "eventNotInLease"

        private val SAFE_CODE = Regex("^[a-z0-9_.-]{1,80}$")
    }
}

private fun JSONObject.optNullableString(key: String): String? =
    if (isNull(key)) null else getString(key)

private fun JSONObject.optNullableLong(key: String): Long? =
    if (isNull(key)) null else getLong(key)

private fun <T> JSONArray.toMutableList(mapper: (JSONObject) -> T): MutableList<T> =
    buildList {
        for (index in 0 until length()) add(mapper(getJSONObject(index)))
    }.toMutableList()

private fun <T> List<T>.toJsonArray(mapper: (T) -> JSONObject): JSONArray =
    JSONArray().apply { forEach { put(mapper(it)) } }
